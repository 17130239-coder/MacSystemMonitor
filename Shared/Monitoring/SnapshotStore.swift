import Foundation

/// Hands the latest metrics from the app (unsandboxed, can read sensors) to the
/// widget extension (sandboxed, cannot) through an App Group container file.
enum SnapshotStore {
    static let fileName = "metrics-snapshot.json"

    /// Injected via Info.plist (`AppGroupIdentifier`) so app and widget stay consistent.
    static var appGroupIdentifier: String? {
        Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String
    }

    static func fileURL(groupIdentifier: String? = appGroupIdentifier) -> URL? {
        guard let groupIdentifier,
              let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupIdentifier)
        else { return nil }
        return container.appendingPathComponent(fileName)
    }

    @discardableResult
    static func save(_ metrics: SystemMetrics, to url: URL? = fileURL()) -> Bool {
        guard let url else { return false }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(metrics) else { return false }
        return (try? data.write(to: url, options: .atomic)) != nil
    }

    static func load(from url: URL? = fileURL()) -> SystemMetrics? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(SystemMetrics.self, from: data)
    }

    /// Older than this and the widget treats the app as not running.
    static let staleAfter: TimeInterval = 180
}
