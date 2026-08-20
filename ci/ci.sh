#!/usr/bin/env bash
# Run this repo's checks natively on this Mac.
#
#   ci/ci.sh            # simulator build, bundle assertions, launch smoke test
#   ci/ci.sh simulator  # only that
#   ci/ci.sh device     # the signed device slice — the artifact an iPad installs
#   ci/ci.sh --list
#
# No job needs a physical device, which is the point: this checkout lives in a
# macOS VM that can compile, sign and run the Simulator but can never pair with an
# iPad. `device` is not in the default set because it is the one job that needs a
# Team ID and reaches Apple for a profile; ask for it by name.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

ALL_JOBS=(simulator bundle smoke device)
DEFAULT_JOBS=(simulator bundle smoke)

# Whichever iPad this Xcode installed, rather than a model name that goes stale
# with the next release. An iPad and not an iPhone because the app is iPad-only
# (TARGETED_DEVICE_FAMILY 2): an iPhone destination matches no device at all.
default_ipad() {
    # The model name keeps its own parentheses ("iPad Pro 13-inch (M5)"), so the
    # UDID's are matched by shape rather than by being the first ones on the line.
    xcrun simctl list devices available \
        | sed -n 's/^ *\(iPad.*\) ([0-9A-Fa-f-]\{36\}) (.*/\1/p' \
        | head -1
}
SIM_NAME=${REMOTEX_CI_SIM:-$(default_ipad)}
BUNDLE_ID=com.andrewtheguy.remotex
DERIVED_SIM=build/ci/DerivedData-sim
DERIVED_DEVICE=build/ci/DerivedData-device

usage() { echo "usage: $0 [--list] [${ALL_JOBS[*]}]" >&2; exit 2; }

jobs=()
while [ $# -gt 0 ]; do
    case $1 in
        --list)
            printf '%s\n' "available: ${ALL_JOBS[*]}" "default:   ${DEFAULT_JOBS[*]}"
            exit 0 ;;
        -h|--help) usage ;;
        *)
            for known in "${ALL_JOBS[@]}"; do
                [ "$1" = "$known" ] && { jobs+=("$1"); shift; continue 2; }
            done
            echo "unknown job: $1" >&2; usage ;;
    esac
done
if [ ${#jobs[@]} -eq 0 ]; then jobs=("${DEFAULT_JOBS[@]}"); fi

info() { echo "[ci] $*"; }
step() { echo; echo "=== $* ==="; }
die() { echo "[ci] error: $*" >&2; exit 1; }

command -v xcodebuild >/dev/null || die 'xcodebuild not found — install Xcode and run xcode-select'
command -v xcodegen >/dev/null || die 'xcodegen not found (brew install xcodegen)'

job_simulator() {
    step 'simulator build'
    xcodegen generate
    xcodebuild build \
        -project Remotex.xcodeproj \
        -scheme RemotexApp \
        -configuration Debug \
        -destination "platform=iOS Simulator,name=$SIM_NAME" \
        -derivedDataPath "$DERIVED_SIM" \
        CODE_SIGNING_ALLOWED=NO
}

# The four Info.plist facts that are this bundle's entire reason to exist, and
# every one of them fails silently: an app that quietly gains a portrait
# orientation, a second scene, or a camera prompt still compiles, links, launches
# and looks fine until it is on the iPad.
job_bundle() {
    step 'bundle assertions'
    local app=$DERIVED_SIM/Build/Products/Debug-iphonesimulator/Remotex.app
    local plist=$app/Info.plist
    [ -f "$plist" ] || die "no simulator build at $app — run the 'simulator' job first"

    local orientations
    orientations=$(plutil -extract 'UISupportedInterfaceOrientations~ipad' json -o - "$plist")
    [ "$orientations" = '["UIInterfaceOrientationLandscapeLeft","UIInterfaceOrientationLandscapeRight"]' ] \
        || die "iPad orientations are $orientations, not the two landscapes"

    [ "$(plutil -extract UIRequiresFullScreen raw -o - "$plist")" = true ] \
        || die 'the bundle no longer requires full screen'
    [ "$(plutil -extract UIApplicationSceneManifest.UIApplicationSupportsMultipleScenes raw -o - "$plist")" = false ] \
        || die 'the bundle now supports multiple scenes, which is multitasking by another name'

    # v1 is audio out and nothing in. A usage description appearing here is the
    # scope line moving, and it moves by accident.
    ! plutil -extract NSCameraUsageDescription raw -o - "$plist" >/dev/null 2>&1 \
        || die 'the bundle asks for the camera, which v1 does not do'
    ! plutil -extract NSMicrophoneUsageDescription raw -o - "$plist" >/dev/null 2>&1 \
        || die 'the bundle asks for the microphone, which v1 does not do'

    info 'landscape-only, full screen, single scene, no capture'
}

# The only check that proves the app gets past launch; everything else stops at
# compile and link.
job_smoke() {
    step "smoke run on the $SIM_NAME simulator"
    local app=$DERIVED_SIM/Build/Products/Debug-iphonesimulator/Remotex.app
    [ -d "$app" ] || die "no simulator build at $app — run the 'simulator' job first"

    xcrun simctl boot "$SIM_NAME" 2>/dev/null || true
    xcrun simctl bootstatus "$SIM_NAME" -b >/dev/null
    xcrun simctl install "$SIM_NAME" "$app"
    local pid
    pid=$(xcrun simctl launch "$SIM_NAME" "$BUNDLE_ID" | sed 's/.*: //')
    info "launched $BUNDLE_ID as pid $pid"

    sleep 5
    # Captured rather than piped into grep -q: -q closes the pipe on the first
    # match, simctl dies of SIGPIPE, and pipefail turns a live app into a crash.
    local running
    running=$(xcrun simctl spawn "$SIM_NAME" launchctl list 2>/dev/null || true)
    case $running in
        *"$BUNDLE_ID"*) ;;
        *) die "$BUNDLE_ID did not survive 5s — check ~/Library/Developer/CoreSimulator/Devices for its crash log" ;;
    esac
    info 'still running after 5s'
    xcrun simctl terminate "$SIM_NAME" "$BUNDLE_ID" >/dev/null 2>&1 || true
}

# The signed device slice. `generic/platform=iOS` builds the device arm64 slice
# without the hardware UDID, which is what lets a device-less VM produce the
# artifact: the iPad's UDID only has to be in the profile, not on this USB bus.
# DEVELOPMENT_TEAM is deliberately not passed on the command line — the point of
# the job is that Developer.local.xcconfig carries it.
job_device() {
    step 'signed device build'
    # The sample file is all comments, and its prose matched a bare `[0-9A-Z]`:
    # copying it without filling anything in used to pass this check.
    local team
    team=$(sed -n 's|^[[:space:]]*DEVELOPMENT_TEAM[[:space:]]*=[[:space:]]*\([^[:space:]/]*\).*|\1|p' \
        Developer.local.xcconfig 2>/dev/null | tail -1 || true)
    [ -n "$team" ] \
        || die 'no Developer.local.xcconfig — copy the sample and fill in your Team ID'
    xcodegen generate
    xcodebuild build \
        -project Remotex.xcodeproj \
        -scheme RemotexApp \
        -configuration Debug \
        -destination 'generic/platform=iOS' \
        -sdk iphoneos \
        -derivedDataPath "$DERIVED_DEVICE" \
        -allowProvisioningUpdates

    local app=$DERIVED_DEVICE/Build/Products/Debug-iphoneos/Remotex.app
    [ -d "$app" ] || die "build did not produce an app at $app"
    codesign --verify --strict "$app" || die "$app failed signature verification"
    [ -f "$app/embedded.mobileprovision" ] \
        || die 'the app has no embedded profile, so no iPad will install it'
    # Captured whole and parsed after, for the same reason as the smoke check: a
    # `| head -1` closes the pipe early and SIGPIPEs codesign under pipefail.
    local details
    details=$(codesign -dv --verbose=2 "$app" 2>&1)
    info "signed: $(awk -F= '/^Authority=/ { print $2; exit }' <<<"$details") (team $(awk -F= '/^TeamIdentifier=/ { print $2; exit }' <<<"$details"))"
    info "$app"
}

info "jobs: ${jobs[*]}"
for job in "${jobs[@]}"; do
    "job_$job"
done

echo
info 'all jobs passed'
