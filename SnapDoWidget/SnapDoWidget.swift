import WidgetKit
import SwiftUI
import AppKit
import ImageIO
import AppIntents

struct CompleteScreenshotIntent: AppIntent {
    static var title: LocalizedStringResource = "Complete Screenshot"
    static var description = IntentDescription("Mark a screenshot task done and free its slot.")
    @Parameter(title: "Screenshot") var filename: String
    init() {}
    init(filename: String) { self.filename = filename }
    func perform() async throws -> some IntentResult {
        try SnapStore().complete(filename)
        WidgetCenter.shared.reloadTimelines(ofKind: "SnapDoWidget")
        return .result()
    }
}

struct ScreenshotItem: Identifiable {
    let id: String
    let image: NSImage?
    var link: URL {
        var parts = URLComponents()
        parts.scheme = "snapdo"
        parts.host = "view"
        parts.queryItems = [URLQueryItem(name: "id", value: id)]
        return parts.url!
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let screenshots: [ScreenshotItem]
    let message: String?
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), screenshots: [], message: "Add a screenshot to get started.")
    }
    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) { completion(loadEntry()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        completion(Timeline(entries: [loadEntry()], policy: .never))
    }
    private func loadEntry() -> SimpleEntry {
        do {
            let store = try SnapStore()
            let items = try store.list().map { name in
                let url = try store.imageURL(name)
                var image: NSImage?
                if let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                   let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: 700
                   ] as CFDictionary) {
                    image = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
                }
                return ScreenshotItem(id: name, image: image)
            }
            return SimpleEntry(date: Date(), screenshots: items, message: nil)
        } catch {
            return SimpleEntry(date: Date(), screenshots: [], message: error.localizedDescription)
        }
    }
}

struct SnapDoWidgetEntryView: View {
    let entry: SimpleEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("SnapDo").font(.headline)
                Spacer()
                Text("\(entry.screenshots.count)/3").font(.caption).foregroundStyle(.secondary)
                if entry.screenshots.count < 3 {
                    Link(destination: URL(string: "snapdo://add")!) {
                        Image(systemName: "plus.circle.fill").font(.title3)
                    }.accessibilityLabel("Add screenshot")
                }
            }
            if entry.screenshots.isEmpty {
                Spacer()
                Text(entry.message ?? "All clear. Add your next screenshot task.")
                    .font(.caption).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).frame(maxWidth: .infinity)
                Link("Add Screenshot", destination: URL(string: "snapdo://add")!)
                    .font(.caption.bold()).frame(maxWidth: .infinity)
                Spacer()
            } else {
                ForEach(entry.screenshots) { screenshot in
                    HStack(spacing: 8) {
                        Link(destination: screenshot.link) {
                            GeometryReader { geometry in
                                Group {
                                    if let image = screenshot.image {
                                        Image(nsImage: image).resizable()
                                            .widgetAccentedRenderingMode(.fullColor).scaledToFit()
                                    } else {
                                        Image(systemName: "photo.badge.exclamationmark")
                                    }
                                }
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .background(Color.primary.opacity(0.04))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }.accessibilityLabel("Open screenshot")
                        Button(intent: CompleteScreenshotIntent(filename: screenshot.id)) {
                            Image(systemName: "checkmark.circle")
                                .font(.title2).frame(width: 32, height: 40)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Mark screenshot done")
                    }
                }
            }
        }
    }
}

struct SnapDoWidget: Widget {
    let kind = "SnapDoWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            SnapDoWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("SnapDo")
        .description("Add a screenshot, open it, and check it off.")
        .supportedFamilies([.systemLarge])
    }
}

