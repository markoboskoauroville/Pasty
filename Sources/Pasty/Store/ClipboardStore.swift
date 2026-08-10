import AppKit
import Observation

@Observable
@MainActor
final class ClipboardStore {
    static let shared = ClipboardStore()

    /// The single board. Array order IS display order: pinned items occupy the
    /// head in a manual order the user controls, everything else follows in
    /// recency order. There is no second list and no pinboard concept.
    private(set) var items: [ClipItem] = []

    var searchText: String = ""
    var selectedID: UUID?

    var historyLimit: Int {
        get { Settings.shared.historyLimit }
        set { Settings.shared.historyLimit = newValue; trimHistory() }
    }

    private var storeURL: URL
    private var imagesDir: URL
    private var baseDir: URL
    private var saveWorkItem: DispatchWorkItem?

    private var fileWatch: DispatchSourceFileSystemObject?
    private var ignoreWatchUntil: Date = .distantPast

    static var localBase: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Pasty", isDirectory: true)
    }

    /// Data written by the app under its former name.
    static var legacyLocalBase: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Pesty", isDirectory: true)
    }

    static var isSandboxed: Bool {
        ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
    }

    static var iCloudBase: URL? {
        guard !isSandboxed else { return nil }
        let p = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
        guard FileManager.default.fileExists(atPath: p.path) else { return nil }
        return p.appendingPathComponent("Pasty", isDirectory: true)
    }

    var iCloudAvailable: Bool { ClipboardStore.iCloudBase != nil }

    private init() {
        ClipboardStore.adoptLegacyDirectoryIfNeeded()
        let base = (Settings.shared.iCloudSync ? ClipboardStore.iCloudBase : nil) ?? ClipboardStore.localBase
        baseDir = base
        imagesDir = base.appendingPathComponent("images", isDirectory: true)
        storeURL = base.appendingPathComponent("store.json")
        prepareDirectories()
        load()
        if Settings.shared.iCloudSync { startWatching() }
    }

    /// One-time move of the old Application Support folder to the new name, so a
    /// user upgrading from the pre-rename build keeps their clips.
    private static func adoptLegacyDirectoryIfNeeded() {
        let fm = FileManager.default
        guard !fm.fileExists(atPath: localBase.path),
              fm.fileExists(atPath: legacyLocalBase.path) else { return }
        try? fm.copyItem(at: legacyLocalBase, to: localBase)
    }

    private func prepareDirectories() {
        let fm = FileManager.default
        try? fm.createDirectory(at: imagesDir, withIntermediateDirectories: true,
                                attributes: [.posixPermissions: 0o700])
        try? fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: baseDir.path)
    }

    // MARK: - Derived views

    var visibleItems: [ClipItem] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return items }
        return items.filter { $0.searchableText.contains(q) }
    }

    var pinnedCount: Int { items.prefix { $0.pinned }.count }

    var selectedItem: ClipItem? {
        guard let id = selectedID else { return nil }
        return visibleItems.first(where: { $0.id == id })
    }

    /// Pinned first in their manual order, then everything else newest first.
    private func normalize() {
        let pins = items.filter { $0.pinned }
        let rest = items.filter { !$0.pinned }.sorted { $0.createdAt > $1.createdAt }
        items = pins + rest
    }

    // MARK: - Capture

    func addCaptured(_ item: ClipItem) {
        if let idx = items.firstIndex(where: { $0.sameContent(as: item) }) {
            if item.imageFileName != items[idx].imageFileName { deleteImageFile(item) }
            let wasPinned = items[idx].pinned
            if wasPinned {
                // A pinned card keeps its slot. Only its timestamp refreshes.
                items[idx].createdAt = item.createdAt
                if searchText.isEmpty { selectedID = items[idx].id }
                scheduleSave()
                return
            }
            var existing = items.remove(at: idx)
            existing.createdAt = item.createdAt
            items.insert(existing, at: pinnedCount)
            if searchText.isEmpty { selectedID = existing.id }
            scheduleSave()
            return
        }
        items.insert(item, at: pinnedCount)
        trimHistory()
        if searchText.isEmpty { selectedID = item.id }
        scheduleSave()
    }

    func applyHistoryLimit() { trimHistory(); scheduleSave() }

    /// The limit applies to unpinned cards only. A pin is a promise that the
    /// card stays until the user says otherwise.
    private func trimHistory() {
        let unpinned = items.filter { !$0.pinned }
        guard unpinned.count > historyLimit else { return }
        let doomed = Set(unpinned.suffix(unpinned.count - historyLimit).map(\.id))
        let removed = items.filter { doomed.contains($0.id) }
        items.removeAll { doomed.contains($0.id) }
        for item in removed { deleteImageFile(item) }
    }

    // MARK: - Pinning

    func togglePin(_ item: ClipItem) {
        guard let i = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[i].pinned.toggle()
        normalize()
        selectedID = item.id
        trimHistory()
        scheduleSave()
    }

    func setPinned(_ pinned: Bool, for item: ClipItem) {
        guard let i = items.firstIndex(where: { $0.id == item.id }), items[i].pinned != pinned else { return }
        togglePin(item)
    }

    /// Move a pinned card one slot left or right inside the pinned block.
    /// Click driven, so no drag and drop is needed anywhere.
    func movePinned(_ item: ClipItem, by delta: Int) {
        guard delta != 0,
              let from = items.firstIndex(where: { $0.id == item.id }),
              items[from].pinned else { return }
        let to = from + delta
        guard to >= 0, to < pinnedCount else { return }
        let moved = items.remove(at: from)
        items.insert(moved, at: to)
        selectedID = moved.id
        scheduleSave()
    }

    func canMovePinned(_ item: ClipItem, by delta: Int) -> Bool {
        guard item.pinned, let from = items.firstIndex(where: { $0.id == item.id }) else { return false }
        let to = from + delta
        return to >= 0 && to < pinnedCount
    }

    // MARK: - Mutation

    func delete(_ item: ClipItem) {
        items.removeAll { $0.id == item.id }
        deleteImageFile(item)
        if selectedID == item.id { selectFirst() }
        scheduleSave()
    }

    /// Clears unpinned cards. Pinned cards survive, which is the point of a pin.
    func clearHistory() {
        let removed = items.filter { !$0.pinned }
        items.removeAll { !$0.pinned }
        selectFirst()
        for item in removed { deleteImageFile(item) }
        scheduleSave()
    }

    func removeAllIncludingPinned() {
        let old = items
        items.removeAll()
        selectedID = nil
        for item in old { deleteImageFile(item) }
        scheduleSave()
    }

    func setTitle(_ title: String, for item: ClipItem) {
        guard let i = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[i].customTitle = title
        scheduleSave()
    }

    func selectFirst() { selectedID = visibleItems.first?.id }

    func moveSelection(by delta: Int) {
        let list = visibleItems
        guard !list.isEmpty else { return }
        guard let id = selectedID, let idx = list.firstIndex(where: { $0.id == id }) else {
            selectedID = list.first?.id; return
        }
        let next = max(0, min(list.count - 1, idx + delta))
        selectedID = list[next].id
    }

    // MARK: - Images

    func imageURL(for item: ClipItem) -> URL? {
        guard let name = item.imageFileName else { return nil }
        return imagesDir.appendingPathComponent(name)
    }

    func loadImage(for item: ClipItem) -> NSImage? {
        guard let url = imageURL(for: item) else { return nil }
        return NSImage(contentsOf: url)
    }

    func storeImageData(_ data: Data) -> String? {
        let name = "\(UUID().uuidString).png"
        let url = imagesDir.appendingPathComponent(name)
        do {
            try data.write(to: url)
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
            return name
        } catch { return nil }
    }

    private func deleteImageFile(_ item: ClipItem) {
        guard let name = item.imageFileName else { return }
        if items.contains(where: { $0.imageFileName == name }) { return }
        if let url = imageURL(for: item) { try? FileManager.default.removeItem(at: url) }
    }

    // MARK: - Persistence

    /// Reads both the current single-list shape and the older shape that had a
    /// separate `pinboards` array. Old pinboard cards come back as pinned cards
    /// on the one board, boards in order, so nothing the user saved is lost.
    private struct Snapshot: Codable {
        var items: [ClipItem]

        init(items: [ClipItem]) { self.items = items }

        private enum CodingKeys: String, CodingKey { case items, history, pinboards }
        private struct LegacyBoard: Codable { var items: [ClipItem]? }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            if let current = try c.decodeIfPresent([ClipItem].self, forKey: .items) {
                items = current
                return
            }
            var merged: [ClipItem] = []
            let boards = try c.decodeIfPresent([LegacyBoard].self, forKey: .pinboards) ?? []
            for board in boards {
                for var saved in board.items ?? [] {
                    guard !merged.contains(where: { $0.sameContent(as: saved) }) else { continue }
                    saved.pinned = true
                    merged.append(saved)
                }
            }
            let history = try c.decodeIfPresent([ClipItem].self, forKey: .history) ?? []
            for entry in history where !merged.contains(where: { $0.sameContent(as: entry) }) {
                merged.append(entry)
            }
            items = merged
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(items, forKey: .items)
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: storeURL),
              let snap = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        items = snap.items
        normalize()
        selectFirst()
    }

    private func scheduleSave() {
        saveWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.saveNow() }
        saveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    func saveNow() {
        let snap = Snapshot(items: items)
        guard let data = try? JSONEncoder().encode(snap) else { return }
        ignoreWatchUntil = Date().addingTimeInterval(1.5)
        try? data.write(to: storeURL, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: storeURL.path)
    }

    // MARK: - iCloud

    func setICloudSync(_ enabled: Bool) {
        stopWatching()
        let target = (enabled ? ClipboardStore.iCloudBase : ClipboardStore.localBase) ?? ClipboardStore.localBase
        let newImages = target.appendingPathComponent("images", isDirectory: true)
        let newStore = target.appendingPathComponent("store.json")
        let fm = FileManager.default
        try? fm.createDirectory(at: newImages, withIntermediateDirectories: true,
                                attributes: [.posixPermissions: 0o700])

        if fm.fileExists(atPath: newStore.path),
           let data = try? Data(contentsOf: newStore),
           let snap = try? JSONDecoder().decode(Snapshot.self, from: data) {
            copyImages(from: imagesDir, to: newImages)
            baseDir = target; imagesDir = newImages; storeURL = newStore
            mergeExternal(snap)
        } else {
            copyImages(from: imagesDir, to: newImages)
            baseDir = target; imagesDir = newImages; storeURL = newStore
            saveNow()
        }
        prepareDirectories()
        if enabled { startWatching() }
    }

    private func copyImages(from src: URL, to dst: URL) {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: src, includingPropertiesForKeys: nil) else { return }
        for f in files where f.pathExtension == "png" {
            let target = dst.appendingPathComponent(f.lastPathComponent)
            if !fm.fileExists(atPath: target.path) { try? fm.copyItem(at: f, to: target) }
        }
    }

    private func contentKey(_ item: ClipItem) -> String {
        switch item.type {
        case .image: return "img:" + (item.imageHash ?? item.imageFileName ?? item.id.uuidString)
        case .color: return "col:" + (item.colorHex ?? "")
        case .file:  return "file:" + item.fileURLs.joined(separator: "|")
        default:     return "txt:" + (item.text ?? "")
        }
    }

    /// Union of both machines. Pinned wins over unpinned, and the local manual
    /// pin order is kept, with any pins only the other Mac knows about appended.
    private func mergeExternal(_ snap: Snapshot) {
        let before = items.count

        var pinnedKeys = Set(items.filter(\.pinned).map(contentKey))
        let remotePinned = Set(snap.items.filter(\.pinned).map(contentKey))

        var localPins = items.filter(\.pinned)
        for remote in snap.items where remote.pinned && !pinnedKeys.contains(contentKey(remote)) {
            pinnedKeys.insert(contentKey(remote))
            var copy = remote
            copy.pinned = true
            localPins.append(copy)
        }

        let combined = (items + snap.items)
            .filter { !pinnedKeys.contains(contentKey($0)) }
            .sorted { $0.createdAt > $1.createdAt }
        var seen = Set<String>()
        var rest: [ClipItem] = []
        for it in combined where seen.insert(contentKey(it)).inserted {
            var copy = it
            copy.pinned = false
            rest.append(copy)
        }

        _ = remotePinned
        items = localPins + Array(rest.prefix(historyLimit))
        selectFirst()
        if items.count != before || !snap.items.isEmpty { saveNow() }
    }

    private func startWatching() {
        stopWatching()
        let fd = open(storeURL.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd, eventMask: [.write, .rename, .delete], queue: .main)
        src.setEventHandler { [weak self] in
            guard let self else { return }
            if Date() < self.ignoreWatchUntil { return }
            if let data = try? Data(contentsOf: self.storeURL),
               let snap = try? JSONDecoder().decode(Snapshot.self, from: data) {
                self.mergeExternal(snap)
            }
            self.startWatching()
        }
        src.setCancelHandler { close(fd) }
        src.resume()
        fileWatch = src
    }

    private func stopWatching() {
        fileWatch?.cancel()
        fileWatch = nil
    }
}
