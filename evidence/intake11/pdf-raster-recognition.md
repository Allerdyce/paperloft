# PDF raster scaling repair — 2026-09-29

## Diagnosis

Synthetic email-001 attachment hash `ecf27a1a6fbc68ab07603a39f45513b823f5b92346cebe21429ed18e72e9cec8` had complete PDFKit selectable text but production OCR returned empty. CoreGraphics raster inspection confirmed visible content. Raw Vision returned zero observations twice at the existing raster geometry, so TextLayout did not discard observations. Segmentation confidence was 0.038, below the 0.8 correction threshold; perspective correction was not involved.

The bitmap was allocated at twice the page dimensions, but CGPDFPage.getDrawingTransform did not upscale content. Its transform for a 612×792 page into a 1224×1584 canvas was a=d=1, translation=(306,396). The original 12-point text remained approximately 12 pixels high, centered in additional whitespace. Merely increasing the canvas to 3x produced partial recognition but retained the geometry error.

## Repair

Scale the bitmap context explicitly, then apply the PDF drawing transform in page-point coordinates. Use the rotated page dimensions for 90/270 degrees. White background, media-box normalization, rotation handling, maximum 2x scale and 2400-pixel longest edge remain bounded. Finite media-box origin/size and finite context scales are required. OCR still operates on visible raster content; no embedded text fallback, invented confidence, parser policy or TextLayout change was introduced. Existing document/image limits remain in place.

## Verification

- Three new deterministic tests PASS: exact 2x ink bounds at zero and nonzero media-box origins; exact ink coordinates, dimensions and orientation for 90/180/270-degree rotations; a 10,000×20,000-point page rendered at 1200×2400 pixels without clipping.
- Full strict package tests PASS: 28 XCTest and 104 Swift Testing tests. Log: `build/recognition-probe/full-package-tests.log`.
- Direct Vision on the corrected synthetic raster returned all six complete lines twice.
- A strict Swift 6 warnings-as-errors standalone build of the actual Recognize.swift and TextLayout.swift, calling the public DocumentRecognizer.text API, returned: Alder Office; RECEIPT; Date: 2026-01-01; Office supplies; Total USD 12.00; Paid by card. Log: `build/recognition-probe/production001-fixed.txt`. Elapsed 64.54 seconds; this cold standalone request remains slow. The earlier process sample showed a Vision/TextRecognition internal semaphore wait, but does not prove its cause. No latency claim is made.

Local probe sources, raster images and logs remain under `build/recognition-probe`. No GUI was driven and no private input was read. This is a rendering correction, not a formal accuracy gate pass. Combined parser/blank-text changes, native integration tests and fresh diagnostic runs must be checked after merge.
