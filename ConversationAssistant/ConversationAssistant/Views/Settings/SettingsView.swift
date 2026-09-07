import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }
            ProjectsSettingsView()
                .tabItem { Label("Projects", systemImage: "folder") }
            ModesSettingsView()
                .tabItem { Label("Modes", systemImage: "list.bullet") }
            AboutSettingsView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 460)
    }
}
