- purpose: an iPad wrapper around the remotex web client (sibling `../remotex`). It
  asks for a gateway address and loads that page in a WKWebView that fills its
  window. Nothing else.
- **there is one client, and it is the page.** This bundle must never grow its own
  target picker, login, clipboard, keyboard, audio or camera handling — all of that
  is the page's, and a second implementation here is the thing to reject in review.
- v1 scope: **audio output only**. The app claims `AVAudioSession` `.playback` so
  Web Audio is not silenced by the ring/silent switch, and it requests no camera and
  no microphone — no `NSCameraUsageDescription`, no `WKUIDelegate` capture grant. A
  `camera = true` target finding no device here is the scope line, not a bug.
- touch is the page's too. remotex's **Touchscreen** switch forwards fingers to a
  Windows host as MS-RDPEI contacts and Windows reads the gestures; this bundle's
  whole part in it is `.defersSystemGestures(on: .all)` on the web view, so an
  edge swipe reaches the page before iPadOS takes it (the system still gets it on
  a second swipe — nothing disables an iPadOS edge). iPadOS's three- and
  four-finger multitasking gestures collide with Windows' and no app can turn
  them off; that is Settings > Multitasking & Gestures, and not a bug here
- the page is never served from a cache. `WebSession.load` empties WebKit's
  memory, disk and fetch caches and any service-worker registration before every
  load, and requests with `.reloadIgnoringLocalAndRemoteCacheData`, which WebKit
  applies to the subresources too. The data store stays the default persistent
  one on purpose: the page's own settings live in its `localStorage`, and a
  `.nonPersistent()` store would forget them at every launch — that is the wrong
  fix for staleness and the thing to reject in review
- strict no backward compatibility
- the endpoint is validated against the client's entry condition
  (`frontend/src/preflight.ts` in the sibling): secure context only — `https://`,
  or `http://` on loopback and `.localhost`
- iPad only (`TARGETED_DEVICE_FAMILY: "2"`), all orientations, single scene, no
  `UIRequiresFullScreen`. Orientation is the page's problem, not this bundle's
- regenerate the project from project.yml after adding sources (`xcodegen generate`)
- `ci/ci.sh` builds for the simulator and smoke-launches it; both jobs run in the
  macOS VM with no device attached
- measured on the iPadOS 26.5 simulator, not assumed: inside `WKWebView` (not
  Safari) `isSecureContext` is true on an https origin and `VideoDecoder`,
  `AudioDecoder`, `VideoEncoder`, `AudioEncoder` and `AudioContext` are all present,
  so the client's preflight passes; `navigator.maxTouchPoints` is 5, so it takes the
  touch path (`CAN_PINCH_ZOOM`). Full screen was measured the same way — the window
  bounds equal the screen's at 1376x1032 landscape under iPadOS 26's windowing
- measured on an iPad mini (A17 Pro), iPadOS 26.6, built with the iOS 26.2 SDK
  (2026-08-20): iPadOS 26 does not enforce a landscape-only iPad app. A binary
  linked against the 26 SDK gets a resizable scene (`sizeRestrictions` non-nil)
  even with `UIRequiresFullScreen` true, and there the orientation mask is a
  preference; the same binary with its linked-SDK stamp rewritten to 18.0 got the
  old non-resizable scene back, so the gate is the linked SDK, not the plist.
  `UIRequiresFullScreenIgnoredStartingWithVersion=99`, an AppDelegate orientation
  mask and `requestGeometryUpdate(.landscape)` changed nothing. That is why the
  lock was removed rather than kept for 17/18 only (TN3192: the key is deprecated
  in 26 and means discrete resizing in 27). Do not reintroduce it.
- always use uv to run python scripts
