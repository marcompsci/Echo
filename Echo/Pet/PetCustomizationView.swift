import SwiftUI

// MARK: - Pet customization sheet

struct PetCustomizationView: View {
    @Bindable var pet: PetState
    @Environment(\.dismiss) private var dismiss

    @State private var isBlinking = false
    @State private var bobbing = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.echoBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: EchoSpacing.lg) {
                        previewSection
                        nameSection
                        statsSection
                        colorSection
                        accessorySection
                    }
                    .padding(.horizontal, EchoSpacing.md)
                    .padding(.top, EchoSpacing.lg)
                    .padding(.bottom, EchoSpacing.xxxl)
                }
            }
            .navigationTitle("Your Pet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.echoBackground, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.echoLavender)
                }
            }
            .onAppear { bobbing = true }
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(Double.random(in: 2.5...5.5)))
                    withAnimation(.easeInOut(duration: 0.07)) { isBlinking = true }
                    try? await Task.sleep(for: .milliseconds(130))
                    withAnimation(.easeInOut(duration: 0.07)) { isBlinking = false }
                }
            }
        }
    }

    // MARK: - Live preview

    private var previewSection: some View {
        VStack(spacing: EchoSpacing.sm) {
            PetCharacterView(
                mood:        pet.mood,
                bodyColor:   pet.bodyColor,
                accessory:   pet.accessory,
                isBlinking:  isBlinking,
                pupilOffset: .zero,
                isExcited:   false,
                size:        120
            )
            .offset(y: bobbing ? -6 : 0)
            .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: bobbing)
            .accessibilityHidden(true)

            Text(pet.name)
                .font(.echoTitle3)
                .foregroundStyle(.echoTextPrimary)
            Text("Mood: \(pet.mood.label)")
                .font(.echoCaption)
                .foregroundStyle(.echoTextSecondary)
        }
    }

    // MARK: - Name

    private var nameSection: some View {
        EchoCard {
            VStack(alignment: .leading, spacing: EchoSpacing.xs) {
                Text("Name")
                    .font(.echoHeadline)
                    .foregroundStyle(.echoTextPrimary)
                TextField("Enter a name", text: $pet.name)
                    .font(.echoBody)
                    .foregroundStyle(.echoTextPrimary)
                    .textFieldStyle(.plain)
                    .padding(EchoSpacing.sm)
                    .background(Color.echoBackground)
                    .clipShape(RoundedRectangle(cornerRadius: EchoSpacing.Corner.md))
            }
            .padding(EchoSpacing.md)
        }
    }

    // MARK: - Stats + interactions

    private var statsSection: some View {
        EchoCard {
            VStack(alignment: .leading, spacing: EchoSpacing.md) {
                Text("Status")
                    .font(.echoHeadline)
                    .foregroundStyle(.echoTextPrimary)

                statBar(label: "Happiness", value: pet.happiness / 100, color: .echoMint)
                statBar(label: "Energy",    value: pet.energy    / 100, color: .echoLavender)

                HStack(spacing: EchoSpacing.sm) {
                    Button { pet.pet() } label: {
                        Label("Pet", systemImage: "hand.raised.fill")
                            .font(.echoFootnote.weight(.medium))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.echoLavender)

                    Button { pet.feed() } label: {
                        Label("Feed", systemImage: "fork.knife")
                            .font(.echoFootnote.weight(.medium))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.echoMint)
                }
            }
            .padding(EchoSpacing.md)
        }
    }

    private func statBar(label: String, value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.echoCaption)
                    .foregroundStyle(.echoTextSecondary)
                Spacer()
                Text("\(Int(value * 100))%")
                    .font(.echoCaption2)
                    .foregroundStyle(.echoTextTertiary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.15))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geo.size.width * max(0, min(1, value)))
                        .animation(.spring(duration: 0.4), value: value)
                }
            }
            .frame(height: 6)
        }
    }

    // MARK: - Color picker

    private var colorSection: some View {
        EchoCard {
            VStack(alignment: .leading, spacing: EchoSpacing.md) {
                Text("Color")
                    .font(.echoHeadline)
                    .foregroundStyle(.echoTextPrimary)

                HStack(spacing: EchoSpacing.sm) {
                    ForEach(PetBodyColor.allCases, id: \.rawValue) { c in
                        Button {
                            withAnimation(.spring(duration: 0.25)) { pet.bodyColor = c }
                        } label: {
                            Circle()
                                .fill(c.color)
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Circle().strokeBorder(
                                        pet.bodyColor == c ? Color.white : Color.clear,
                                        lineWidth: 3
                                    )
                                )
                                .shadow(
                                    color: c.shadowColor,
                                    radius: pet.bodyColor == c ? 6 : 0
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(c.label)
                        .accessibilityAddTraits(pet.bodyColor == c ? .isSelected : [])
                    }
                }
            }
            .padding(EchoSpacing.md)
        }
    }

    // MARK: - Accessory picker

    private var accessorySection: some View {
        EchoCard {
            VStack(alignment: .leading, spacing: EchoSpacing.md) {
                Text("Accessory")
                    .font(.echoHeadline)
                    .foregroundStyle(.echoTextPrimary)

                HStack(spacing: EchoSpacing.xs) {
                    ForEach(PetAccessory.allCases, id: \.rawValue) { acc in
                        Button {
                            withAnimation(.spring(duration: 0.25)) { pet.accessory = acc }
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: acc.systemIcon)
                                    .font(.echoTitle3)
                                    .foregroundStyle(pet.accessory == acc ? .echoLavender : .echoTextSecondary)
                                    .frame(height: 28)
                                Text(acc.label)
                                    .font(.echoCaption2)
                                    .foregroundStyle(pet.accessory == acc ? .echoTextPrimary : .echoTextTertiary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, EchoSpacing.sm)
                            .background(
                                pet.accessory == acc
                                    ? Color.echoLavender.opacity(0.12)
                                    : Color.echoBackground
                            )
                            .clipShape(RoundedRectangle(cornerRadius: EchoSpacing.Corner.md))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(acc.label)
                        .accessibilityAddTraits(pet.accessory == acc ? .isSelected : [])
                    }
                }
            }
            .padding(EchoSpacing.md)
        }
    }
}

#Preview {
    PetCustomizationView(pet: PetState())
}
