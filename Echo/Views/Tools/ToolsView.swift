import SwiftUI

// MARK: - Tools tab: everything Echo can do, in one calm place

struct ToolsView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        NavigationStack {
            ZStack {
                EchoAmbientBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: EchoSpacing.xl) {
                        group("Get help", [
                            ToolItem(icon: "dot.radiowaves.left.and.right", title: "Live Guide", detail: "Echo watches your screen and tells you each tap", tint: .echoMint) {
                                router.navigateToLiveGuide()
                            },
                            ToolItem(icon: "camera.viewfinder", title: "Latest screenshot", detail: "Explain it, or fix the error on it", tint: .echoLavender) {
                                EchoLaunchCenter.shared.request(.lastScreenshot)
                            }
                        ])
                        group("Get things done", [
                            ToolItem(icon: "wand.and.stars", title: "Echo Agent", detail: "Reminders, events, texts, calls, directions", tint: .echoLavender) {
                                router.navigateToAgent()
                            },
                            ToolItem(icon: "photo.stack", title: "Photo Cleanup", detail: "Screenshots, big videos, duplicates", tint: .echoMint) {
                                router.selectedTab = .home
                                router.path.append(EchoRoute.photoCleanup)
                            },
                            ToolItem(icon: "folder.badge.gearshape", title: "File Cleanup", detail: "Sort by type, find duplicates", tint: .echoMint) {
                                router.selectedTab = .home
                                router.path.append(EchoRoute.fileCleanup)
                            }
                        ])
                        VStack(alignment: .leading, spacing: EchoSpacing.sm) {
                            EchoSectionHeader(title: "Make Echo yours")
                            VStack(spacing: 0) {
                                link("Echo Skills", "sparkles.rectangle.stack", "Your own voice commands") { SkillsView() }
                                Divider().padding(.leading, 56)
                                link("What Echo Remembers", "brain.head.profile", "Edit or forget anytime") { MemoryView() }
                                Divider().padding(.leading, 56)
                                link("Connect AI", "link.circle", "Claude, ChatGPT, Grok, Muse") { ConnectAIView() }
                                Divider().padding(.leading, 56)
                                link("Summon Hey Echo", "waveform.circle", "Action Button, Back Tap, Siri") { HeyEchoSetupView() }
                            }
                            .echoGlass(cornerRadius: EchoSpacing.Corner.xl)
                        }
                    }
                    .padding(.horizontal, EchoSpacing.gutter)
                    .padding(.bottom, EchoSpacing.xxxl)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Tools")
        }
    }

    private func group(_ title: String, _ items: [ToolItem]) -> some View {
        VStack(alignment: .leading, spacing: EchoSpacing.sm) {
            EchoSectionHeader(title: title)
            ForEach(items) { item in
                Button(action: item.action) {
                    HStack(spacing: EchoSpacing.md) {
                        ZStack {
                            Circle().fill(item.tint.opacity(0.16)).frame(width: 44, height: 44)
                            Image(systemName: item.icon).font(.echoHeadline).foregroundStyle(item.tint)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title).font(.echoHeadline).foregroundStyle(.echoTextPrimary)
                            Text(item.detail).font(.echoCaption).foregroundStyle(.echoTextSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.echoFootnote.weight(.semibold)).foregroundStyle(.echoTextTertiary)
                    }
                    .padding(EchoSpacing.md)
                    .echoGlass(cornerRadius: EchoSpacing.Corner.xl)
                    .accessibilityElement(children: .combine)
                }
                .buttonStyle(.echoPress)
            }
        }
    }

    private func link<D: View>(_ title: String, _ icon: String, _ detail: String, @ViewBuilder destination: () -> D) -> some View {
        NavigationLink(destination: destination()) {
            HStack(spacing: EchoSpacing.md) {
                Image(systemName: icon).font(.echoHeadline).foregroundStyle(.echoLavender).frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.echoSubheadline.weight(.semibold)).foregroundStyle(.echoTextPrimary)
                    Text(detail).font(.echoCaption).foregroundStyle(.echoTextSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.echoFootnote.weight(.semibold)).foregroundStyle(.echoTextTertiary)
            }
            .padding(EchoSpacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct ToolItem: Identifiable {
    var id: String { title }
    let icon: String
    let title: String
    let detail: String
    let tint: Color
    let action: () -> Void
}

// MARK: - Hey Echo bar that rides above the tab bar

struct HeyEchoAccessory: View {
    let action: () -> Void
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    var body: some View {
        Button(action: action) {
            HStack(spacing: EchoSpacing.sm) {
                EchoOrbView(size: placement == .inline ? 22 : 28)
                Text(placement == .inline ? "Hey Echo" : "Hey Echo — tap to talk")
                    .font(.echoSubheadline.weight(.semibold))
                    .foregroundStyle(.echoTextPrimary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "mic.fill").foregroundStyle(.echoLavender)
            }
            .padding(.horizontal, EchoSpacing.gutter)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Hey Echo, tap to talk")
    }
}
