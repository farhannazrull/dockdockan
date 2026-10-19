import SwiftUI

struct NoteWidget: View {
    let line1: String
    let line2: String

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(line1)
                .font(theme.font(13, .semibold))
                .foregroundStyle(Theme.noteText)
                .lineLimit(1)
                .truncationMode(.tail)
            Text(line2)
                .font(theme.font(13, .semibold))
                .foregroundStyle(Theme.noteText)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, theme.s(12))
        .padding(.vertical, theme.cardPadding)
        .frame(height: theme.cardHeight)
        .background(Theme.noteYellow)
        .clipShape(RoundedRectangle(cornerRadius: theme.s(14), style: .continuous))
        // Lebar tetap agar "Take a walk." tidak pernah terpotong.
        .frame(minWidth: theme.s(140))
    }
}

struct NoteWidget_Previews: PreviewProvider {
    static var previews: some View {
        NoteWidget(line1: "Ship it.", line2: "Take a walk.")
            .environment(\.theme, Theme(scale: 1))
            .padding()
            .background(Color.black)
    }
}
