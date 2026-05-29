import SwiftUI

/// Root layout: sidebar + answer grid, top toolbar, theme application.
struct MainView: View {
    @EnvironmentObject private var store: AppStore
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    private var palette: ThemePalette {
        ThemePalette.palette(for: store.settings.theme)
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 360)
        } detail: {
            DetailView()
        }
        .environment(\.palette, palette)
        .preferredColorScheme(store.settings.theme.preferredColorScheme)
        .tint(palette.accent)
        .toolbar { TopToolbarView() }
        .overlay(alignment: .bottom) { ToastView(toast: store.toast) }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: store.toast)
        .sheet(isPresented: $store.showingSettings) {
            SettingsView()
                .environmentObject(store)
                .environment(\.palette, palette)
                .preferredColorScheme(store.settings.theme.preferredColorScheme)
        }
    }
}

/// A transient toast notification shown near the bottom of the window.
private struct ToastView: View {
    let toast: ToastMessage?

    var body: some View {
        if let toast {
            HStack(spacing: 8) {
                Image(systemName: toast.isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(toast.isSuccess ? Color.green : Color.orange)
                Text(toast.message)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }
            .font(.callout)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(.separator, lineWidth: 0.5))
            .shadow(radius: 8, y: 2)
            .padding(.bottom, 24)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .id(toast.id)
        }
    }
}

/// The detail pane: either the answer grid or an empty state.
private struct DetailView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.palette) private var palette

    var body: some View {
        ZStack {
            palette.windowBackground.ignoresSafeArea()
            if store.activeSheet != nil {
                AnswerGridView()
            } else {
                EmptyStateView()
            }
        }
    }
}

private struct EmptyStateView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundStyle(palette.secondaryText)
            Text(store.t("empty.title"))
                .font(.title2)
                .foregroundStyle(palette.primaryText)
            Text(store.t("empty.subtitle"))
                .font(.body)
                .foregroundStyle(palette.secondaryText)
            Button {
                store.createSheet()
            } label: {
                Label(store.t("toolbar.newSheet"), systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
