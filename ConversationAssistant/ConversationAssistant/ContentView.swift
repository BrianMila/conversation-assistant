//
//  ContentView.swift
//  ConversationAssistant
//
//  Created by Brian Mila on 3/13/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(SessionState.self) private var sessionState

    var body: some View {
        if sessionState.isActive {
            ActiveSessionView()
        } else {
            PreSessionView()
        }
    }
}

#Preview {
    ContentView()
}
