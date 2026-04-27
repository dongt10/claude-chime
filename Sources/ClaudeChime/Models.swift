import Foundation

struct Sound: Identifiable, Hashable, Sendable {
    var id: String { path }
    let name: String
    let path: String

    static func displayName(forPath path: String) -> String {
        URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
    }
}
