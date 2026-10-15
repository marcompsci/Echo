import SwiftUI
import AuthenticationServices

// MARK: - Connect an account (onboarding + Settings)

struct ConnectAccountsView: View {
    var showsDeveloperNote = true
    var onDone: (() -> Void)? = nil

    @State private var accounts = AccountService.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: EchoSpacing.md) {
            if let account = accounts.account {
                connectedCard(account)
            } else {
                SignInWithAppleButton(.continue) { request in
                    accounts.prepareAppleRequest(request)
                } onCompletion: { result in
                    Task { await accounts.handleAppleResult(result); if accounts.isSignedIn { onDone?() } }
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 50)
                .clipShape(RoundedRectangle(cornerRadius: EchoSpacing.Corner.lg))

                providerButton(.google, title: "Continue with Google (Gmail)")

                if showsDeveloperNote {
                    VStack(spacing: 4) {
                        providerButton(.github, title: "Developers: Continue with GitHub")
                        Text("Connect GitHub to test new builds and send developer feedback.")
                            .font(.echoCaption)
                            .foregroundStyle(.echoTextTertiary)
                            .multilineTextAlignment(.center)
                    }
                }
            }

            if accounts.isWorking { ProgressView() }
            if let error = accounts.errorMessage {
                Text(error)
                    .font(.echoCaption)
                    .foregroundStyle(.echoDestructive)
                    .multilineTextAlignment(.center)
                    .onTapGesture { accounts.errorMessage = nil }
            }
        }
    }

    private func providerButton(_ provider: AccountProvider, title: String) -> some View {
        Button {
            Task { await accounts.signIn(with: provider); if accounts.isSignedIn { onDone?() } }
        } label: {
            Label(title, systemImage: provider.systemImage)
                .font(.echoHeadline)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.echoSurface)
                .foregroundStyle(.echoTextPrimary)
                .clipShape(RoundedRectangle(cornerRadius: EchoSpacing.Corner.lg))
                .overlay(RoundedRectangle(cornerRadius: EchoSpacing.Corner.lg).strokeBorder(Color.echoSeparator))
        }
        .buttonStyle(.plain)
        .disabled(accounts.isWorking)
    }

    private func connectedCard(_ account: EchoAccount) -> some View {
        HStack {
            Image(systemName: account.provider.systemImage)
                .foregroundStyle(.echoLavender)
            VStack(alignment: .leading, spacing: 2) {
                Text("Connected with \(account.provider.title)")
                    .font(.echoHeadline)
                    .foregroundStyle(.echoTextPrimary)
                Text(account.githubUsername.map { "@\($0)" } ?? account.email ?? account.displayName ?? "")
                    .font(.echoCaption)
                    .foregroundStyle(.echoTextSecondary)
            }
            Spacer()
            Button("Disconnect", role: .destructive) { accounts.signOut() }
                .font(.echoFootnote)
        }
        .padding(EchoSpacing.md)
        .background(Color.echoSurface)
        .clipShape(RoundedRectangle(cornerRadius: EchoSpacing.Corner.lg))
    }
}
