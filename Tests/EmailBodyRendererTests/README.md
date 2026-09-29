# Offline email body renderer

`Apps/PaperloftApp/EmailBodyRenderer.swift` provides the app-layer,
`@MainActor EmailBodyRendering` protocol and `OfflineEmailBodyRenderer`.
Only render the body after the intake pipeline chooses it as the receipt candidate.
The renderer does not parse MIME, choose attachments, open source files, save an
email, or change the library/index.

```swift
let request = EmailBodyRenderRequest(
    body: .plainText(document.body), // or .html(untrustedHTML)
    envelope: .init(
        from: document.envelope?.from ?? "",
        to: document.envelope?.to ?? "",
        date: document.envelope?.date ?? "",
        subject: document.envelope?.subject ?? ""
    )
)
let result = try await OfflineEmailBodyRenderer().render(request)
// Persist result.data in an app-owned destination through normal intake.
```

`EmailBodyPDF` contains body-only extraction text, PDF data, page count, the
selected engine, a fallback diagnostic code when applicable, and the count of
navigations rejected by the delegate. Envelope values are display context, not extraction truth. The
protocol can be replaced with a stub in intake tests. The app target discovers the
new source through its synchronized folder; the unit target needs an explicit
source reference if it compiles AppModel directly. This change does not edit the
Xcode project or intake integration.

## Safety and limits

Untrusted HTML is converted to text by a bounded native tokenizer. Attributes,
resource elements, scripts, CSS and hidden sections are discarded before WebKit
sees anything. Paragraphs and table rows/cells preserve basic reading order.
Entity-decoded text and envelope fields are escaped into one fixed template.
Unknown HTML entities remain literal. Malformed HTML fails closed.

This deliberately does **not** reproduce original HTML colors, column geometry,
logos, images, links or fonts. It produces a readable, searchable monochrome
transcription with From, To, Date and Subject first. Each page has fixed letter
paper dimensions, and only text is passed to WebKit.

Additional defenses: nonpersistent website data store; content JavaScript disabled;
script window opening disabled; a block-all content rule list; deny-by-default
navigation (only the initial in-memory `about:blank` document is allowed); and CSP
with no resource sources, scripts, frames, base URL or forms. No JavaScript is
evaluated by native code. No network entitlement is added.

Defaults/hard ceilings:

- 256 KiB body and 4 KiB per envelope field; at most 64 Unicode scalars per grapheme.
- 40 real PDF pages, 612 × 792 points each, 38 pre-wrapped text lines per page.
- 32 MiB PDF output; 15-second WebKit deadline (configurable from 1 ms to 30 seconds).
- Cancellation and timeout stop loading and resolve the caller once. The payload
  and page limits bound synchronous native preparation before the WebKit deadline.

## Repeatable synthetic checks

Run from the repository root on the native Mac session; reserve the project's
GUI lock while running. The harness uses an application with activation prohibited
and never creates or displays a window.

```sh
mkdir -p build/email-render
xcrun swiftc -swift-version 6 -warnings-as-errors -parse-as-library Apps/PaperloftApp/EmailBodyRenderer.swift Tests/EmailBodyRendererTests/EmailBodyRendererSmoke.swift -o build/email-render/EmailBodyRendererSmoke
build/email-render/EmailBodyRendererSmoke
build/email-render/EmailBodyRendererSmoke --native
```

The harness verifies:

- PDFKit opens output and extracts selectable envelope/body text.
- A 95-line body produces three separate letter-size pages, with every line
  appearing exactly once and the last line retained.
- Malicious scripts, CSS imports/font URLs, images/srcset, iframes, SVG, objects,
  video, forms, base URLs and refresh tags do not survive as resource markup.
- A positively controlled loopback-only listener observes zero connections from
  the malicious document; the delegate observes zero external navigations.
- Body/header/grapheme/page limits, malformed HTML, timeout and cancellation fail
  with the expected error. A synthetic PDF is written under `build/email-render`.

The navigation counter is not a system-wide network monitor. The loopback probe
checks actual attempted connections to every resource URL in that synthetic HTML;
it does not claim to measure unrelated system traffic. The primary guarantee is
that original resource-bearing markup never reaches WebKit, with CSP, content
rules and delegate restrictions as additional layers.

Local renderer checks do not establish the full 1.1 gate: MIME coverage, document
selection, real email fidelity, live Mail dragging and signed app integration need
separate verification.

## Confirmed sandbox limitation and explicit fallback

On macOS 27 / Xcode 27 (2026-09-29), the headless, ad-hoc-signed probe with only
`com.apple.security.app-sandbox=true` reproduced WebKit content-process termination.
The same WebKit-only harness succeeds without App Sandbox. Rule-list compilation
succeeded: the fixed diagnostic is domain `app.paperloft.email-renderer`, code
**1002** (WebContent terminated), not **1001** (rule-list unavailable). No email
content, URL, sender or subject is included in these diagnostics.

The renderer's default `.automatic` policy now falls back on those two explicit
startup failures to native CoreText/CoreGraphics PDF generation. It consumes the
same bounded, sanitized, pre-wrapped text, retains selectable text and real letter
pages, and never grants network access. A failed WebKit startup is cached for the
process so every subsequent receipt does not restart the failing WebKit process.
Timeouts, cancellation, malformed content and limits remain errors; they are not
silently converted into successes. Tests may request `.webKitOnly` or `.nativeOnly`.

**This is an implementation deviation from the specified WebKit rendering path.**
A successful native fallback is not evidence that sandboxed WebKit works, and is
not a full 1.1 acceptance verdict. The no-outgoing-network contract is preserved.
The historical issue is also described in the [original reporter's reproduction](https://github.com/feedback-assistant/reports/issues/1)
and [Apple Developer Forums discussion](https://developer.apple.com/forums/thread/116359);
current behavior was independently reproduced here, rather than inferred from
those historical reports.

Reproduce the sandbox probe while holding the GUI lock (it creates no windows):

```sh
mkdir -p build/email-render/SandboxProbe.app/Contents/MacOS
cp Tests/EmailBodyRendererTests/SandboxProbe-Info.plist build/email-render/SandboxProbe.app/Contents/Info.plist
xcrun swiftc -swift-version 6 -warnings-as-errors -parse-as-library Apps/PaperloftApp/EmailBodyRenderer.swift Tests/EmailBodyRendererTests/EmailSandboxProbe.swift -o build/email-render/SandboxProbe.app/Contents/MacOS/EmailSandboxProbe
codesign --force --sign - --entitlements Tests/EmailBodyRendererTests/Sandbox.entitlements build/email-render/SandboxProbe.app
build/email-render/SandboxProbe.app/Contents/MacOS/EmailSandboxProbe
codesign -d --entitlements :- build/email-render/SandboxProbe.app
```

The automatic probe passes with engine `nativeText`, diagnostic 1002; all 95 lines
appear exactly once on three letter pages, the header remains selectable but is
excluded from `bodyText`, and malicious HTML retains the visible total while
scripts/resource markup are discarded. Passing `--webkit-only` deliberately
reproduces the platform failure (exit 1, code 1002) on this Mac. Passing
`--native-only` verifies the native path without starting WebKit at all.
