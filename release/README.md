# Release materials (drafts for the owner)

- `metadata.md`: App Store listing (subtitle, keywords, description, promotional text), in-app purchase metadata, age rating answers and review notes (SPEC 6.8). Nothing has been entered in App Store Connect.
- `screenshots/1…5-*.png`: the five 2880 × 1800 App Store screenshots, captured from the real app with the sample receipts and the on-device model.
- `screenshots/iap-review-paywall.png`: the paywall, as the review screenshot for both in-app purchases. The mock controls are hidden.

**To regenerate the screenshots:** run `AppStoreScreenshotTests` (UI tests). It sizes the main window to 1440 × 900 points with the Debug/QA-only `-PaperloftWindowSize` hook, waits until the model has read every sample, and attaches the images as `AppStore-*`.
