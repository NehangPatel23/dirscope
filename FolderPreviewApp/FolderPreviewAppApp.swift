import AppKit
import SwiftUI

@main
struct FolderPreviewAppApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        PreviewSettings.registerDefaults()
        ArchiveEntryOpenBridge.configureLaunchMode()

        if ArchiveEntryOpenBridge.handleEarlyLaunchArguments() {
            exit(0)
        }

        ArchiveEntryOpenBridge.installHostOpenHandler()
    }

    var body: some Scene {
        WindowGroup {
            if ArchiveEntryOpenBridge.isBackgroundOpenHelperMode {
                BackgroundHelperRootView()
            } else {
                ContentView()
                    .onOpenURL { url in
                        ArchiveEntryOpenBridge.handleIncomingURL(url)
                    }
            }
        }
        .defaultSize(width: 780, height: 560)
        .windowResizability(.contentMinSize)

        Settings {
            if ArchiveEntryOpenBridge.isBackgroundOpenHelperMode {
                EmptyView()
            } else {
                SettingsView()
            }
        }
    }
}

private struct BackgroundHelperRootView: View {
    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear {
                NSApp.setActivationPolicy(.accessory)
                DispatchQueue.main.async {
                    for window in NSApp.windows where window.canBecomeMain {
                        window.orderOut(nil)
                    }
                }
            }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if ArchiveEntryOpenBridge.isBackgroundOpenHelperMode {
            NSApp.setActivationPolicy(.accessory)
        }
        ArchiveEntryOpenBridge.processPendingOpenOnLaunch()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        if !ArchiveEntryOpenBridge.isBackgroundOpenHelperMode {
            ArchiveEntryOpenBridge.promoteToForegroundApp()
        }
        _ = ArchiveEntryOpenBridge.processPendingOpenIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        ArchiveEntryOpenBridge.applicationWillTerminate()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if ArchiveEntryOpenBridge.isBackgroundOpenHelperMode {
            return false
        }
        ArchiveEntryOpenBridge.promoteToForegroundApp()
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            ArchiveEntryOpenBridge.handleIncomingURL(url)
        }
    }
}
