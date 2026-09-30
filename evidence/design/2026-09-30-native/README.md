# AC-16 critique follow-up: native macOS patterns (2026-09-30)

This covers the fixes for the design review in `evidence/design/2026-09-30-critique.md`. The owner's direction was: "lean on macOS patterns unless there's an opportunity to keep the branding / look and feel consistent."

Screenshots in this folder come from UI test runs on the merged code.

## Done

| Critique item | Change | Tests |
| --- | --- | --- |
| Review inbox: no Receipt menu | Receipt › Confirm and File (⌘↩), Remove from Inbox, Next/Previous Document (⌘] / ⌘[). Navigation follows the filtered list. | `ReceiptMenuTests`, `ReceiptNavigationTests` |
| Review inbox: Import/Paste inside the content | Moved to window toolbar items. The empty Inbox keeps its large cards. | `ReceiptLibraryUXTests` |
| Review inbox: chips change width | Checkmark space is reserved. | `ReceiptLibraryUXTests` |
| Review form: label column, widths, warnings, currency | LabeledContent rows share one label column and equal control widths. Warnings outline the control only. Currency is a pop-up ("EUR – Euro"). | `ReviewFormTests` |
| Library: static headers off by 8–10 px, no sort, faint selection, "USD 12.50", ISO dates, no ⌘F | Sortable headers aligned with values, sort kept per window. 2 pt accent selection. Localized currency and dates. Toolbar actions. Edit › Find… (⌘F). | `LibraryAlignmentTests`, `CoreFlowTests` |
| Export sheet: typed year, text dates, early error, layout jumps, Q1 default | Year pop-up, DatePicker fields, no error until end < start, fixed two-row layout, current quarter. Plus File › Export for Accountant… (⇧⌘E). | `ExportSheetTests`, `CoreFlowTests` |
| Settings: raw container path, empty space, 14 fields + 14 ⊖ | Finder-style folder display with Show in Finder. Panes sized to content. Bordered category list with +/−. | `SettingsPolishTests` |
| Onboarding: no View › Show/Hide Sidebar | SidebarCommands (⌃⌘S). | `SettingsPolishTests` |

The accessibility audit stays at the 10 known system findings. One new contrast flag on a 10 pt field warning was fixed by using callout text.

## Kept on purpose

- **Library rounded rows and View buttons.** These come from the owner's visual reference (PLAN.md), so the rows stay and only their behaviour changed. The critique suggested a plain `Table`.
- **Branded sidebar and the serif page title.** They are identity. The frozen `NavigationTests` also requires the sidebar buttons and the "A place for your paperwork" heading.
- **Sidebar Settings page.** An earlier change deliberately keeps it in the main window (`testSidebarSettingsStaysInMainWindow`).
- **Review date as a text field plus calendar.** An unread date must show as empty and highlighted. A DatePicker would fill in a default date.
- **Filter chips instead of a segmented control.** The status colours carry meaning, and the checkmark gives a cue that doesn't rely on colour.
- **Remove from Inbox has no ⌘⌫.** That key deletes to the start of the line while a review field has focus.

## Waiting for the owner

- **Icon small-size contrast.** SPEC §6.5 routes this to the owner. The candidate is in PROPOSALS.md: tray-front `#357C51`, measured at 3.1:1 at 16 px against today's 1.23:1.

## Not yet done

- Native checkboxes for multi-select in Inbox rows.
- Return/⌘O and ⌘⌫ on Library rows. The context menu, double-click and ⌫ via onDeleteCommand already exist.
- Checking Full Keyboard Access focus order, which needs a system setting.
