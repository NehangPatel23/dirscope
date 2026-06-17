import AppKit
import Foundation
import Darwin

/// Stages archive entries from the sandboxed Quick Look extension and asks the host app to open them.
enum ArchiveEntryOpenBridge {
    static let backgroundHelperArgument = "-backgroundOpenHelper"
    static let registerLoginItemArgument = "-registerLoginItem"
    static let launchAgentLabel = "com.folderpreview.app.openhelper"

    private static let darwinNotification = "com.dirscope.openStagedArchiveEntry" as CFString
    private static let hostBundleIdentifier = "com.folderpreview.app"
    private static let pendingRequestFileName = "PendingOpen.plist"
    private static let backgroundHelperPIDFileName = "BackgroundHelper.pid"

    private(set) static var isBackgroundOpenHelperMode = false

    private static var pendingRequestURL: URL {
        SharedPreferencesStore.preferencesDirectory.appendingPathComponent(pendingRequestFileName)
    }

    private static var backgroundHelperPIDURL: URL {
        SharedPreferencesStore.preferencesDirectory.appendingPathComponent(backgroundHelperPIDFileName)
    }

    static var stagingDirectory: URL {
        SharedPreferencesStore.preferencesDirectory.appendingPathComponent("OpenStaging", isDirectory: true)
    }

    static func configureLaunchMode(arguments: [String] = CommandLine.arguments) {
        isBackgroundOpenHelperMode = arguments.contains(backgroundHelperArgument)
    }

    /// Handle headless setup flags before SwiftUI starts. Returns true when the process should exit.
    static func handleEarlyLaunchArguments() -> Bool {
        guard !SharedPreferencesStore.isQuickLookExtension else { return false }

        if CommandLine.arguments.contains(registerLoginItemArgument) {
            startBackgroundOpenHelperIfNeeded()
            return true
        }

        if isBackgroundOpenHelperMode, !acquireBackgroundHelperInstance() {
            return true
        }

        return false
    }

    static func stage(data: Data, filename: String) -> URL? {
        let safeName = filename.replacingOccurrences(of: "/", with: "_")
        let directory = stagingDirectory

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let stagedURL = directory.appendingPathComponent(safeName)
            if FileManager.default.fileExists(atPath: stagedURL.path) {
                try FileManager.default.removeItem(at: stagedURL)
            }
            try data.write(to: stagedURL, options: .atomic)
            return stagedURL
        } catch {
            return nil
        }
    }

    static func installHostOpenHandler() {
        guard !SharedPreferencesStore.isQuickLookExtension else { return }
        HostOpenObserver.shared.install()
        _ = processPendingOpenIfNeeded()

        if !isBackgroundOpenHelperMode {
            startBackgroundOpenHelperIfNeeded()
        }
    }

    static func startBackgroundOpenHelperIfNeeded() {
        guard !SharedPreferencesStore.isQuickLookExtension else { return }
        guard !isBackgroundOpenHelperMode else { return }
        guard !isBackgroundHelperProcessRunning() else { return }
        launchBackgroundOpenHelper()
    }

    struct BackgroundOpenHelperStatus {
        let isLaunchAgentInstalled: Bool
        let isRunning: Bool
        let helperExecutablePath: String?
    }

    static func backgroundOpenHelperStatus() -> BackgroundOpenHelperStatus {
        BackgroundOpenHelperStatus(
            isLaunchAgentInstalled: isLaunchAgentInstalled(),
            isRunning: isBackgroundHelperProcessRunning(),
            helperExecutablePath: resolvedHelperExecutableURL()?.path
        )
    }

    @discardableResult
    static func reinstallBackgroundOpenHelper() -> Bool {
        guard !SharedPreferencesStore.isQuickLookExtension else { return false }
        guard let helperURL = resolvedHelperExecutableURL() else { return false }

        let plistURL = launchAgentPlistURL()
        do {
            try FileManager.default.createDirectory(
                at: plistURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            let plist: [String: Any] = [
                "Label": launchAgentLabel,
                "ProgramArguments": [helperURL.path, backgroundHelperArgument],
                "RunAtLoad": true,
                "ProcessType": "Background"
            ]
            let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            try data.write(to: plistURL, options: .atomic)

            let target = "gui/\(getuid())/\(launchAgentLabel)"
            runLaunchctl(arguments: ["bootout", target])
            _ = runLaunchctl(arguments: ["bootstrap", target, plistURL.path])
            launchBackgroundOpenHelper()
            return true
        } catch {
            return false
        }
    }

    static func isLaunchAgentInstalled() -> Bool {
        FileManager.default.fileExists(atPath: launchAgentPlistURL().path)
    }

    static func isBackgroundHelperRunning() -> Bool {
        isBackgroundHelperProcessRunning()
    }

    private static func launchAgentPlistURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(launchAgentLabel).plist")
    }

    private static func resolvedHelperExecutableURL() -> URL? {
        let bundleExecutable = Bundle.main.bundleURL
            .appendingPathComponent("Contents/MacOS/Dirscope")
        if FileManager.default.isExecutableFile(atPath: bundleExecutable.path) {
            return bundleExecutable
        }

        let installed = URL(fileURLWithPath: "/Applications/Dirscope.app/Contents/MacOS/Dirscope")
        if FileManager.default.isExecutableFile(atPath: installed.path) {
            return installed
        }

        return NSWorkspace.shared
            .urlForApplication(withBundleIdentifier: hostBundleIdentifier)?
            .appendingPathComponent("Contents/MacOS/Dirscope")
    }

    @discardableResult
    private static func runLaunchctl(arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            return -1
        }
    }

    /// Called when the host app finishes launching.
    static func processPendingOpenOnLaunch() {
        guard !SharedPreferencesStore.isQuickLookExtension else { return }
        _ = processPendingOpenIfNeeded()
        scheduleLaunchRetries()
    }

    static func handleIncomingURL(_ url: URL) {
        guard !SharedPreferencesStore.isQuickLookExtension else { return }
        guard isPendingOpenURL(url) else { return }
        processPendingOpenOnLaunch()
        if !isBackgroundOpenHelperMode {
            scheduleHostWindowSuppression()
        }
    }

    static func requestHostOpen(stagedURL: URL) {
        writePendingRequest(path: stagedURL.path)
        postDarwinNotification()
        wakeHostApp()
    }

    static func applicationWillTerminate() {
        guard isBackgroundOpenHelperMode else { return }
        clearBackgroundHelperPID()
    }

    static func promoteToForegroundApp() {
        guard !isBackgroundOpenHelperMode else { return }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    @discardableResult
    static func processPendingOpenIfNeeded() -> Bool {
        guard !SharedPreferencesStore.isQuickLookExtension else { return false }
        guard FileManager.default.fileExists(atPath: pendingRequestURL.path),
              let data = try? Data(contentsOf: pendingRequestURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let path = plist["path"] as? String else {
            return false
        }

        try? FileManager.default.removeItem(at: pendingRequestURL)

        let stagedURL = URL(fileURLWithPath: path)
        guard FileManager.default.isReadableFile(atPath: stagedURL.path) else { return false }
        return openStagedFile(at: stagedURL)
    }

    @discardableResult
    static func openStagedFile(at url: URL) -> Bool {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.open(url, configuration: configuration) { _, error in
            if error != nil {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        }
        return true
    }

    private static func isPendingOpenURL(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "dirscope" else { return false }
        if url.host?.lowercased() == "open-pending" { return true }
        return url.path.lowercased().contains("open-pending")
    }

    private static var suppressHostWindow = false

    private static func scheduleHostWindowSuppression() {
        suppressHostWindow = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            guard suppressHostWindow else { return }
            suppressHostWindow = false
            NSApp.windows.forEach { $0.orderOut(nil) }
        }
    }

    private static func writePendingRequest(path: String) {
        let plist: [String: Any] = [
            "path": path,
            "timestamp": Date().timeIntervalSince1970
        ]
        let directory = pendingRequestURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let data = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0) else {
            return
        }
        try? data.write(to: pendingRequestURL, options: .atomic)
    }

    private static func postDarwinNotification() {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(darwinNotification),
            nil,
            nil,
            true
        )
    }

    private static func scheduleLaunchRetries() {
        let delays: [TimeInterval] = [0.15, 0.35, 0.75, 1.5]
        for delay in delays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                _ = processPendingOpenIfNeeded()
            }
        }
    }

    private static func wakeHostApp() {
        postDarwinNotification()

        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: hostBundleIdentifier) else {
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.createsNewApplicationInstance = true
        configuration.arguments = [backgroundHelperArgument]
        NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { _, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                postDarwinNotification()
            }
        }
    }

    private static func launchBackgroundOpenHelper() {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: hostBundleIdentifier) else {
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.createsNewApplicationInstance = true
        configuration.arguments = [backgroundHelperArgument]
        NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { _, _ in }
    }

    @discardableResult
    private static func acquireBackgroundHelperInstance() -> Bool {
        if isBackgroundHelperProcessRunning() {
            return false
        }

        let pid = ProcessInfo.processInfo.processIdentifier
        try? "\(pid)".write(to: backgroundHelperPIDURL, atomically: true, encoding: .utf8)
        return true
    }

    private static func isBackgroundHelperProcessRunning() -> Bool {
        guard let data = try? Data(contentsOf: backgroundHelperPIDURL),
              let pidString = String(data: data, encoding: .utf8),
              let pid = Int32(pidString),
              pid > 0 else {
            return false
        }

        if kill(pid, 0) != 0 {
            clearBackgroundHelperPID()
            return false
        }

        return pid != ProcessInfo.processInfo.processIdentifier
    }

    private static func clearBackgroundHelperPID() {
        try? FileManager.default.removeItem(at: backgroundHelperPIDURL)
    }
}

private final class HostOpenObserver {
    static let shared = HostOpenObserver()

    private var token: UnsafeMutableRawPointer?

    func install() {
        guard token == nil else { return }

        let observerToken = UnsafeMutableRawPointer(Unmanaged.passRetained(ObserverBox()).toOpaque())
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            observerToken,
            { _, _, _, _, _ in
                DispatchQueue.main.async {
                    _ = ArchiveEntryOpenBridge.processPendingOpenIfNeeded()
                }
            },
            "com.dirscope.openStagedArchiveEntry" as CFString,
            nil,
            .deliverImmediately
        )
        token = observerToken
    }

    deinit {
        if let token {
            CFNotificationCenterRemoveObserver(
                CFNotificationCenterGetDarwinNotifyCenter(),
                token,
                CFNotificationName("com.dirscope.openStagedArchiveEntry" as CFString),
                nil
            )
            Unmanaged<ObserverBox>.fromOpaque(token).release()
        }
    }
}

private final class ObserverBox {}
