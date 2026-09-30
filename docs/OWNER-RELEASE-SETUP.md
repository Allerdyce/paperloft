# Owner guide: clearing the release preflight blockers

Written 2026-09-30 from the release check in `evidence/release/readiness-20260929.md`. It follows `SPEC.md` sections 3.3–3.8 and 4, trimmed to what is still open. Everything here is yours to do; the agent can't sign in, create accounts, set prices or accept agreements on your behalf. **Never paste keys, passwords or `.p8` contents into chat.**

Today's full preflight shows **10 FAIL** lines:
- no Apple Distribution identity
- no Mac Installer Distribution identity
- four example values in `asc.env`
- missing API key file
- no signing identity for the team
- the App Store Connect check failed
- missing `acceptance-v1` tag

Steps 1–4 clear them, step 5 covers the manual confirmations, and step 6 is the go/no-go.

---

## Step 1: EvidencePair LLC's Apple Developer membership (the DUNS dependency)

Everything else (Team ID, certificates, API key, app record) belongs to this membership, so do it first.

1. **D-U-N-S Number.** Look it up or request it at <https://developer.apple.com/enroll/duns-lookup/>.
   - Use the exact legal name **EvidencePair LLC** and the address on your state filing.
   - It's free and takes about 5–7 business days. Dun & Bradstreet may contact you to verify.
2. **Prepare what Apple checks:**
   - a work email on a domain tied to the LLC (e.g. an address at `paperloft.app`)
   - the live website `https://paperloft.app` (it already passes preflight)
   - the enrolling person must have authority to sign contracts for the LLC
3. **Choose how to enroll** (<https://developer.apple.com/programs/enroll/>):
   - **Convert** the existing individual membership (team GQ4UA5C6RQ) to the LLC through Apple's membership update request. This moves every app on it to the LLC and **can't be undone**.
   - Or **enroll the LLC as a new membership**. This creates a new Team ID; the agent updates the project config afterwards.
4. When approved, sign in at <https://developer.apple.com/account> and accept the Program License Agreement.
5. Write down the **Team ID**: Account › Membership details. You'll need it in step 4.

## Step 2: App Store Connect business setup (browser)

At <https://appstoreconnect.apple.com>, signed in as the LLC's Account Holder:

1. **Business:**
   - sign the **Paid Apps Agreement**
   - complete the tax forms with the LLC's EIN (a US LLC normally files a W-9)
   - add the LLC's bank account for payouts
2. **Small Business Program:** enroll at <https://developer.apple.com/app-store/small-business-program/>. It gives the 15% rate.
3. **Bundle ID:** in Certificates, Identifiers & Profiles › Identifiers, register `app.paperloft.receipts`, the explicit App ID for macOS.
   - Enable the **App Groups** capability.
   - The Share extension uses `app.paperloft.receipts.share`. Xcode can register it during the shakedown; register it yourself if Apple asks.
4. **App record:** My Apps › + › New App.
   - Platform macOS; name **Paperloft Receipts**; primary language English (U.S.); bundle ID `app.paperloft.receipts`; any SKU (e.g. `PAPERLOFT-RECEIPTS-1`).
   - This can't be automated.
5. **In-app products**, with these exact IDs (a placeholder display name is enough; the agent finishes localizations):
   - Subscription group **Paperloft Pro** containing the auto-renewable `app.paperloft.receipts.pro.yearly` at **$29.99/year**, with a **1-week free trial** introductory offer.
   - Non-consumable `app.paperloft.receipts.pro.lifetime` at **$69.99**.
6. **App price:** Free (Pro is sold in-app), with the availability you want.
7. **App Privacy:** answer **Data Not Collected**.

## Step 3: Signing certificates on this Mac (as `builder`)

1. Open Xcode › Settings › Accounts, add the Apple Account that administers the LLC team, and select the **EvidencePair LLC** team.
2. Manage Certificates › **+** › create:
   - **Apple Development** (for the LLC team, if not already present)
   - **Apple Distribution**
   - **Mac Installer Distribution**
3. Stop keychain prompts during unattended runs. Run in Terminal, replacing the placeholder with the `builder` login password; type it yourself, don't share it:
   ```bash
   security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "<builder password>" ~/Library/Keychains/login.keychain-db
   ```
   ```bash
   security set-keychain-settings ~/Library/Keychains/login.keychain-db
   ```
4. Check: this should list all three identities for EvidencePair LLC.
   ```bash
   security find-identity -v
   ```
5. Optional, per SPEC 3.3: remove the Apple Account from Xcode afterwards so its session can't expire mid-run. From here the agent signs with the API key.

## Step 4: App Store Connect API key and `asc.env`

1. App Store Connect › Users and Access › Integrations › **App Store Connect API** › Team Keys.
   - The first time, the Account Holder must click Request Access.
2. Generate a key named e.g. "Paperloft factory" with the **App Manager** role.
   - Download the `.p8`. **It downloads only once.**
   - Note the **Key ID** (in the key row) and the **Issuer ID** (at the top of the page).
   - If the shakedown's archive step later fails with a signing-permission error, create an **Admin** key instead.
3. Move the key into place, replacing `KEYID` with your Key ID:
   ```bash
   mkdir -p ~/.appstoreconnect/private_keys && mv ~/Downloads/AuthKey_KEYID.p8 ~/.appstoreconnect/private_keys/ && chmod 600 ~/.appstoreconnect/private_keys/AuthKey_KEYID.p8
   ```
4. Edit the secrets file:
   ```bash
   open -e ~/Factory/.secrets/asc.env
   ```
   Replace the four example lines, keeping the quotes:
   ```
   ASC_KEY_ID="your Key ID"
   ASC_ISSUER_ID="your Issuer ID"
   ASC_KEY_PATH="/Users/builder/.appstoreconnect/private_keys/AuthKey_<KEYID>.p8"
   TEAM_ID="the LLC Team ID from step 1"
   ```
   Leave `BUNDLE_ID`, `APP_NAME`, `SUPPORT_EMAIL`, `SITE_DOMAIN` and `LEGAL_ENTITY` as they are.
5. Lock the permissions down:
   ```bash
   chmod 600 ~/Factory/.secrets/asc.env && chmod 700 ~/Factory/.secrets
   ```

## Step 5: The manual confirmations preflight can't check

1. **Focus:** Do Not Disturb on, always, with no allowed people or apps (System Settings › Focus).
2. **Agent app settings:**
   - Full access for this project
   - prevent sleep while running
   - notifications and memories off
   - (Preflight still words this item for Codex. If you now run this project in Claude, apply the equivalent settings there.)
3. **Computer Use:**
   - Screen Recording and Accessibility granted
   - locked use on
   - "Always allow" for Xcode, Finder, Preview and Paperloft Receipts
4. **GitHub rulesets** on the `paperloft` repo, under Settings › Rules › Rulesets (a private repo needs GitHub Pro or Team):
   - **Branch ruleset:** target all branches; restrict deletions; block force pushes.
   - **Tag ruleset:** target `acceptance-*` and `p*-done`; restrict updates; restrict deletions.
5. **App Store Connect:** confirm the Paid Apps Agreement is active and Small Business Program enrollment went through (step 2).
6. Optional (preflight WARN): automatic restart after power loss.
   ```bash
   sudo pmset -a autorestart 1
   ```

## Step 6: The acceptance baseline tag, then go/no-go

1. **Create `acceptance-v1`.** This freezes the acceptance bar. It belongs on commit **`9ad4c75`** (2026-09-27, "Record owner authorization for Apple agreements").
   - That's the latest commit to change `AGENTS.md`. It includes your approved amendments.
   - All 14 frozen files there are byte-identical to today's `run/1`.
   - Tagging the original kit commit `640eab5` instead would make `verify_lock.sh` fail, because `AGENTS.md` has changed since.
   ```bash
   cd ~/Factory/paperloft && git tag -a acceptance-v1 9ad4c75 -m "Acceptance baseline: kit plus owner-approved AGENTS.md amendments"
   ```
   ```bash
   cd ~/Factory/paperloft && git push origin acceptance-v1
   ```
   ```bash
   cd ~/Factory/paperloft && scripts/verify_lock.sh
   ```
   Expect every line to be PASS. Once the tag ruleset is on, the tag can't move. A future change to a frozen file would need a new tag (the script honours `ACCEPTANCE_TAG`).
2. **Run the full preflight:**
   ```bash
   cd ~/Factory/paperloft && scripts/preflight_check.sh --log
   ```
   No line may say FAIL; confirm the MANUAL lines by eye.
3. **Supervised shakedown** (SPEC §4, about 90 minutes with you at the Mac).
   - Tell the agent "start the shakedown".
   - It builds, tests, drives the UI, buys the yearly product in the local StoreKit file, archives, exports and uploads a throwaway build 0.0.1, confirms it through the API, then repeats key steps after a reboot.
   - Fix each dialog it surfaces until a post-reboot pass is clean.
4. After that, the owner authorization in `docs/DISTRIBUTION-AUTHORIZATION.md` applies: distribution signing, archives and uploads happen only once readiness checks pass. **Submission for review and public release stay blocked** until you explicitly say otherwise.

## What still blocks the release after this (agent-side)

These don't need you:
- speed (AC-10)
- accessibility (AC-13; the proposal needs your decision)
- purchase-flow tests (AC-11, possible once the products exist)
- design review (AC-16)
- QA personas (AC-17)
- release checker and screenshots (AC-18)
- PRIVACY.md, SUPPORT.md and in-app Help (AC-20)
- the independent final verification (AC-21)
