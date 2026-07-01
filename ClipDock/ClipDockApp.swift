//
//  ClipDockApp.swift
//  ClipDock
//
//  Created by 陈睿 on 2026/6/30.
//

import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

@main
struct ClipDockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = ClipDockStore()

    var body: some Scene {
        Window("ClipDock", id: "main") {
            ContentView(store: store)
        }

        Window("Quick Add", id: "quick-add") {
            QuickAddView(store: store)
        }
        .defaultSize(width: 160, height: 78)
        .commands {
            QuickAddCommands()
        }

        MenuBarExtra("ClipDock", systemImage: "tray.and.arrow.down") {
            ClipDockMenuBarView()
        }
    }
}

private struct QuickAddCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandMenu("ClipDock") {
            Button("Show Main Window") {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }

            Button("Show Quick Add") {
                openWindow(id: "quick-add")
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
}

private struct ClipDockMenuBarView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        Button("Show Main Window") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }

        Button("Show Quick Add") {
            openWindow(id: "quick-add")
            NSApp.activate(ignoringOtherApps: true)
        }

        Button("Hide Quick Add") {
            dismissWindow(id: "quick-add")
        }

        Divider()

        Button("Quit ClipDock") {
            NSApp.terminate(nil)
        }
    }
}
