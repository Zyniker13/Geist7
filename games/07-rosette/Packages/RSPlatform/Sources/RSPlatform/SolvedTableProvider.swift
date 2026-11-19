import Foundation
import RSCore
import RSAI

// MARK: - Box

/// A reference-type box for sharing a value across a closure boundary
/// (avoids the "mutation of captured var in concurrently-executing code"
/// diagnostic in Swift 6).
private final class Box<T>: @unchecked Sendable {
    var value: T
    init(_ value: T) { self.value = value }
}

// MARK: - TableSource

/// A source of the solved win-probability table (RS-P7.2). The table moves
/// from the app's main bundle to an on-demand resource (ODR) so the base
/// download stays small; the source abstracts *where* the table comes from
/// so the app and the tests can use the same provider.
///
/// A source returns the table file's URL, or nil when the table is not
/// available (offline, not yet downloaded, or no table ships). A nil URL
/// degrades the AI to expectiminimax — the offline fallback the G7 gate
/// verifies.
public protocol TableSource: Sendable {
    /// The URL of the solved table file, or nil when unavailable.
    func tableURL() -> URL?
}

// MARK: - OnDemandTableSource

#if os(iOS)
/// Loads the table from an on-demand resource (RS-P7.2). The table file is
/// tagged with a resource tag in the app target; when the app needs it, a
/// `NSBundleResourceRequest` for that tag downloads (or confirms local) the
/// resource, after which the table file is read from the bundle. When the
/// resource is unavailable (offline, not downloaded) the request fails and
/// the source returns nil, so the AI falls back to expectiminimax.
///
/// iOS/iPadOS only: `NSBundleResourceRequest` is unavailable on macOS, where
/// the table ships in the bundle (`BundleTableSource`) instead.
public final class OnDemandTableSource: TableSource, @unchecked Sendable {

    /// The resource tag for the on-demand table resource.
    public let tag: String

    /// The table file name inside the bundle (no extension).
    public let fileName: String

    /// The table file extension inside the bundle.
    public let fileExtension: String

    ///   - tag: The resource tag for the on-demand table resource.
    ///   - fileName: The table file name (default `ur_finkel`).
    ///   - fileExtension: The table file extension (default `bin`).
    public init(
        tag: String,
        fileName: String = "ur_finkel",
        fileExtension: String = "bin"
    ) {
        self.tag = tag
        self.fileName = fileName
        self.fileExtension = fileExtension
    }

    /// Request the on-demand resource and return the table file's URL, or
    /// nil when the resource is unavailable (the offline fallback path).
    public func tableURL() -> URL? {
        let request = NSBundleResourceRequest(tags: [tag])
        let semaphore = DispatchSemaphore(value: 0)
        let box = Box(false)
        request.beginAccessingResources { error in
            box.value = (error == nil)
            semaphore.signal()
        }
        semaphore.wait()
        guard box.value else { return nil }
        return Bundle.main.url(forResource: fileName, withExtension: fileExtension)
    }
}
#endif

// MARK: - BundleTableSource

/// Loads the table from a regular bundle (the app bundle, or a test bundle).
/// Used when the table ships with the app rather than as an ODR, and by the
/// tests to exercise the "table available" path without a network.
public struct BundleTableSource: TableSource, Sendable {

    /// The bundle that holds the table file.
    public let bundle: Bundle

    /// The table file name inside the bundle (no extension).
    public let fileName: String

    /// The table file extension inside the bundle.
    public let fileExtension: String

    public init(
        bundle: Bundle,
        fileName: String = "ur_finkel",
        fileExtension: String = "bin"
    ) {
        self.bundle = bundle
        self.fileName = fileName
        self.fileExtension = fileExtension
    }

    public func tableURL() -> URL? {
        bundle.url(forResource: fileName, withExtension: fileExtension)
    }
}

// MARK: - NullTableSource

/// A source with no table (simulates offline / not downloaded). Always
/// returns nil, so the AI falls back to expectiminimax.
public struct NullTableSource: TableSource, Sendable {
    public init() {}
    public func tableURL() -> URL? { nil }
}

// MARK: - SolvedTableProvider

/// Produces a `SolvedTableStore` from a `TableSource` (RS-P7.2). The app
/// builds one with an `OnDemandTableSource` (the ODR bundle); the tests use
/// `BundleTableSource` (table available) and `NullTableSource` (offline).
/// When the source has no table the store degrades to nil and the AI falls
/// back to expectiminimax.
public final class SolvedTableProvider: Sendable {

    /// The table source.
    public let source: any TableSource

    public init(source: any TableSource) {
        self.source = source
    }

    /// Load the table from the source. Returns a store that degrades to nil
    /// (expectiminimax fallback) when the source has no table.
    public func load() -> SolvedTableStore {
        SolvedTableStore(url: source.tableURL())
    }

    /// Whether the source currently has a table available.
    public var isAvailable: Bool { source.tableURL() != nil }
}
