import SwiftUI
import UniformTypeIdentifiers
import WidgetKit
import AppKit
import ImageIO

private struct TaskImage: Identifiable {
    let id: String
    let image: NSImage?
}

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var tasks: [TaskImage] = []
    @State private var selected: TaskImage?
    @State private var showPicker = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var canUndo = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("SnapDo").font(.largeTitle.bold())
                    Text("Three things. One at a time.").foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(tasks.count)/3").font(.title2.monospacedDigit()).foregroundStyle(.secondary)
            }

            if tasks.isEmpty {
                ContentUnavailableView("A little room to focus", systemImage: "photo.on.rectangle.angled",
                    description: Text("Add a screenshot of something you want to do."))
                    .frame(maxWidth: .infinity, minHeight: 240)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(tasks) { task in
                            HStack(spacing: 16) {
                                Button { selected = task } label: {
                                    Group {
                                        if let image = task.image {
                                            Image(nsImage: image).resizable().scaledToFit()
                                        } else {
                                            Label("Image unavailable", systemImage: "photo")
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 150)
                                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .help("Open a larger view")
                                .accessibilityLabel("View screenshot")
                                Button { complete(task.id) } label: {
                                    Label("Done", systemImage: "checkmark.circle")
                                }
                                .controlSize(.large)
                                .help("Complete this task and free its slot")
                            }
                        }
                    }
                }
            }

            HStack {
                Button { showPicker = true } label: {
                    Label("Add Screenshot", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(tasks.count >= 3)
                .keyboardShortcut("o", modifiers: .command)
                if canUndo {
                    Button("Undo Last Done") { perform { try SnapStore().undo() } }
                }
                Spacer()
            }
            Text(tasks.count == 3
                ? "All three slots are full. Mark one Done to make room."
                : "Add one or more images. Your existing tasks stay in place.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(minWidth: 600, minHeight: 540)
        .fileImporter(isPresented: $showPicker, allowedContentTypes: [.png, .jpeg], allowsMultipleSelection: true) { result in
            perform { try SnapStore().add(result.get()) }
        }
        .alert("SnapDo", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorMessage ?? "Something went wrong.") }
        .sheet(item: $selected) { task in
            VStack(spacing: 16) {
                HStack {
                    Text("Screenshot").font(.headline)
                    Spacer()
                    Button("Done with Task") { complete(task.id); selected = nil }
                    Button("Close") { selected = nil }.keyboardShortcut(.cancelAction)
                }
                if let url = try? SnapStore().imageURL(task.id), let image = NSImage(contentsOf: url) {
                    GeometryReader { geometry in
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                    }
                } else { Text("This screenshot is no longer available.") }
            }
            .padding(20)
            .frame(
                width: min(960, (NSScreen.main?.visibleFrame.width ?? 1040) - 80),
                height: min(720, (NSScreen.main?.visibleFrame.height ?? 820) - 100)
            )
        }
        .onAppear { refresh() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { refresh() } }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in refresh() }
        .onOpenURL { url in
            guard url.scheme == "snapdo" else { return }
            refresh()
            if url.host == "add" { showPicker = tasks.count < 3 }
            if url.host == "view", let id = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "id" })?.value {
                selected = tasks.first { $0.id == id }
            }
        }
    }

    private func complete(_ id: String) {
        perform { try SnapStore().complete(id) }
    }

    private func perform(_ operation: () throws -> Void) {
        do {
            try operation()
            refresh()
            WidgetCenter.shared.reloadTimelines(ofKind: "SnapDoWidget")
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func refresh() {
        do {
            let store = try SnapStore()
            tasks = try store.list().map { name in
                let url = try store.imageURL(name)
                var image: NSImage?
                if let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                   let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: 900
                   ] as CFDictionary) {
                    image = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
                }
                return TaskImage(id: name, image: image)
            }
            canUndo = store.canUndo
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
