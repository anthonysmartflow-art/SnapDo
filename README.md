# SnapDo

**Three things. One at a time.**

SnapDo is a native macOS desktop widget that turns screenshots into a small, visual to-do list. Keep up to three screenshot tasks visible, open an image when you need the details, and check it off when you're done.

Built by **A.J. Rosenberger** as a personal productivity project, using AI-assisted development.

## What it does

- Adds PNG or JPEG images through the widget's Add Screenshot action.
- Keeps a maximum of three active tasks to encourage focus.
- Opens screenshots in a resizable viewer.
- Completes tasks directly from the widget with an interactive checkmark.
- Shares local task data between the app and widget through an App Group.
- Uses file locking and atomic manifest writes to coordinate storage updates.

Screenshot data stays in the local shared container; this source snapshot contains no networking or account system. Completing a task removes it from the active list but retains its image locally for undo and existing widget timelines.

## Built with

Swift, SwiftUI, AppKit, WidgetKit, App Intents, Foundation, and ImageIO.

## Source guide

| File | Purpose |
| --- | --- |
| `SnapDo/SnapDoApp.swift` | App entry point, image picker, URL handling, and screenshot viewer |
| `SnapDo/SnapStore.swift` | Three-item task list, local image storage, completion, undo, and file locking |
| `SnapDoWidget/SnapDoWidget.swift` | Widget layout, image thumbnails, and interactive completion intent |
| `SnapDoWidget/SnapStore.swift` | Matching storage implementation compiled into the widget target |
| `SnapDo/ContentView.swift` | Additional task-list view retained in the source; not the current app entry interface |
| `SnapDo.xcodeproj` | Xcode project containing the app and widget extension |

The two copies of `SnapStore.swift` must stay identical. The project also retains Xcode-generated configuration and timer-control starter files; the timer is a placeholder, not a working SnapDo feature.

## Build locally

This is a source-code portfolio project, not an App Store release or a ready-to-install download.

1. Clone this repository and open `SnapDo.xcodeproj` in Xcode.
2. Use an Xcode/macOS SDK compatible with the project. The checked-in deployment target is **macOS 26.5**.
3. Configure signing for both **SnapDo** and **SnapDoWidgetExtension** using your own Apple development team.
4. Configure an App Group authorized for your team. Use the same identifier in both entitlement files and both copies of `SnapStore.swift`. The checked-in team and group identify the original local development setup.
5. Build the **SnapDo** scheme for **My Mac**, launch the app, then add the large **SnapDo** widget from macOS's widget gallery.
6. Use the widget's plus button to add an image. If needed, the image picker can also be opened with:

```bash
open "snapdo://add"
```

The app runs as a background utility and does not open a main window on launch. Its current interface is the widget, image picker, and screenshot viewer.

## Repository scope

This repository preserves the existing app source and project configuration. Personal screenshots, task data, signing certificates, provisioning profiles, build output, and user-specific Xcode workspace settings are not included.
