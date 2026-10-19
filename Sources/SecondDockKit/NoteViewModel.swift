import AppKit
import Combine
import Foundation

/// Note widget: teks nyata yang bisa diedit dan tersimpan di note.txt.
@MainActor
public final class NoteViewModel: ObservableObject {
    @Published public private(set) var text: String
    @Published public private(set) var isEditing = false

    /// Dipanggil controller agar panel jadi menerima keyboard saat mengedit.
    public var onEditingChange: ((Bool) -> Void)?

    private var saveTask: Task<Void, Never>?
    private static let debounce: Duration = .milliseconds(300)

    public static var fileURL: URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                                 in: .userDomainMask).first else { return nil }
        let dir = base.appendingPathComponent("SecondDock", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("note.txt")
    }

    public init() {
        if let url = Self.fileURL,
           let data = try? String(contentsOf: url, encoding: .utf8) {
            text = data
        } else {
            text = ""
        }
    }

    deinit {
        saveTask?.cancel()
    }

    public var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public func update(_ value: String) {
        text = value
        scheduleSave()
    }

    public func beginEditing() {
        guard !isEditing else { return }
        isEditing = true
        onEditingChange?(true)
    }

    public func endEditing() {
        guard isEditing else { return }
        isEditing = false
        saveTask?.cancel()
        save()
        onEditingChange?(false)
    }

    private func scheduleSave() {
        saveTask?.cancel()
        let snapshot = text
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: Self.debounce)
            guard !Task.isCancelled else { return }
            Self.write(snapshot)
            _ = self
        }
    }

    public func save() {
        saveTask?.cancel()
        Self.write(text)
    }

    private static func write(_ value: String) {
        guard let url = fileURL else { return }
        try? value.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Pratinjau/render offscreen: teks contoh, tanpa menyentuh disk.
    public static let preview: NoteViewModel = {
        let vm = NoteViewModel()
        vm.text = "Ship it.\nTake a walk."
        return vm
    }()
}