//
//  AppIconPicker.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// ryC0's icons in Settings > Appearance, each a small picture of
/// itself, in a grid. Choosing one asks iOS to put it on the Home Screen,
/// which iOS confirms with an alert of its own.
struct AppIconPicker: View {
    @State private var selection = AppIconChoice(alternateIconName: UIApplication.shared.alternateIconName)
    @State private var errorMessage: String?
    @ScaledMetric(relativeTo: .body) private var minimumWidth = 72.0

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: minimumWidth), spacing: 8)], spacing: 12) {
            ForEach(AppIconChoice.allCases) { choice in
                AppIconSwatch(choice: choice, isSelected: choice == selection) {
                    choose(choice)
                }
            }
        }
        .padding(.vertical, 8)
        .sensoryFeedback(.selection, trigger: selection)
        .alert(
            "ryc0.settings.appIconFailed".loc,
            isPresented: Binding<Bool>.isPresented(for: $errorMessage),
            presenting: errorMessage
        ) { _ in
            Button("lc.common.ok".loc) { }
        } message: { message in
            Text(message)
        }
    }

    /// Shows the choice straight away, and goes back to the icon in use if iOS
    /// turns it down.
    private func choose(_ choice: AppIconChoice) {
        guard choice != selection else {
            return
        }
        let previous = selection
        selection = choice
        Task {
            do {
                try await UIApplication.shared.setAlternateIconName(choice.alternateIconName)
            } catch {
                selection = previous
                errorMessage = error.localizedDescription
            }
        }
    }
}
