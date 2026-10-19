import SwiftUI
import AppKit
import UniformTypeIdentifiers
import WidgetKit

@main
struct SnapDoApp: App {
    @NSApplicationDelegateAdaptor(SnapDoDelegate.self) private var delegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

@MainActor
final class SnapDoDelegate: NSObject, NSApplicationDelegate {
    private var viewer: NSWindow?
    private var picker: NSOpenPanel?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "snapdo" {
            if url.host == "add" {
                addScreenshot()
            } else if url.host == "view",
                      let filename = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                        .queryItems?.first(where: { $0.name == "id" })?.value {
                showScreenshot(filename)
            }
        }
    }

    private func showScreenshot(_ filename: String) {
        do {
            let store = try SnapStore()
            guard try store.list().contains(filename),
                  let image = NSImage(contentsOf: try store.imageURL(filename)) else {
                showError("This screenshot is no longer in your task list.")
                return
            }
            let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1040, height: 820)
            let size = NSSize(width: min(1100, screen.width - 80), height: min(800, screen.height - 100))
            let window = viewer ?? NSWindow(
                contentRect: NSRect(origin: .zero, size: size),
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.title = "Screenshot"
            window.contentMinSize = NSSize(width: 320, height: 240)
            window.collectionBehavior = [.moveToActiveSpace, .fullScreenPrimary]
            window.contentView = NSHostingView(rootView: ScreenshotOnlyView(image: image))
            if viewer == nil { window.center() }
            viewer = window
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } catch { showError(error.localizedDescription) }
    }

    private func addScreenshot() {
        guard picker == nil else {
            picker?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        do {
            let available = 3 - (try SnapStore().list().count)
            guard available > 0 else {
                showError("All three slots are full. Use the widget's checkmark to finish a task first.")
                return
            }
            let panel = NSOpenPanel()
            panel.title = "Add Screenshot"
            panel.prompt = "Add"
            panel.message = "Choose up to \(available) images. Existing tasks stay in place."
            panel.allowedContentTypes = [.png, .jpeg]
            panel.canChooseDirectories = false
            panel.allowsMultipleSelection = available > 1
            picker = panel
            NSApp.activate(ignoringOtherApps: true)
            panel.begin { [weak self] response in
                guard let self else { return }
                self.picker = nil
                guard response == .OK else { return }
                do {
                    try SnapStore().add(panel.urls)
                    WidgetCenter.shared.reloadTimelines(ofKind: "SnapDoWidget")
                } catch { self.showError(error.localizedDescription) }
            }
        } catch { showError(error.localizedDescription) }
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "SnapDo"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}

private struct ScreenshotOnlyView: View {
    let image: NSImage

    var body: some View {
        GeometryReader { geometry in
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .padding(12)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
