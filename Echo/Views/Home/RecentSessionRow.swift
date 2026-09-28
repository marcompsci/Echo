import SwiftUI

struct RecentSessionRow: View {
    let session: EchoSession

    var body: some View {
        HStack(spacing: EchoSpacing.md) {
            // Thumbnail or placeholder
            Group {
                if let data = session.imageData, let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        Color.echoSurfaceElevated
                        Image(systemName: "photo")
                            .foregroundStyle(.echoTextTertiary)
                    }
                }
            }
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: EchoSpacing.Corner.md))
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(session.questionPreview)
                    .font(.echoSubheadline)
                    .foregroundStyle(.echoTextPrimary)
                    .lineLimit(2)

                Text(session.formattedDate)
                    .font(.echoCaption)
                    .foregroundStyle(.echoTextTertiary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.echoCaption.weight(.semibold))
                .foregroundStyle(.echoTextTertiary)
                .accessibilityHidden(true)
        }
        .padding(EchoSpacing.md)
        .background(Color.echoSurface)
        .clipShape(RoundedRectangle(cornerRadius: EchoSpacing.Corner.xl))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(session.questionPreview), \(session.formattedDate)")
    }
}
