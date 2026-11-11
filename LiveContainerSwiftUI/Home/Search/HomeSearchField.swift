//
//  HomeSearchField.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The search field at the bottom of search, in a glass capsule, with a
/// button beside it that closes search. On iPad, Escape closes it too.
struct HomeSearchField: View {
    /// What is typed.
    @Binding var text: String
    /// Whether the field has the keyboard.
    var isFocused: FocusState<Bool>.Binding
    /// Opens the best match, as the keyboard's Go key does.
    let onSubmit: () -> Void
    /// Closes search.
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                TextField("ryc0.home.search".loc, text: $text)
                    .focused(isFocused)
                    .submitLabel(.go)
                    .onSubmit(onSubmit)
                    .onKeyPress(.escape, action: escapePressed)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if !text.isEmpty {
                    Button(action: clear) {
                        Label("ryc0.home.clearSearch".loc, systemImage: "xmark.circle.fill")
                            .labelStyle(.iconOnly)
                            .foregroundStyle(.secondary)
                            .frame(minWidth: HomeDesign.minimumTouchSize, minHeight: HomeDesign.minimumTouchSize)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.leading, HomeDesign.searchPanelPadding)
            .padding(.trailing, text.isEmpty ? HomeDesign.searchPanelPadding : 4)
            .frame(minHeight: HomeDesign.searchFieldHeight)
            .homeGlass(.capsule)

            Button(action: onClose) {
                Label("lc.common.close".loc, systemImage: "xmark")
                    .labelStyle(.iconOnly)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: HomeDesign.searchFieldHeight, height: HomeDesign.searchFieldHeight)
                    .homeGlass(.circle, isInteractive: true)
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
        }
    }

    private func clear() {
        text = ""
    }

    /// On iPad, Escape on a hardware keyboard closes search, as it closes
    /// Spotlight. On iPhone the key goes on as before.
    private func escapePressed() -> KeyPress.Result {
        guard !SharedModel.isPhone else {
            return .ignored
        }
        onClose()
        return .handled
    }
}
