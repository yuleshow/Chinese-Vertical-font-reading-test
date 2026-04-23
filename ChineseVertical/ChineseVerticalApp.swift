import SwiftUI

@main
struct ChineseVerticalApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 800, height: 1080)
    }
}
