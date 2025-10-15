import Foundation

@MainActor
final class ProjectManager: ObservableObject {
    @Published var current: ProjectV2? = nil
    @Published var dirty: Bool = false
    @Published var recent: [URL] = []
    @Published var currentURL: URL? = nil

    private var autosaveTimer: Timer?

    func newProject(title: String = "Untitled Project") {
        current = ProjectV2.newDefault(title: title)
        dirty = true
        scheduleAutosave()
    }

    func open(url: URL) {
        do {
            let p = try ProjectStore.loadV2(from: url)
            current = p
            currentURL = url
            addRecent(url)
            dirty = false
            scheduleAutosave()
        } catch {
            Logger.logAsync(.error, "Open failed", context: error.localizedDescription)
        }
    }

    func save(to url: URL) {
        guard let p = current else { return }
        do {
            try ProjectStore.saveV2(project: p, to: url)
            dirty = false
            addRecent(url)
            currentURL = url
        } catch {
            Logger.logAsync(.error, "Save failed", context: error.localizedDescription)
        }
    }

    func markDirty() {
        dirty = true
    }

    private func scheduleAutosave() {
        autosaveTimer?.invalidate()
        autosaveTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self, self.dirty, let p = self.current else { return }
            if let url = self.currentURL {
                try? ProjectStore.saveV2(project: p, to: url)
            } else {
                let tmp = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent("autosave.ltproj.json")
                try? ProjectStore.saveV2(project: p, to: tmp)
            }
        }
    }

    private func addRecent(_ url: URL) {
        recent.removeAll { $0 == url }
        recent.insert(url, at: 0)
        if recent.count > 20 { recent.removeLast(recent.count - 20) }
    }
}


