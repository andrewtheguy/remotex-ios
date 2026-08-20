import SwiftUI

/// The page, edge to edge, and the two controls that are not the page's.
struct SessionView: View {
    @StateObject private var session: WebSession
    private let onChangeEndpoint: () -> Void
    @State private var showingMenu = false

    init(url: URL, onChangeEndpoint: @escaping () -> Void) {
        _session = StateObject(wrappedValue: WebSession(url: url))
        self.onChangeEndpoint = onChangeEndpoint
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            WebViewHost(session: session)
                .ignoresSafeArea()

            if let failure = session.failure {
                FailureView(
                    message: failure,
                    onRetry: { session.load() },
                    onChangeEndpoint: onChangeEndpoint
                )
            } else {
                handle
            }
        }
    }

    /// The whole of this app's chrome: a dot in the corner. Anything larger would
    /// be taking back the screen the bundle exists to give away.
    private var handle: some View {
        Button {
            showingMenu = true
        } label: {
            Circle()
                .fill(.white.opacity(0.22))
                .frame(width: 10, height: 10)
                .padding(14)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .confirmationDialog("remotex", isPresented: $showingMenu, titleVisibility: .hidden) {
            Button("Reload") { session.load() }
            Button("Change endpoint…") { onChangeEndpoint() }
            Button("Cancel", role: .cancel) {}
        }
    }
}

/// What a load failure looks like when there is no address bar to read it in.
private struct FailureView: View {
    let message: String
    let onRetry: () -> Void
    let onChangeEndpoint: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 20) {
                Text("Could not reach the gateway")
                    .font(.title2.weight(.semibold))
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 520)
                HStack(spacing: 12) {
                    Button("Try again", action: onRetry)
                        .buttonStyle(.borderedProminent)
                    Button("Change endpoint…", action: onChangeEndpoint)
                        .buttonStyle(.bordered)
                }
            }
            .padding(40)
        }
    }
}
