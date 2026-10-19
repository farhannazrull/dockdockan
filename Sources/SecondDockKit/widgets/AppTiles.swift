import AppKit
import SwiftUI

/// Ikon app 40pt dari bundle ID + titik running + badge + bounce.
/// Hilang = dim + tooltip "not installed". Tanpa badge alias.
struct AppIcon: View {
    let bundleID: String
    var badge: Int?
    var running = true
    var dimmed = false
    var onOpen: () -> Void = {}

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bounce = false

    var body: some View {
        VStack(spacing: theme.s(5)) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let image = Self.icon(for: bundleID) {
                        Image(nsImage: image)
                            .resizable()
                            .frame(width: theme.s(52), height: theme.s(52))
                    } else if Self.isFigma(bundleID) {
                        FigmaGlyph(size: theme.s(52))
                    } else {
                        RoundedRectangle(cornerRadius: theme.s(12), style: .continuous)
                            .fill(Color.white.opacity(0.10))
                            .frame(width: theme.s(52), height: theme.s(52))
                    }
                }
                .opacity(Self.isFigma(bundleID) && Self.icon(for: bundleID) == nil
                         ? 1 : (dimmed || Self.url(for: bundleID) == nil ? 0.45 : 1))
                .scaleEffect(bounce ? 1.25 : 1)
                if let badge, badge > 0 {
                    Text("\(min(badge, 99))")
                        .font(theme.font(10, .bold))
                        .foregroundStyle(.white)
                        .frame(width: theme.s(16), height: theme.s(16))
                        .background(Theme.dangerRed)
                        .clipShape(Circle())
                        .offset(x: theme.s(5), y: theme.s(-5))
                }
            }
            Circle()
                .fill(running ? Color.white : Color.clear)
                .frame(width: theme.s(5), height: theme.s(5))
        }
        .help(Self.url(for: bundleID) == nil
            ? "\(Self.displayName(for: bundleID)) (not installed)"
            : Self.displayName(for: bundleID))
        .onTapGesture {
            if !reduceMotion {
                bounce = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { bounce = false }
            }
            onOpen()
        }
    }

    static func isFigma(_ bundleID: String) -> Bool { bundleID == "com.figma.Desktop" }

    static func url(for bundleID: String) -> URL? {
        if bundleID == "com.apple.finder" {
            let finder = URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")
            if FileManager.default.fileExists(atPath: finder.path) { return finder }
        }
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
    }

    static func icon(for bundleID: String) -> NSImage? {
        guard let url = url(for: bundleID) else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    static func displayName(for bundleID: String) -> String {
        if let url = url(for: bundleID) {
            let name = FileManager.default.displayName(atPath: url.path)
            if !name.isEmpty { return name.replacingOccurrences(of: ".app", with: "") }
        }
        return bundleID.split(separator: ".").last.map(String.init) ?? bundleID
    }

    static func launch(bundleID: String) {
        guard let url = url(for: bundleID) else { return }
        NSWorkspace.shared.open(url)
    }
}

/// Folder biru + huruf "P", buka path.
struct FolderTile: View {
    let letter: String
    let path: String
    var onOpen: () -> Void = {}

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: theme.s(5)) {
            ZStack {
                Image(systemName: "folder.fill")
                    .font(theme.font(44))
                    .foregroundStyle(.blue)
                    .frame(width: theme.s(52), height: theme.s(52))
                Text(letter)
                    .font(theme.font(15, .bold))
                    .foregroundStyle(.white)
                    .offset(y: theme.s(3))
            }
            Color.clear.frame(width: theme.s(5), height: theme.s(5))
        }
        .help(path)
        .onTapGesture(perform: onOpen)
    }
}

struct DividerTile: View {
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        theme.divider(scheme)
            .frame(width: theme.s(1), height: theme.s(28))
    }
}

struct HandleTile: View {
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Capsule(style: .continuous)
            .fill(theme.divider(scheme))
            .frame(width: theme.s(3), height: theme.s(24))
            .padding(.leading, theme.s(14))
    }
}

/// Area app paged: 2 per halaman + chevron + handle.
struct PagedAppsView: View {
    let apps: [String]
    @State private var page = 0
    private let pageSize = 2

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let pages = max(1, (apps.count + pageSize - 1) / pageSize)
        let current = min(page, pages - 1)
        let visible = Array(apps.dropFirst(current * pageSize).prefix(pageSize))
        HStack(spacing: theme.s(12)) {
            ForEach(visible, id: \.self) { bundleID in
                AppIcon(bundleID: bundleID)
            }
            Button {
                if current > 0 { page = current - 1 }
            } label: {
                Image(systemName: "chevron.left")
                    .font(theme.font(14, .semibold))
                    .foregroundStyle(theme.primaryGlyph(scheme).opacity(0.35))
                    .frame(width: theme.s(20), height: theme.cardHeight)
            }
            .buttonStyle(.plain)
            .help("Sebelumnya")
            .disabled(current == 0)
            Button {
                if current < pages - 1 { page = current + 1 }
            } label: {
                Image(systemName: "chevron.right")
                    .font(theme.font(14, .semibold))
                    .foregroundStyle(theme.primaryGlyph(scheme))
                    .frame(width: theme.s(20), height: theme.cardHeight)
            }
            .buttonStyle(.plain)
            .help("Berikutnya")
            .disabled(current >= pages - 1)
            HandleTile()
        }
    }
}
