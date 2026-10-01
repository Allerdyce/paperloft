# Icon tray contrast change (owner-approved 2026-10-01)

**Change:** only the `04-tray-front` layer fill, from `#10462A` to `#357C51`. Geometry, the other layers, the Icon Composer glass and the composition are unchanged.

**Measured on the built `.icns`:** relative-luminance contrast of the front tray against the tile beside it.

| Size | Before | After |
| --- | --- | --- |
| 16 px | 1.03:1 | 1.73:1 |
| 32 px | 1.14:1 | 1.92:1 |

The 09-30 mock projected 3.1:1 and 2.6:1, but it used flat colour. The built icon keeps the group's 30% glass translucency, which blends the tray toward the tile. The tray now reads at 32 px (`before-after.png`), and 128 px still matches the artwork.
