import SwiftUI
import AgilitonCore

/// Reusable loading button with built-in error handling
public struct LoadingButton<Label: View>: View {
    let action: () async throws -> Void
    let label: () -> Label

    @State private var isLoading = false
    @State private var error: Error?
    @State private var showError = false

    public init(action: @escaping () async throws -> Void,
                @ViewBuilder label: @escaping () -> Label) {
        self.action = action
        self.label = label
    }

    public var body: some View {
        Button {
            Task {
                await performAction()
            }
        } label: {
            ZStack {
                label()
                    .opacity(isLoading ? 0 : 1)

                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                }
            }
        }
        .disabled(isLoading)
        .alert("Error", isPresented: $showError, presenting: error) { _ in
            Button("OK") {
                error = nil
            }
        } message: { error in
            Text(error.localizedDescription)
        }
    }

    private func performAction() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await action()
        } catch {
            AgilitonLogger.shared.error("Button action failed: \(error.localizedDescription)")
            self.error = error
            showError = true
        }
    }
}

/// Convenience initializer for text buttons
extension LoadingButton where Label == Text {
    public init(_ title: String,
                action: @escaping () async throws -> Void) {
        self.init(action: action) {
            Text(title)
        }
    }
}

// MARK: - Preview

struct LoadingButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            LoadingButton("Save") {
                try await Task.sleep(nanoseconds: 2_000_000_000)
            }
            .buttonStyle(.borderedProminent)

            LoadingButton {
                try await Task.sleep(nanoseconds: 1_000_000_000)
            } label: {
                HStack {
                    Image(systemName: "arrow.up.circle")
                    Text("Upload")
                }
            }
            .buttonStyle(.bordered)

            LoadingButton("Error Test") {
                throw NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
        .padding()
    }
}