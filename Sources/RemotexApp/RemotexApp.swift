import SwiftUI

@main
struct RemotexApp: App {
    init() {
        AudioOutput.prepare()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

/// Setup or session, and nothing between them.
struct RootView: View {
    @StateObject private var store = EndpointStore()
    @State private var editing = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let url = store.url, !editing {
                SessionView(url: url, onChangeEndpoint: { editing = true })
                    // Identity is the endpoint: a different one is a different
                    // session, the same one survives a cancelled edit unreloaded.
                    .id(url)
            } else {
                EndpointSetupView(
                    current: store.url,
                    onCommit: { url in
                        store.set(url)
                        editing = false
                    },
                    onCancel: store.url == nil ? nil : { editing = false }
                )
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        // The home indicator too: on an iPad this app is the screen.
        .persistentSystemOverlays(.hidden)
    }
}
