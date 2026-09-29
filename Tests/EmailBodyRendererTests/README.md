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

`EmailBodyPDF` contains PDF data, page count, and the count of navigations rejected
by the delegate. Envelope values are display context, not extraction truth. The
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
