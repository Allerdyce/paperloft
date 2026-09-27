// App Store Connect check for the Paperloft factory.
//
// Run with: xcrun swift scripts/asc_ping.swift
// Reads ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH and BUNDLE_ID from the environment
// (scripts/preflight_check.sh loads them from ~/Factory/.secrets/asc.env).
//
// Prints, one per line:
//   ASC_OK app_id=<id> name=<name>     the app record exists
//   ASC_NO_APP bundle=<bundle id>      no app record for this bundle ID
//   ASC_AUTH_FAILED ...                the key was rejected
//   ASC_PRODUCT <product id>           each in-app purchase and subscription it can see
//   ASC_WARN ...                       something it could not read
//   ASC_ERROR ...                      anything else
// Never prints the key or the token. Apple frameworks only.

import CryptoKit
import Foundation

func env(_ name: String) -> String {
    guard let value = ProcessInfo.processInfo.environment[name], !value.isEmpty else {
        print("ASC_ERROR missing environment variable \(name)")
        exit(2)
    }
    return value
}

func base64URL(_ data: Data) -> String {
    data.base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}

let keyID = env("ASC_KEY_ID")
let issuerID = env("ASC_ISSUER_ID")
let keyPath = (env("ASC_KEY_PATH") as NSString).expandingTildeInPath
let bundleID = env("BUNDLE_ID")

// ES256 JWT, valid for 10 minutes (Apple allows up to 20).
let token: String
do {
    let pem = try String(contentsOfFile: keyPath, encoding: .utf8)
    let key = try P256.Signing.PrivateKey(pemRepresentation: pem)
    let now = Int(Date().timeIntervalSince1970)
    let header: [String: Any] = ["alg": "ES256", "kid": keyID, "typ": "JWT"]
    let claims: [String: Any] = ["iss": issuerID, "iat": now, "exp": now + 600, "aud": "appstoreconnect-v1"]
    let signingInput = base64URL(try JSONSerialization.data(withJSONObject: header))
        + "." + base64URL(try JSONSerialization.data(withJSONObject: claims))
    let signature = try key.signature(for: Data(signingInput.utf8))
    token = signingInput + "." + base64URL(signature.rawRepresentation)
} catch {
    print("ASC_ERROR could not build a token from the key file: \(error)")
    exit(2)
}

func get(_ path: String, _ query: [String: String] = [:]) async -> (status: Int, json: [String: Any]) {
    guard var components = URLComponents(string: "https://api.appstoreconnect.apple.com" + path) else {
        return (0, [:])
    }
    if !query.isEmpty {
        components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
    }
    guard let url = components.url else { return (0, [:]) }
    var request = URLRequest(url: url)
    request.timeoutInterval = 30
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    do {
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        return (status, json)
    } catch {
        return (0, ["error": "\(error.localizedDescription)"])
    }
}

func productIDs(in json: [String: Any]) -> [String] {
    let items = json["data"] as? [[String: Any]] ?? []
    return items.compactMap { ($0["attributes"] as? [String: Any])?["productId"] as? String }
}

// 1. The app record.
let apps = await get("/v1/apps", ["filter[bundleId]": bundleID, "fields[apps]": "name,bundleId"])
if apps.status == 401 || apps.status == 403 {
    print("ASC_AUTH_FAILED http \(apps.status): check key ID, issuer ID, key file and role")
    exit(1)
}
guard apps.status == 200 else {
    print("ASC_ERROR http \(apps.status) while listing apps")
    exit(1)
}
guard let app = (apps.json["data"] as? [[String: Any]])?.first, let appID = app["id"] as? String else {
    print("ASC_NO_APP bundle=\(bundleID)")
    exit(1)
}
let appName = (app["attributes"] as? [String: Any])?["name"] as? String ?? "?"
print("ASC_OK app_id=\(appID) name=\(appName)")

// 2. Non-consumable and consumable in-app purchases.
let iaps = await get("/v1/apps/\(appID)/inAppPurchasesV2", ["limit": "200"])
if iaps.status == 200 {
    for id in productIDs(in: iaps.json) { print("ASC_PRODUCT \(id)") }
} else {
    print("ASC_WARN could not list in-app purchases (http \(iaps.status))")
}

// 3. Auto-renewable subscriptions, group by group.
let groups = await get("/v1/apps/\(appID)/subscriptionGroups", ["limit": "50"])
if groups.status == 200 {
    for group in groups.json["data"] as? [[String: Any]] ?? [] {
        guard let groupID = group["id"] as? String else { continue }
        let subs = await get("/v1/subscriptionGroups/\(groupID)/subscriptions", ["limit": "200"])
        if subs.status == 200 {
            for id in productIDs(in: subs.json) { print("ASC_PRODUCT \(id)") }
        } else {
            print("ASC_WARN could not list subscriptions in group \(groupID) (http \(subs.status))")
        }
    }
} else {
    print("ASC_WARN could not list subscription groups (http \(groups.status))")
}
