import SwiftUI

@main
struct AnswerSheetToolkitApp: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(store)
                .frame(minWidth: 820, minHeight: 560)
        }
        .windowToolbarStyle(.unified)
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
