import Foundation

/// Why what was typed is not an endpoint this client can start against.
///
/// The refusals are the page's own (`frontend/src/preflight.ts`): remotex needs a
/// **secure context** for WebCodecs, the clipboard and the keyboard, and the
/// gateway speaks plain HTTP and never TLS. So the secure part comes from where
/// the gateway is reached — HTTPS through a terminating proxy, or loopback. Saying
/// that here, before a load, beats a black WebView showing the same refusal in
/// three lines of the page's own text.
enum EndpointProblem: Error {
    case empty
    case unparseable
    case notHTTP(String)
    case insecure(String)

    var message: String {
        switch self {
        case .empty:
            return "Type the address of your remotex gateway."
        case .unparseable:
            return "That is not an address. A host, or a full https:// URL."
        case let .notHTTP(scheme):
            return "\(scheme):// is not a web address. Use https://."
        case let .insecure(host):
            return """
                http://\(host) is not a secure context, and remotex will refuse to \
                start on one. Reach the gateway over https://, or over an SSH tunnel \
                to localhost.
                """
        }
    }
}

enum Endpoint {
    /// The URL to load, or why there isn't one.
    static func parse(_ typed: String) -> Result<URL, EndpointProblem> {
        let trimmed = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.empty) }
        // A bare host is what anybody types; assume the scheme the client requires
        // rather than making the operator spell it every time.
        let spelled = trimmed.contains("://") ? trimmed : "https://" + trimmed
        guard var parts = URLComponents(string: spelled),
              let host = parts.host, !host.isEmpty
        else {
            return .failure(.unparseable)
        }
        let scheme = (parts.scheme ?? "").lowercased()
        parts.scheme = scheme
        guard scheme == "https" || scheme == "http" else {
            return .failure(.notHTTP(scheme))
        }
        if scheme == "http", !isLoopback(host) {
            return .failure(.insecure(host))
        }
        guard let url = parts.url else { return .failure(.unparseable) }
        return .success(url)
    }

    /// The hosts a browser calls a secure context over plain HTTP: loopback, and
    /// the RFC 6761 `.localhost` names the embedded gateway routes instances under.
    private static func isLoopback(_ host: String) -> Bool {
        let bare = host.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        return bare == "localhost"
            || bare == "127.0.0.1"
            || bare == "::1"
            || bare.hasSuffix(".localhost")
    }
}

/// The one thing this app remembers between launches.
final class EndpointStore: ObservableObject {
    private static let defaultsKey = "endpoint"

    @Published private(set) var url: URL?

    init() {
        url = UserDefaults.standard.string(forKey: Self.defaultsKey)
            .flatMap(URL.init(string:))
    }

    func set(_ url: URL) {
        self.url = url
        UserDefaults.standard.set(url.absoluteString, forKey: Self.defaultsKey)
    }
}
