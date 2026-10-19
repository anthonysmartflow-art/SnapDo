import Foundation
import ImageIO
import Darwin

// Identical in both targets so the app and widget use the same storage rules.
nonisolated struct SnapStore {
    let directory: URL

    init(directory: URL? = nil) throws {
        if let directory {
            self.directory = directory
        } else {
            guard let container = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: "HV3L34Y872.com.ajrosenberger.SnapDo"
            ) else { throw Self.failure("Shared storage is unavailable.") }
            self.directory = container.appendingPathComponent("Screenshots", isDirectory: true)
        }
        try FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
    }

    func list() throws -> [String] {
        let manifest = directory.appendingPathComponent("screenshot-files.json")
        guard FileManager.default.fileExists(atPath: manifest.path) else { return [] }
        let names = try JSONDecoder().decode([String].self, from: Data(contentsOf: manifest))
        guard names.count <= 3, Set(names).count == names.count,
              names.allSatisfy(Self.validName) else {
            throw Self.failure("The saved task list could not be read safely.")
        }
        return names
    }

    func imageURL(_ name: String) throws -> URL {
        guard Self.validName(name) else { throw Self.failure("Invalid screenshot name.") }
        return directory.appendingPathComponent(name)
    }

    func add(_ urls: [URL]) throws {
        guard !urls.isEmpty else { return }
        try locked {
            let current = try list()
            let available = 3 - current.count
            guard urls.count <= available else {
                throw Self.failure(available == 0
                    ? "All three slots are full. Mark a task Done before adding another."
                    : "There are only \(available) empty slots. Select fewer screenshots.")
            }
            var added: [String] = []
            do {
                for url in urls {
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    let data = try Data(contentsOf: url)
                    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                          CGImageSourceGetCount(source) > 0 else {
                        throw Self.failure("One selected file is not a readable image.")
                    }
                    let name = UUID().uuidString + "." + url.pathExtension.lowercased()
                    try data.write(to: imageURL(name), options: .atomic)
                    added.append(name)
                }
                try save(current + added)
            } catch {
                for name in added { try? FileManager.default.removeItem(at: imageURL(name)) }
                throw error
            }
        }
    }

    func complete(_ name: String) throws {
        try locked {
            let current = try list()
            guard current.contains(name) else { return }
            try save(current.filter { $0 != name })
            // Keep the image copy for Undo and any widget timeline still displaying it.
            try? Data(name.utf8).write(to: directory.appendingPathComponent("last-completed.txt"), options: .atomic)
        }
    }

    func undo() throws {
        try locked {
            let marker = directory.appendingPathComponent("last-completed.txt")
            guard FileManager.default.fileExists(atPath: marker.path) else { return }
            let name = try String(contentsOf: marker, encoding: .utf8)
            var current = try list()
            guard !current.contains(name) else { return }
            guard current.count < 3 else { throw Self.failure("Make room before restoring the last task.") }
            guard FileManager.default.fileExists(atPath: try imageURL(name).path) else {
                throw Self.failure("The completed screenshot is no longer available.")
            }
            current.append(name)
            try save(current)
            try? FileManager.default.removeItem(at: marker)
        }
    }

    var canUndo: Bool {
        guard let name = try? String(contentsOf: directory.appendingPathComponent("last-completed.txt"), encoding: .utf8),
              let current = try? list() else { return false }
        return !current.contains(name) && current.count < 3
    }

    private func save(_ names: [String]) throws {
        try JSONEncoder().encode(names).write(
            to: directory.appendingPathComponent("screenshot-files.json"), options: .atomic)
    }

    private func locked<T>(_ operation: () throws -> T) throws -> T {
        let fd = open(directory.appendingPathComponent("tasks.lock").path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard fd >= 0 else { throw Self.failure("Couldn't open the task list lock.") }
        defer { close(fd) }
        guard flock(fd, LOCK_EX) == 0 else { throw Self.failure("Couldn't lock the task list.") }
        defer { flock(fd, LOCK_UN) }
        return try operation()
    }

    private static func validName(_ name: String) -> Bool {
        !name.isEmpty && !name.contains("/") && !name.contains("\\") && name != "." && name != ".."
    }

    private static func failure(_ text: String) -> NSError {
        NSError(domain: "SnapDo", code: 1, userInfo: [NSLocalizedDescriptionKey: text])
    }
}
