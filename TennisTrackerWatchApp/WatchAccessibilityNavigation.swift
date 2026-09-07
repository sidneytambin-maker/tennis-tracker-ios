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
            Label("Pages", systemImage: "square.grid.2x2").font(.caption)
        }
        .sheet(isPresented: $showingPages) {
            NavigationStack {
                List {
                    ForEach(TennisWatchPage.allCases) { page in
                        Button(page.rawValue) { store.page = page; showingPages = false }
                    }
                }.navigationTitle("Pages")
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showingPages = false } } }
            }
        }
        .accessibilityValue("\(store.page.rawValue), page \((TennisWatchPage.allCases.firstIndex(of: store.page) ?? 0) + 1) of 5")
        .accessibilityAdjustableAction { direction in
            let index = TennisWatchPage.allCases.firstIndex(of: store.page) ?? 0
            switch direction {
            case .increment: store.page = TennisWatchPage.allCases[min(index + 1, 4)]
            case .decrement: store.page = TennisWatchPage.allCases[max(index - 1, 0)]
            @unknown default: break
            }
        }
        .accessibilityActions {
            ForEach(TennisWatchPage.allCases) { page in Button(page.rawValue) { store.page = page } }
        }
    }
}
