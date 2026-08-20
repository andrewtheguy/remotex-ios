import SwiftUI
import WebKit

/// The WebView, its configuration, and whether the last load failed.
///
/// One gateway, one page, no browser around it: no back/forward, no address bar,
/// no tabs. Everything remotex does — the target picker, the login, the desktop,
/// the clipboard — is that page's own, and this file must not grow a second version
/// of any of it.
///
/// v1 carries the desktop's sound **out** and nothing in: no camera, no microphone.
/// A target with `camera = true` will find no device here, which is a scope line and
/// not a bug — MS-RDPECAM needs `getUserMedia` plus a `VideoEncoder`, and neither is
/// worth carrying until the audio path is known good on this device.
final class WebSession: NSObject, ObservableObject {
    let webView: WKWebView
    private let url: URL

    /// The last load failure, in WebKit's words. Nil while the page is up.
    @Published private(set) var failure: String?

    init(url: URL) {
        self.url = url

        let configuration = WKWebViewConfiguration()
        // The desktop's sound is not a media element the operator presses play on:
        // remotex hands decoded packets to Web Audio, so a gesture requirement
        // would simply mean silence.
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.allowsPictureInPictureMediaPlayback = false
        // .mobile rather than the iPad's default desktop-class content mode. The
        // client reads touch off navigator.maxTouchPoints (CAN_PINCH_ZOOM); a
        // desktop user agent would put a touch screen on the pointer path, which
        // wants a pointer this device does not have.
        configuration.defaultWebpagePreferences.preferredContentMode = .mobile

        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()

        webView.navigationDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        // Pinch zoom belongs to the page on a touch client: it scales the
        // framebuffer itself, and WebKit's own gesture would be a second thing
        // reading the same two fingers.
        webView.scrollView.pinchGestureRecognizer?.isEnabled = false
        webView.scrollView.bouncesZoom = false
        // Left on in Release too: when something goes wrong it goes wrong in the
        // page, and Safari's Web Inspector is the only way to see it from here.
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }

        load()
    }

    func load() {
        failure = nil
        webView.load(URLRequest(url: url))
    }
}

extension WebSession: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        failure = nil
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        report(error)
    }

    func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation!,
        withError error: Error
    ) {
        report(error)
    }

    /// A load this app replaced is not a failure to put on screen; every other one
    /// is, because a wrapper with no address bar gives the operator nowhere else to
    /// read it.
    private func report(_ error: Error) {
        let error = error as NSError
        guard error.domain != NSURLErrorDomain || error.code != NSURLErrorCancelled else {
            return
        }
        failure = error.localizedDescription
    }
}

/// The WebView as a SwiftUI view. Its lifetime is the session's, not this
/// struct's — SwiftUI rebuilds the struct freely and must not reload the page.
struct WebViewHost: UIViewRepresentable {
    let session: WebSession

    func makeUIView(context: Context) -> WKWebView { session.webView }

    func updateUIView(_ webView: WKWebView, context: Context) {}
}
