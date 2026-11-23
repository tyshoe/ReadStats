import Flutter
import UIKit
import UniformTypeIdentifiers
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var backupFolder: BackupFolderChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Required by flutter_local_notifications so notifications can be shown
    // while the app is in the foreground.
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    GeneratedPluginRegistrant.register(with: self)
    if let registrar = self.registrar(forPlugin: "BackupFolderChannel") {
      backupFolder = BackupFolderChannel(messenger: registrar.messenger())
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

/// A folder the reader picked in Files for automatic backups — on this iPhone
/// or in iCloud Drive. Access is kept across launches with a bookmark, which is
/// the folder's id; a file's ref is its name.
///
/// Reads and writes are coordinated (NSFileCoordinator), so an iCloud file
/// that isn't downloaded yet is fetched before it's copied. A folder that can
/// no longer be reached fails with code `no_access`.
///
/// The same channel exists on Android (BackupFolderChannel.kt), so the Dart
/// side is shared.
class BackupFolderChannel: NSObject, UIDocumentPickerDelegate {
  private let channel: FlutterMethodChannel
  private var pending: FlutterResult?
  /// Folders whose security scope is open, by id. Touched only on [queue].
  private var open: [String: URL] = [:]
  private let queue = DispatchQueue(label: "com.tyshoe.readstats.backup-folder", qos: .utility)

  private struct NoAccess: Error {}

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "com.tyshoe.readstats/backup_folder", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result)
    }
  }

  private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    if call.method == "pick" {
      pick(result)
      return
    }
    let args = call.arguments as? [String: Any] ?? [:]
    guard let id = args["id"] as? String else {
      result(FlutterError(code: "bad_args", message: "No folder id", details: nil))
      return
    }
    let known = ["check", "list", "write", "read", "delete", "release"]
    guard known.contains(call.method) else {
      result(FlutterMethodNotImplemented)
      return
    }
    queue.async {
      do {
        let value = try self.run(call.method, id: id, args: args)
        DispatchQueue.main.async { result(value) }
      } catch is NoAccess {
        DispatchQueue.main.async {
          result(FlutterError(
            code: "no_access", message: "The backup folder can't be reached", details: nil))
        }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: "failed", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  private func run(_ method: String, id: String, args: [String: Any]) throws -> Any? {
    if method == "release" {
      open.removeValue(forKey: id)?.stopAccessingSecurityScopedResource()
      return nil
    }
    let folder = try resolve(id)
    switch method {
    case "check":
      return folder.lastPathComponent
    case "list":
      return try list(folder)
    case "write":
      guard let name = args["name"] as? String, let src = args["src"] as? String else {
        throw NoAccess()
      }
      try write(URL(fileURLWithPath: src), to: folder.appendingPathComponent(name))
      return nil
    case "read":
      guard let ref = args["ref"] as? String, let dest = args["dest"] as? String else {
        throw NoAccess()
      }
      try read(folder.appendingPathComponent(ref), to: URL(fileURLWithPath: dest))
      return nil
    case "delete":
      guard let ref = args["ref"] as? String else { throw NoAccess() }
      try coordinate(writing: folder.appendingPathComponent(ref), options: .forDeleting) {
        try FileManager.default.removeItem(at: $0)
      }
      return nil
    default:
      return nil
    }
  }

  // ─── Picking ────────────────────────────────────────────────────────────

  private func pick(_ result: @escaping FlutterResult) {
    guard pending == nil else {
      result(FlutterError(code: "busy", message: "A folder is already being picked", details: nil))
      return
    }
    guard let presenter = topController() else {
      result(FlutterError(code: "unavailable", message: "Nothing to present from", details: nil))
      return
    }
    pending = result
    let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.folder])
    picker.delegate = self
    picker.allowsMultipleSelection = false
    presenter.present(picker, animated: true)
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard let result = pending else { return }
    pending = nil
    guard let url = urls.first else {
      result(nil)
      return
    }
    queue.async {
      do {
        guard url.startAccessingSecurityScopedResource() else { throw NoAccess() }
        let bookmark = try url.bookmarkData(
          options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        let id = bookmark.base64EncodedString()
        self.open[id] = url
        DispatchQueue.main.async { result(["id": id, "name": url.lastPathComponent]) }
      } catch {
        url.stopAccessingSecurityScopedResource()
        DispatchQueue.main.async {
          result(FlutterError(
            code: "no_access", message: "Couldn't keep access to that folder", details: nil))
        }
      }
    }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    pending?(nil)
    pending = nil
  }

  private func topController() -> UIViewController? {
    // The app uses the app delegate's window (no scene manifest); the scene
    // lookup covers a later move to scenes.
    var window = UIApplication.shared.connectedScenes
      .compactMap { ($0 as? UIWindowScene)?.keyWindow }
      .first
    if window == nil, let appWindow = UIApplication.shared.delegate?.window {
      window = appWindow
    }
    var top = window?.rootViewController
    while let presented = top?.presentedViewController { top = presented }
    return top
  }

  // ─── Files ──────────────────────────────────────────────────────────────

  /// The folder behind [id], with its security scope open.
  private func resolve(_ id: String) throws -> URL {
    if let url = open[id] { return url }
    guard let data = Data(base64Encoded: id) else { throw NoAccess() }
    var stale = false
    guard
      let url = try? URL(
        resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale),
      url.startAccessingSecurityScopedResource()
    else { throw NoAccess() }
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
      isDirectory.boolValue
    else {
      url.stopAccessingSecurityScopedResource()
      throw NoAccess()
    }
    open[id] = url
    return url
  }

  private func list(_ folder: URL) throws -> [[String: Any]] {
    let keys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey]
    let items = try FileManager.default.contentsOfDirectory(
      at: folder, includingPropertiesForKeys: keys, options: [])
    var files: [[String: Any]] = []
    for item in items {
      let values = try? item.resourceValues(forKeys: Set(keys))
      if values?.isDirectory == true { continue }
      var name = item.lastPathComponent
      var size = values?.fileSize
      // An iCloud file not downloaded yet shows as ".Name.icloud".
      if name.hasPrefix("."), name.hasSuffix(".icloud") {
        name = String(name.dropFirst().dropLast(".icloud".count))
        size = nil
      } else if name.hasPrefix(".") {
        continue
      }
      let modified = values?.contentModificationDate.map { Int64($0.timeIntervalSince1970 * 1000) }
      files.append([
        "ref": name,
        "name": name,
        "size": size.map { $0 as Any } ?? NSNull(),
        "modified": modified.map { $0 as Any } ?? NSNull(),
      ])
    }
    return files
  }

  private func write(_ src: URL, to dest: URL) throws {
    try coordinate(writing: dest, options: .forReplacing) { target in
      if FileManager.default.fileExists(atPath: target.path) {
        try FileManager.default.removeItem(at: target)
      }
      try FileManager.default.copyItem(at: src, to: target)
    }
  }

  private func read(_ src: URL, to dest: URL) throws {
    var failure: Error?
    var coordinationError: NSError?
    NSFileCoordinator().coordinate(readingItemAt: src, options: [], error: &coordinationError) {
      source in
      do {
        if FileManager.default.fileExists(atPath: dest.path) {
          try FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.copyItem(at: source, to: dest)
      } catch {
        failure = error
      }
    }
    if let error = coordinationError ?? failure { throw error }
  }

  private func coordinate(
    writing url: URL, options: NSFileCoordinator.WritingOptions, _ work: (URL) throws -> Void
  ) throws {
    var failure: Error?
    var coordinationError: NSError?
    NSFileCoordinator().coordinate(writingItemAt: url, options: options, error: &coordinationError) {
      target in
      do { try work(target) } catch { failure = error }
    }
    if let error = coordinationError ?? failure { throw error }
  }
}
