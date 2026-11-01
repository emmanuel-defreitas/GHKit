import GHKit
import SwiftUI

#if os(iOS) || os(visionOS)
    import UIKit
#elseif os(macOS)
    import AppKit
#endif

/// A ready-made device-flow sign-in screen.
///
///     if !session.isSignedIn { GitHubSignInView(session: session) }
public struct GitHubSignInView: View {
    let session: GitHubSession

    public init(session: GitHubSession) {
        self.session = session
    }

    public var body: some View {
        VStack(spacing: 16) {
            switch session.state {
            case .awaitingAuthorization(let authorization):
                DeviceCodeView(authorization: authorization, onCancel: session.cancelSignIn)
            case .restoring:
                ProgressView()
            case .signedOut, .signedIn:
                Button {
                    session.startDeviceFlowSignIn()
                } label: {
                    Label("Sign in with GitHub", systemImage: "person.crop.circle.badge.checkmark")
                }
                .buttonStyle(.borderedProminent)

                if let error = session.lastError {
                    Text(error.localizedDescription)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding()
    }
}

/// Shows a device-flow code, with buttons to copy it and open GitHub.
public struct DeviceCodeView: View {
    let authorization: DeviceAuthorization
    let onCancel: () -> Void
    @Environment(\.openURL) private var openURL

    public init(authorization: DeviceAuthorization, onCancel: @escaping () -> Void) {
        self.authorization = authorization
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(spacing: 16) {
            Text("Enter this code on GitHub")
                .font(.headline)

            code

            HStack {
                #if os(iOS) || os(visionOS) || os(macOS)
                    Button("Copy Code", systemImage: "doc.on.doc", action: copyCode)
                #endif
                Button("Open GitHub", systemImage: "safari") {
                    copyCode()
                    openURL(authorization.verificationURL)
                }
                .buttonStyle(.borderedProminent)
            }

            HStack(spacing: 8) {
                ProgressView()
                Text("Waiting for you to approve…")
                    .foregroundStyle(.secondary)
            }
            .font(.footnote)

            Text("Code expires \(authorization.expiresAt, style: .relative)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Cancel", role: .cancel, action: onCancel)
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var code: some View {
        let text = Text(authorization.userCode)
            .font(.system(.largeTitle, design: .monospaced, weight: .semibold))
            .accessibilityLabel("Code \(authorization.userCode.map(String.init).joined(separator: " "))")
        #if os(iOS) || os(visionOS) || os(macOS)
            text.textSelection(.enabled)
        #else
            text
        #endif
    }

    private func copyCode() {
        #if os(iOS) || os(visionOS)
            UIPasteboard.general.string = authorization.userCode
        #elseif os(macOS)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(authorization.userCode, forType: .string)
        #endif
    }
}
