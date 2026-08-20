- purpose: an iPad wrapper around the remotex web client (sibling `../remotex`). It
  asks for a gateway address and loads that page in a full-screen, landscape-only
  WKWebView. Nothing else.
- **there is one client, and it is the page.** This bundle must never grow its own
  target picker, login, clipboard, keyboard, audio or camera handling — all of that
  is the page's, and a second implementation here is the thing to reject in review.
- v1 scope: **audio output only**. The app claims `AVAudioSession` `.playback` so
  Web Audio is not silenced by the ring/silent switch, and it requests no camera and
  no microphone — no `NSCameraUsageDescription`, no `WKUIDelegate` capture grant. A
  `camera = true` target finding no device here is the scope line, not a bug.
- strict no backward compatibility
- the endpoint is validated against the client's entry condition
  (`frontend/src/preflight.ts` in the sibling): secure context only — `https://`,
  or `http://` on loopback and `.localhost`
- iPad only (`TARGETED_DEVICE_FAMILY: "2"`), landscape only, `UIRequiresFullScreen`
- regenerate the project from project.yml after adding sources (`xcodegen generate`)
- `ci/ci.sh` builds for the simulator and smoke-launches it; both jobs run in the
  macOS VM with no device attached
- measured on the iPadOS 26.5 simulator, not assumed: inside `WKWebView` (not
  Safari) `isSecureContext` is true on an https origin and `VideoDecoder`,
  `AudioDecoder`, `VideoEncoder`, `AudioEncoder` and `AudioContext` are all present,
  so the client's preflight passes; `navigator.maxTouchPoints` is 5, so it takes the
  touch path (`CAN_PINCH_ZOOM`). Full screen was measured the same way — the window
  bounds equal the screen's at 1376x1032 landscape under iPadOS 26's windowing
- always use uv to run python scripts
