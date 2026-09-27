#!/bin/bash
# Paperloft factory pre-flight doctor.
#
# Read-only: it checks the machine and never changes a setting. Every FAIL line
# says how to fix it. The agent runs this at the start of every session and
# must not start work while anything FAILs.
#
# Usage: scripts/preflight_check.sh [--local] [--fast] [--log]
#   --local defer membership, distribution signing and acceptance-tag checks
#           for local development only; never authorizes release or upload
#   --fast  skip the Swift checks (App Store Connect record and products,
#           Foundation Models availability); about 20 seconds faster
#   --log   also write the output to evidence/preflight-latest.txt
#
# Levels: PASS, WARN, FAIL (configuration: fix it, then re-run), TFAIL
# (transient: network, power, a model still downloading; retry later),
# MANUAL (confirm by hand).
#
# Exit 0: no FAIL or TFAIL.  Exit 1: at least one FAIL.
# Exit 3: only TFAILs; wait about 5 minutes and re-run (AGENTS.md section 2).
#
# Written for the bash 3.2 that ships with macOS.

set -u

LOCAL=0
FAST=0
LOG=0
for arg in "$@"; do
  case "$arg" in
    --local) LOCAL=1 ;;
    --fast) FAST=1 ;;
    --log) LOG=1 ;;
    -h|--help) sed -n '2,17p' "$0"; exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FACTORY_DIR="${FACTORY_DIR:-$HOME/Factory}"
ENV_FILE="${ASC_ENV_FILE:-$FACTORY_DIR/.secrets/asc.env}"
MIN_MACOS_MAJOR=27
MIN_FREE_GB=40

if [ "$LOG" -eq 1 ]; then
  mkdir -p "$REPO_DIR/evidence"
  exec > >(tee "$REPO_DIR/evidence/preflight-latest.txt") 2>&1
fi

n_pass=0; n_warn=0; n_fail=0; n_tfail=0; n_manual=0

report() { # level message
  printf '%-6s %s\n' "$1" "$2"
  case "$1" in
    PASS) n_pass=$((n_pass + 1)) ;;
    WARN) n_warn=$((n_warn + 1)) ;;
    FAIL) n_fail=$((n_fail + 1)) ;;
    TFAIL) n_tfail=$((n_tfail + 1)) ;;
    MANUAL) n_manual=$((n_manual + 1)) ;;
  esac
}

# Only explicitly designated release prerequisites may be deferred.
release_report() {
  if [ "$LOCAL" -eq 1 ]; then
    report MANUAL "DEFERRED (local development only): $2"
  else
    report "$1" "$2"
  fi
}

section() { printf '\n== %s ==\n' "$1"; }

# Run a command with a time limit, so a hidden prompt shows up as a failure
# instead of a hang. macOS has no `timeout`, so use perl's alarm.
HAVE_PERL=0
command -v perl >/dev/null 2>&1 && HAVE_PERL=1
with_timeout() { # seconds command...  (stdin closed, so nothing can wait on input)
  local secs="$1"
  shift
  if [ "$HAVE_PERL" -eq 1 ]; then
    perl -e 'alarm shift; exec @ARGV or die "exec failed: $!\n"' "$secs" "$@" </dev/null
  else
    "$@" </dev/null
  fi
}

net_trouble() { # does this output look like a network problem rather than a setup problem?
  echo "$1" | grep -Eqi "could not resolve|timed out|connection refused|network is unreachable|no route to host|http 0"
}

pm_val() { # pmset key -> current value
  pmset -g 2>/dev/null | awk -v k="$1" '$1 == k { print $2; exit }'
}

echo "Paperloft factory pre-flight  $(date '+%Y-%m-%d %H:%M:%S')  user=$(id -un)  repo=$REPO_DIR"
if [ "$HAVE_PERL" -eq 0 ]; then
  echo "WARN   perl not found; checks run without time limits, so a hidden prompt could hang this script"
  n_warn=$((n_warn + 1))
fi

# ---------------------------------------------------------------------------
section "Machine"

os_ver="$(sw_vers -productVersion 2>/dev/null)"
os_major="${os_ver%%.*}"
if [ -n "$os_major" ] && [ "$os_major" -ge "$MIN_MACOS_MAJOR" ] 2>/dev/null; then
  report PASS "macOS $os_ver"
else
  report FAIL "macOS $MIN_MACOS_MAJOR or later required (found ${os_ver:-unknown})"
fi

if [ "$(uname -m)" = "arm64" ]; then
  report PASS "Apple silicon"
else
  report FAIL "Apple silicon required"
fi

me="$(id -un)"
if id -Gn "$me" 2>/dev/null | tr ' ' '\n' | grep -qx admin; then
  report WARN "user '$me' is an admin; a Standard user named builder is recommended (section 3.1)"
else
  report PASS "user '$me' is a Standard user"
fi
if [ "$me" != "builder" ]; then
  report WARN "running as '$me', expected 'builder'"
fi

free_gb="$(df -g "$HOME" 2>/dev/null | awk 'NR == 2 { print $4 }')"
if [ -n "$free_gb" ] && [ "$free_gb" -ge "$MIN_FREE_GB" ] 2>/dev/null; then
  report PASS "${free_gb} GB free"
else
  report FAIL "at least ${MIN_FREE_GB} GB free disk needed (found ${free_gb:-unknown} GB)"
fi

displays="$(with_timeout 60 system_profiler SPDisplaysDataType 2>/dev/null)"
if echo "$displays" | grep -q "Resolution"; then
  if echo "$displays" | grep -qi "retina"; then
    report PASS "Retina-class display connected"
  else
    report WARN "display connected but not Retina-class; 2880x1800 screenshots may need a Retina display or HDMI dummy plug"
  fi
else
  report FAIL "no display detected; connect a display or an HDMI dummy plug (section 3.2)"
fi

# ---------------------------------------------------------------------------
section "Power, sleep, lock, updates"

if pmset -g batt 2>/dev/null | grep -q "AC Power"; then
  report PASS "on wall power"
else
  report TFAIL "not on wall power"
fi

for key in sleep displaysleep disksleep; do
  val="$(pm_val "$key")"
  if [ "$val" = "0" ]; then
    report PASS "pmset $key 0"
  else
    report FAIL "pmset $key is ${val:-unset}; fix: sudo pmset -a $key 0"
  fi
done

val="$(pm_val autorestart)"
if [ "$val" = "1" ]; then
  report PASS "pmset autorestart 1"
else
  report WARN "pmset autorestart is ${val:-unset}; fix: sudo pmset -a autorestart 1"
fi

idle="$(defaults -currentHost read com.apple.screensaver idleTime 2>/dev/null)"
if [ "$idle" = "0" ]; then
  report PASS "screen saver never starts"
elif [ -z "$idle" ]; then
  report WARN "screen saver setting not found; set Lock Screen > Start Screen Saver when inactive to Never"
else
  report FAIL "screen saver starts after ${idle}s; set Lock Screen > Start Screen Saver when inactive to Never"
fi

lock_status="$(with_timeout 20 sysadminctl -screenLock status 2>&1)"
if echo "$lock_status" | grep -qi "screenLock is off"; then
  report PASS "screen lock is off"
else
  report WARN "screen lock may be on ($(echo "$lock_status" | sed 's/.*screenLock/screenLock/' | head -1)); set Lock Screen > Require password to Never"
fi

val="$(defaults read /Library/Preferences/com.apple.SoftwareUpdate AutomaticallyInstallMacOSUpdates 2>/dev/null)"
if [ "$val" = "0" ]; then
  report PASS "automatic macOS update install off"
else
  report WARN "automatic macOS update install may be on; turn it off in Software Update for the run"
fi

val="$(defaults read /Library/Preferences/com.apple.SoftwareUpdate CriticalUpdateInstall 2>/dev/null)"
if [ "$val" = "0" ]; then
  report PASS "automatic security responses off"
else
  report WARN "automatic security responses may be on; turn off in Software Update for the run"
fi

val_new="$(defaults read /Library/Preferences/com.apple.SoftwareUpdate AutomaticallyInstallAppUpdates 2>/dev/null)"
val_old="$(defaults read /Library/Preferences/com.apple.commerce AutoUpdate 2>/dev/null)"
if [ "$val_new" = "0" ] || [ "$val_old" = "0" ]; then
  report PASS "App Store automatic updates off (Xcode will not update mid-run)"
else
  report WARN "App Store automatic updates may be on; turn off in App Store > Settings"
fi

val="$(defaults read /Library/Preferences/com.apple.TimeMachine AutoBackup 2>/dev/null)"
if [ "$val" = "1" ]; then
  report WARN "Time Machine automatic backups on; turn off for the run"
else
  report PASS "Time Machine automatic backups off"
fi

for key in BluetoothAutoSeekKeyboard BluetoothAutoSeekPointingDevice; do
  val="$(defaults read /Library/Preferences/com.apple.Bluetooth "$key" 2>/dev/null)"
  if [ "$val" = "0" ]; then
    report PASS "$key off"
  else
    report WARN "$key not off; only matters without a wired keyboard and mouse (section 3.2)"
  fi
done

# ---------------------------------------------------------------------------
section "Xcode and UI automation"

dev_dir="$(xcode-select -p 2>/dev/null)"
case "$dev_dir" in
  */Xcode*.app/Contents/Developer)
    report PASS "xcode-select: $dev_dir"
    case "$dev_dir" in
      *[Bb]eta*) report WARN "Xcode is a beta; the spec expects the current release Xcode" ;;
    esac
    ;;
  *)
    report FAIL "xcode-select points to '${dev_dir:-nothing}'; fix: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
    ;;
esac

xc_ver="$(xcodebuild -version 2>/dev/null | head -1)"
if [ -n "$xc_ver" ]; then
  report PASS "$xc_ver"
else
  report FAIL "xcodebuild not usable; fix: sudo xcodebuild -license accept"
fi

if with_timeout 60 xcodebuild -checkFirstLaunchStatus >/dev/null 2>&1; then
  report PASS "Xcode first launch complete"
else
  report FAIL "Xcode first-launch tasks pending; fix: sudo xcodebuild -runFirstLaunch"
fi

if DevToolsSecurity -status 2>/dev/null | grep -qi "enabled"; then
  report PASS "developer mode enabled"
else
  report FAIL "developer mode off; fix: sudo DevToolsSecurity -enable"
fi

if dseditgroup -o checkmember -m "$me" _developer >/dev/null 2>&1; then
  report PASS "$me is in _developer"
else
  report FAIL "$me not in _developer; fix: sudo dseditgroup -o edit -a $me -t user _developer"
fi

# Only ever read the status here. Running the enable command unattended can hang.
amt="$(with_timeout 20 automationmodetool 2>&1)"
if echo "$amt" | grep -q "DOES NOT REQUIRE"; then
  report PASS "UI automation needs no password"
else
  report FAIL "UI automation will ask for a password; fix (from an admin account): sudo automationmodetool enable-automationmode-without-authentication"
fi

# ---------------------------------------------------------------------------
section "Signing and keychain"

ids="$(security find-identity -v -p codesigning 2>/dev/null)"
all_ids="$(security find-identity -v 2>/dev/null)"
for name in "Apple Development" "Apple Distribution"; do
  if echo "$ids" | grep -q "\"$name"; then
    report PASS "identity: $name"
  else
    release_report FAIL "no valid '$name' identity; create it in Xcode > Settings > Accounts > Manage Certificates (section 3.3)"
  fi
done
if echo "$all_ids" | grep -Eq "3rd Party Mac Developer Installer|Mac Installer Distribution"; then
  report PASS "identity: Mac Installer Distribution"
else
  release_report FAIL "no Mac Installer Distribution identity; create it in Xcode > Settings > Accounts > Manage Certificates"
fi

keychain="$HOME/Library/Keychains/login.keychain-db"
kc_info="$(with_timeout 20 security show-keychain-info "$keychain" 2>&1)"
if echo "$kc_info" | grep -q "no-timeout"; then
  report PASS "login keychain does not auto-lock"
else
  report FAIL "login keychain auto-locks; fix: security set-keychain-settings $keychain"
fi
if echo "$kc_info" | grep -q "lock-on-sleep"; then
  report WARN "login keychain locks on sleep"
fi

# The most common hidden prompt: codesign asking to use the private key.
dev_hash="$(echo "$ids" | awk '/"Apple Development/ { print $2; exit }')"
if [ "$LOCAL" -eq 0 ] && [ -n "$dev_hash" ]; then
  probe_dir="$(mktemp -d)"
  cp /usr/bin/true "$probe_dir/probe"
  if with_timeout 30 codesign --force --sign "$dev_hash" "$probe_dir/probe" >/dev/null 2>&1; then
    report PASS "codesign works with no keychain prompt"
  else
    report FAIL "codesign failed or waited on a prompt; fix: security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k '<password>' $keychain"
  fi
  rm -rf "$probe_dir"
fi

# ---------------------------------------------------------------------------
section "Secrets and App Store Connect"

case "$ENV_FILE" in
  "$REPO_DIR"/*) report FAIL "secrets file is inside the repo; move it to $FACTORY_DIR/.secrets/" ;;
esac

if [ -f "$ENV_FILE" ]; then
  perm="$(stat -f '%Lp' "$ENV_FILE" 2>/dev/null)"
  if [ "$perm" = "600" ]; then
    report PASS "secrets file present, mode 600"
  else
    report WARN "secrets file mode is ${perm:-unknown}; fix: chmod 600 $ENV_FILE"
  fi
  set -a
  # shellcheck disable=SC1090
  . "$ENV_FILE"
  set +a
  for var in ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_PATH TEAM_ID BUNDLE_ID APP_NAME SUPPORT_EMAIL SITE_DOMAIN LEGAL_ENTITY; do
    if [ "$LOCAL" -eq 1 ]; then
      case "$var" in
        ASC_KEY_ID|ASC_ISSUER_ID|ASC_KEY_PATH|TEAM_ID)
          release_report FAIL "$var requires active membership before release"
          continue ;;
      esac
    fi
    val="${!var:-}"
    case "$val" in
      "") report FAIL "$var missing from $ENV_FILE" ;;
      ABC123DEFG|00000000-0000-0000-0000-000000000000|ABCDE12345|com.example.*|*@example.com|*AuthKey_ABC123DEFG.p8)
        report FAIL "$var still has the example value from asc.env.example" ;;
      *) report PASS "$var set" ;;
    esac
  done
  sec_perm="$(stat -f '%Lp' "$(dirname "$ENV_FILE")" 2>/dev/null)"
  if [ "$sec_perm" != "700" ]; then
    report WARN "secrets folder mode is ${sec_perm:-unknown}; fix: chmod 700 $(dirname "$ENV_FILE")"
  fi
  key_file="${ASC_KEY_PATH:-}"
  key_file="${key_file/#\~/$HOME}"
  if [ -n "$key_file" ] && [ -f "$key_file" ]; then
    report PASS "App Store Connect key file present"
  else
    release_report FAIL "App Store Connect key file not found at '${ASC_KEY_PATH:-}'"
  fi
  if [ -n "${TEAM_ID:-}" ] && ! echo "$ids" | grep -q "($TEAM_ID)"; then
    release_report FAIL "no signing identity for team $TEAM_ID"
  fi
else
  report FAIL "secrets file not found at $ENV_FILE (section 3.4)"
fi

if [ "$LOCAL" -eq 0 ]; then
code="$(with_timeout 20 curl -sS -o /dev/null -w '%{http_code}' https://api.appstoreconnect.apple.com/v1/apps 2>/dev/null)"
if [ "$code" = "401" ] || [ "$code" = "200" ]; then
  report PASS "App Store Connect API reachable"
else
  report TFAIL "App Store Connect API not reachable (HTTP ${code:-none})"
fi

if [ "$FAST" -eq 0 ] && [ -f "$ENV_FILE" ]; then
  asc_out="$(with_timeout 240 xcrun swift "$REPO_DIR/scripts/asc_ping.swift" 2>&1)"
  asc_rc=$?
  case "$asc_out" in
    *ASC_OK*)
      report PASS "app record: $(echo "$asc_out" | grep ASC_OK | head -1 | sed 's/^ASC_OK //')"
      for suffix in pro.yearly pro.lifetime; do
        if echo "$asc_out" | grep -qx "ASC_PRODUCT ${BUNDLE_ID:-}.$suffix"; then
          report PASS "in-app product ${BUNDLE_ID:-}.$suffix"
        else
          report FAIL "in-app product ${BUNDLE_ID:-}.$suffix not found in App Store Connect (section 3.4)"
        fi
      done
      if echo "$asc_out" | grep -q "ASC_WARN"; then
        report WARN "$(echo "$asc_out" | grep ASC_WARN | head -1)"
      fi
      ;;
    *ASC_NO_APP*)
      report FAIL "no App Store Connect app record for ${BUNDLE_ID:-?}; create it in the web UI (section 3.4)"
      ;;
    *ASC_AUTH_FAILED*)
      report FAIL "App Store Connect rejected the API key; check key ID, issuer ID, key file and role"
      ;;
    *)
      if net_trouble "$asc_out" || [ "$asc_rc" -eq 142 ]; then
        report TFAIL "App Store Connect check could not connect (exit $asc_rc): $(echo "$asc_out" | tail -1)"
      else
        report FAIL "App Store Connect check failed (exit $asc_rc): $(echo "$asc_out" | tail -1)"
      fi
      ;;
  esac
fi

fi # release-only App Store Connect checks

# ---------------------------------------------------------------------------
if [ "$LOCAL" -eq 1 ]; then
  release_report FAIL "App Store Connect API, app record and products require full preflight before release"
fi
section "Apple Intelligence"

if [ "$FAST" -eq 0 ]; then
  fm_out="$(with_timeout 240 xcrun swift "$REPO_DIR/scripts/fm_check.swift" 2>&1)"
  fm_rc=$?
  case "$fm_out" in
    *FM_UNAVAILABLE*NotReady*|*FM_UNAVAILABLE*notReady*)
      report TFAIL "on-device model not ready yet (still downloading or updating); retry later"
      ;;
    *FM_UNAVAILABLE*)
      report FAIL "on-device model unavailable: $(echo "$fm_out" | grep FM_UNAVAILABLE | head -1 | sed 's/^FM_UNAVAILABLE: //'); turn on Apple Intelligence and wait for the models to download"
      ;;
    *FM_OK*)
      report PASS "on-device model available"
      ;;
    *)
      report FAIL "could not compile or run fm_check.swift (exit $fm_rc): $(echo "$fm_out" | tail -1)"
      ;;
  esac
else
  report MANUAL "Foundation Models check skipped (--fast)"
fi

# ---------------------------------------------------------------------------
section "Repo and GitHub"

case "$REPO_DIR" in
  "$HOME/Desktop"*|"$HOME/Documents"*|"$HOME/Downloads"*)
    report FAIL "repo is in a privacy-protected folder; move it to $FACTORY_DIR" ;;
  "$FACTORY_DIR"/*)
    report PASS "repo is under $FACTORY_DIR" ;;
  *)
    report WARN "repo is outside $FACTORY_DIR" ;;
esac

if git -C "$REPO_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  report PASS "git repository"
  origin="$(git -C "$REPO_DIR" remote get-url origin 2>/dev/null)"
  case "$origin" in
    git@github-paperloft:*) report PASS "origin uses the github-paperloft deploy key" ;;
    *) report WARN "origin is '${origin:-unset}'; expected git@github-paperloft:<owner>/paperloft.git" ;;
  esac
  if git -C "$REPO_DIR" rev-parse -q --verify "refs/tags/acceptance-v1" >/dev/null 2>&1; then
    report PASS "tag acceptance-v1 present"
  else
    release_report FAIL "tag acceptance-v1 missing; commit the kit, tag it and push (section 3.5)"
  fi
else
  report FAIL "$REPO_DIR is not a git repository"
fi

for host in github-paperloft github-paperloft-site; do
  ssh_out="$(with_timeout 25 ssh -o BatchMode=yes -o ConnectTimeout=10 -T "git@$host" 2>&1)"
  if echo "$ssh_out" | grep -q "successfully authenticated"; then
    report PASS "ssh $host"
  elif net_trouble "$ssh_out"; then
    report TFAIL "ssh $host: $(echo "$ssh_out" | head -1)"
  else
    report FAIL "ssh $host: $(echo "$ssh_out" | head -1); check the Host block in ~/.ssh/config and the deploy key (section 3.5)"
  fi
done

if [ -d "$FACTORY_DIR/paperloft-site/.git" ]; then
  report PASS "site repo cloned at $FACTORY_DIR/paperloft-site"
else
  report FAIL "site repo not cloned; fix: git clone git@github-paperloft-site:<owner>/paperloft-site.git $FACTORY_DIR/paperloft-site"
fi

# ---------------------------------------------------------------------------
section "Site domain"

if [ -n "${SITE_DOMAIN:-}" ]; then
  a_records="$(with_timeout 15 dig +short A "$SITE_DOMAIN" 2>/dev/null)"
  if echo "$a_records" | grep -q "^185\.199\.1[01][0-9]\.153$"; then
    report PASS "$SITE_DOMAIN points at GitHub Pages"
  elif [ -z "$a_records" ]; then
    if with_timeout 15 dig +short A apple.com 2>/dev/null | grep -q .; then
      report FAIL "$SITE_DOMAIN has no A records; point it at GitHub Pages (section 3.5)"
    else
      report TFAIL "DNS lookups are failing; check the network"
    fi
  else
    report FAIL "$SITE_DOMAIN points at $(echo "$a_records" | tr '\n' ' ')instead of GitHub Pages (185.199.108-111.153)"
  fi
fi

for dir in "$FACTORY_DIR/holdout" "$FACTORY_DIR/private-samples"; do
  case "$dir" in
    "$REPO_DIR"/*) report FAIL "$dir must be outside the repo" ;;
  esac
done

# ---------------------------------------------------------------------------
section "Confirm by hand (not readable from a script)"

report MANUAL "Focus: Do Not Disturb on, always, no allowed people or apps"
report MANUAL "Codex: Full access for this project; Prevent sleep while running on; notifications off; memories off"
report MANUAL "Computer Use: Screen Recording and Accessibility granted; Locked use on; Always allow Xcode, Finder, Preview (and the app after the shakedown)"
report MANUAL "GitHub rulesets: no force-push to main; acceptance-* tags cannot be updated or deleted"
report MANUAL "App Store Connect: Paid Apps Agreement active; Small Business Program enrolled"

# ---------------------------------------------------------------------------
printf '\nSummary: %d PASS, %d WARN, %d FAIL, %d TFAIL, %d MANUAL\n' "$n_pass" "$n_warn" "$n_fail" "$n_tfail" "$n_manual"
if [ "$n_fail" -gt 0 ]; then
  echo "NO-GO: fix every FAIL before starting a run."
  exit 1
fi
if [ "$n_tfail" -gt 0 ]; then
  echo "WAIT: only transient failures; re-run in about 5 minutes."
  exit 3
fi
if [ "$LOCAL" -eq 1 ]; then
  echo "GO: LOCAL DEVELOPMENT ONLY. Distribution signing, upload and release remain blocked."
else
  echo "GO"
fi
exit 0
