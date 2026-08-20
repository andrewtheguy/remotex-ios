import SwiftUI

/// The one question this app asks: which gateway.
struct EndpointSetupView: View {
    let current: URL?
    let onCommit: (URL) -> Void
    let onCancel: (() -> Void)?

    @State private var typed: String = ""
    @State private var problem: String?
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 18) {
                Text("remotex")
                    .font(.largeTitle.weight(.semibold))
                Text("The address of your gateway.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                TextField("https://gateway.example", text: $typed)
                    .textFieldStyle(.roundedBorder)
                    .font(.title3)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.go)
                    .focused($focused)
                    .onSubmit(commit)

                if let problem {
                    Text(problem)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 12) {
                    Button("Open", action: commit)
                        .buttonStyle(.borderedProminent)
                    if let onCancel {
                        Button("Cancel", action: onCancel)
                            .buttonStyle(.bordered)
                    }
                }
            }
            .frame(maxWidth: 560)
            .padding(40)
        }
        .onAppear {
            typed = current?.absoluteString ?? ""
            focused = true
        }
    }

    private func commit() {
        switch Endpoint.parse(typed) {
        case let .success(url):
            problem = nil
            onCommit(url)
        case let .failure(reason):
            problem = reason.message
        }
    }
}
