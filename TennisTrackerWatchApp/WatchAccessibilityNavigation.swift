import SwiftUI

enum WatchAccessibilityNavigation {
    static var testingEnabled: Bool {
        #if targetEnvironment(simulator)
        ProcessInfo.processInfo.arguments.contains("-watch-accessibility-navigation")
        #else
        false
        #endif
    }
}

struct WatchPageSelector: View {
    @EnvironmentObject private var store: WatchTennisStore
    @State private var showingPages = false
    var body: some View {
        Button { showingPages = true } label: {
            Image(systemName: "square.grid.2x2")
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(TennisSportStyle.ink)
        }
        .accessibilityLabel("Menu")
        .accessibilityHint("Opens the five app screens. You can also choose a screen using Actions.")
        .sheet(isPresented: $showingPages) {
            NavigationStack {
                List {
                    ForEach(TennisWatchPage.allCases) { page in
                        Button(page.rawValue) { store.page = page; showingPages = false }
                    }
                }.navigationTitle("Menu")
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showingPages = false } } }
            }
        }
        .accessibilityValue("Current screen: \(store.page.rawValue)")
        .accessibilityActions {
            ForEach(TennisWatchPage.allCases) { page in Button(page.rawValue) { store.page = page } }
        }
    }
}
