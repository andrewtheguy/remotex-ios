# remotex-ios

A wrapper. It asks for a gateway address and then shows that page on an iPad
with nothing around it — no browser chrome, whatever the window's orientation.

That is the whole feature. remotex has one client — the page a browser loads —
and this bundle adds none of it. v1 carries the desktop's **sound out and nothing
in**: the app claims the `.playback` audio session so the session is not silenced
by a switch nobody associates with a remote desktop, and it asks for no camera and
no microphone. A target with `camera = true` finds no device here. It exists because iPadOS will not give a web
page the screen: Safari keeps its chrome and its gestures, and a home-screen web
clip cannot be installed against an address typed at runtime. An app can, so this
is one.

Touch is the page's as well. Against a Windows host remotex offers a
**Touchscreen** switch that sends fingers through as real touch contacts
(MS-RDPEI), so Windows' own gestures apply — tap, drag, press-and-hold, pinch,
two-finger scroll, edge swipes. The app's one contribution is to defer iPadOS's
edge gestures on the web view, so a swipe from an edge reaches the page first and
the system only on a second swipe. Nothing disables an iPadOS edge, and the
three- and four-finger multitasking gestures are the user's to turn off in
Settings > Multitasking & Gestures if they want Windows' instead.

## Build

Needs Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install
xcodegen`). The `.xcodeproj` is generated and gitignored; regenerate it after
changing `project.yml` or adding sources.

```sh
xcodegen generate
ci/ci.sh                 # simulator build, bundle assertions, launch smoke test
ci/ci.sh device          # the signed slice an iPad installs
open Remotex.xcodeproj   # to run it
```

The default jobs need no Team ID and no hardware. `device` needs both a Team ID —
copy `Developer.local.xcconfig.sample` to `Developer.local.xcconfig` and fill it
in — and a reachable Apple, since it resolves a provisioning profile. It signs
against the team's wildcard profile, so a new bundle identifier needs no App ID
registered by hand.

## The endpoint

The address is checked before it is loaded, against the client's own entry
condition (`frontend/src/preflight.ts` in the remotex tree): remotex needs a
**secure context** for WebCodecs, the clipboard and the keyboard, and the gateway
speaks plain HTTP and never TLS. So `https://` is accepted, `http://` only on
loopback and `.localhost`, and a LAN address on plain HTTP is refused here rather
than by a black page three seconds later.

A gateway behind a self-signed certificate will not load: nothing here overrides
WebKit's trust evaluation. Put a real certificate on the terminating proxy, or
reach it through a tunnel.

Tap the dot in the top-left corner to reload or change the endpoint. It is
remembered across launches.
