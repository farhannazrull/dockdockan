import SwiftUI

/// Kartu note: padat #F2D369, teks #2A2200 13pt semibold, dua baris terlihat.
/// Klik = edit inline; Escape / klik luar / Cmd+Return = simpan lalu keluar.
struct NoteWidget: View {
    @ObservedObject var note: NoteViewModel

    @Environment(\.theme) private var theme
    @FocusState private var editorFocused: Bool
    @State private var editorFrame: CGRect = .zero
    @State private var outsideMonitor: Any?

    var body: some View {
        ZStack(alignment: .top) {
            display
            if note.isEditing {
                editor
                    .frame(maxWidth: theme.s(280))
                    .fixedSize(horizontal: false, vertical: true)
                    .background(Theme.noteYellow)
                    .clipShape(RoundedRectangle(cornerRadius: theme.s(14), style: .continuous))
                    .offset(y: -theme.s(84))
                    .background(GeometryReader { geo in
                        Color.clear.preference(key: EditorFrameKey.self, value: geo.frame(in: .global))
                    })
                    .zIndex(1)
            }
        }
    }

    // MARK: - Tampilan

    private var display: some View {
        Group {
            if note.isEmpty && !note.isEditing {
                Text("Click to add a note")
                    .font(theme.font(13, .semibold))
                    .foregroundStyle(Theme.noteText.opacity(0.55))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(note.text)
                    .font(theme.font(13, .semibold))
                    .foregroundStyle(Theme.noteText)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, theme.s(12))
        .padding(.vertical, theme.cardPadding)
        .frame(height: theme.cardHeight)
        .frame(minWidth: theme.s(140))
        .background(Theme.noteYellow)
        .clipShape(RoundedRectangle(cornerRadius: theme.s(14), style: .continuous))
        .help(note.isEmpty ? "" : note.text)
        .onPreferenceChange(EditorFrameKey.self) { editorFrame = $0 }
        .contentShape(RoundedRectangle(cornerRadius: theme.s(14), style: .continuous))
        .onTapGesture {
            guard !note.isEditing else { return }
            note.beginEditing()
            editorFocused = true
        }
        .onChange(of: note.isEditing) { _, editing in
            if editing { startOutsideMonitor() } else { stopOutsideMonitor() }
        }
        .onDisappear { stopOutsideMonitor() }
    }

    /// Klik di luar editor = simpan lalu keluar.
    private func startOutsideMonitor() {
        stopOutsideMonitor()
        // NoteWidget adalah struct, jadi tidak bisa [weak self];
        // note (ObservedObject) dan frame-nya diambil lewat closure state.
        let note = note
        let current = { self.editorFrame }
        outsideMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { event in
            MainActor.assumeIsolated {
                if !current().contains(event.locationInWindow) { note.endEditing() }
            }
            return event
        }
    }

    private func stopOutsideMonitor() {
        if let outsideMonitor { NSEvent.removeMonitor(outsideMonitor) }
        outsideMonitor = nil
    }

    private var editor: some View {
        TextField("", text: Binding(
            get: { note.text },
            set: { note.update($0) }
        ), axis: .vertical)
        .textFieldStyle(.plain)
        .font(theme.font(13, .semibold))
        .foregroundStyle(Theme.noteText)
        .lineLimit(2 ... 8)
        .padding(.horizontal, theme.s(12))
        .padding(.vertical, theme.cardPadding)
        .frame(width: theme.s(280), alignment: .leading)
        .focused($editorFocused)
        .onKeyPress(.escape) {
            note.endEditing()
            return .handled
        }
        .onKeyPress(phases: .down) { press in
            if press.key == .return, press.modifiers.contains(.command) {
                note.endEditing()
                return .handled
            }
            return .ignored
        }
    }
}

struct NoteWidget_Previews: PreviewProvider {
    static var previews: some View {
        NoteWidget(note: NoteViewModel.preview)
            .environment(\.theme, Theme(scale: 1))
            .padding()
            .background(Color.black)
    }
}

private struct EditorFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}
