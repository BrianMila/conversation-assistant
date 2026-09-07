//
//  ConversationAssistantApp.swift
//  ConversationAssistant
//
//  Created by Brian Mila on 3/13/26.
//

import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main
struct ConversationAssistantApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var settings = AppSettings()
    @State private var modesManager = ModesManager()
    @State private var sessionState = SessionState()
    @State private var audioService = AudioService()
    @State private var suggestionService = SuggestionService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settings)
                .environment(modesManager)
                .environment(sessionState)
                .environment(audioService)
                .environment(suggestionService)
        }
        .windowResizability(.contentMinSize)

        Window("Guide", id: "guide-panel") {
            GuidePanelView()
                .environment(settings)
                .environment(modesManager)
                .environment(sessionState)
        }
        .defaultSize(width: 480, height: 600)
        .windowResizability(.contentMinSize)

        Settings {
            SettingsView()
                .environment(settings)
                .environment(modesManager)
        }
    }
}
