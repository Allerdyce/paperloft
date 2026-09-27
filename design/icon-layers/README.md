# Icon Composer layer preparation

Draft vector reconstruction of the owner-provided design/app-icon-source.png, preserving the cream torn receipt, two green lines, folded corner and green tray. All layers share a1024-square canvas; use background#083920 in Icon Composer. Tray#10462A, paper#F8F1E0, lines#104A2E match SPEC6.5. The back tray contains a dark cavity; the folded corner remains separate so native effects can define its edge. No baked shadows, texture or icon mask.

Import in numbered back-to-front order into Icon Composer, keep aligned at native canvas position, then inspect native materials and small-size contrast. These are editable preparation assets, not a completed .icon or accepted product icon. Native build integration and independent critic at16/32/128px remain pending. Do not replace the owner source or redesign colors without a documented proposal.

Apple workflow reference: https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer . SVG layers, background/effects and saved .icon are supported; use the actual tool to author its package rather than guessing an undocumented manifest.

Local rendering check: macOS Quick Look successfully produced1024px thumbnails for all four SVGs. Each was visually inspected against the owner source: receipt retains two rounded lines and torn edge, fold is separate, back tray has a cavity, and front tray has the center notch. No clipping or missing layer was observed. This is only individual-layer validation, not the composited native material result or16/32/128px acceptance. Thumbnails/log are under build/icon-preview.
