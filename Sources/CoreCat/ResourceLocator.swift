import Foundation

struct ResourceLocator {
    static func url(relativePath: String) -> URL? {
        let fm = FileManager.default

        if let root = ProcessInfo.processInfo.environment["CORECAT_RESOURCE_DIR"] {
            let url = URL(fileURLWithPath: root, isDirectory: true).appendingPathComponent(relativePath)
            if fm.fileExists(atPath: url.path) { return url }
        }

        if let resourceURL = Bundle.main.resourceURL {
            let url = resourceURL.appendingPathComponent(relativePath)
            if fm.fileExists(atPath: url.path) { return url }
        }

        // Convenient when launching the SwiftPM executable from the source tree.
        let cwdURL = URL(fileURLWithPath: fm.currentDirectoryPath, isDirectory: true)
            .appendingPathComponent("Resources", isDirectory: true)
            .appendingPathComponent(relativePath)
        if fm.fileExists(atPath: cwdURL.path) { return cwdURL }

        return nil
    }
}
