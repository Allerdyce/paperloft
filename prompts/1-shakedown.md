Shakedown, pass 1. I am at the Mac. The goal is to prove that nothing on this machine will prompt during the real run.

Read AGENTS.md and SPEC.md section 4, then run shakedown steps 1 to 10 in order, then step 12.

- Step 2: create the real Xcode project skeleton from SPEC.md 6.2 (folder-synchronized groups, the PaperloftKit local package, app, unit test and UI test targets, App Sandbox entitlements, the bundle ID and team from ~/Factory/.secrets/asc.env). The real run keeps this project.
- Step 5: also capture one 2880 x 1800 screenshot of the app window the way P8 will, so any Screen Recording prompt shows up now.
- Step 8: upload as version 0.0.1, build 1. Never submit it for review.
- Step 12: wait 30 minutes with nothing running, then repeat step 5.
- Also spawn each subagent in .codex/agents/ once with the task "reply with your name and the model you are running", so a bad config fails now.

After every step, take a Computer Use screenshot and look for any system dialog. Record the step, command, result and any dialog in PREFLIGHT_LOG.md. If a dialog appears, stop and tell me what it says; I will fix the setting, then you re-run that step.

When done: add a check to scripts/preflight_check.sh for every dialog you saw (except the frozen scripts, which you must not touch), commit everything on branch shakedown, push, and give me a short summary. I will then reboot for pass 2.
