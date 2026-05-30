import SwiftUI

@main
struct AnswerSheetToolkitApp: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(store)
                .frame(minWidth: 320, idealWidth: 900, maxWidth: .infinity,
                       minHeight: 280, idealHeight: 640, maxHeight: .infinity)
        }
        .windowToolbarStyle(.unified)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 900, height: 640)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button(store.t("toolbar.newSheet")) {
                    store.createSheet()
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(store)
        }
    }
}
