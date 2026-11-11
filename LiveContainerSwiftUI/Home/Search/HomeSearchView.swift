//
//  HomeSearchView.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Search over the blurred Home Screen, laid out like iOS 26's: results at
/// the top, and the search field at the bottom, above the keyboard. Before
/// anything is typed it suggests the apps opened most recently and offers the
/// hidden apps behind Face ID. With the keyboard down, the Home button under
/// the field closes search. VoiceOver stays in search while it is open.
///
/// On iPad the panels and the field keep to a column in the middle, like
/// Spotlight's, and the Home button shows whenever no on-screen keyboard
/// covers the bottom, as with a hardware keyboard.
struct HomeSearchView: View {
    @Environment(HomeScreenModel.self) private var model
    @FocusState private var isFieldFocused: Bool
    /// Whether the Home button shows under the field. On iPhone it shows
    /// whenever the field doesn't have the keyboard; on iPad, whenever no
    /// on-screen keyboard is up. As search opens it waits a moment for the
    /// keyboard, so it doesn't flash, and shows if the keyboard never came.
    @State private var showsHomeButton = false
    /// On iPad, whether an on-screen keyboard is up. The iPhone goes by the
    /// field's focus instead.
    @State private var isKeyboardUp = false

    var body: some View {
        @Bindable var model = model
        let metrics = model.padMetrics ?? model.metrics ?? .reference
        let query = model.searchQuery

        VStack(spacing: HomeDesign.searchSpacing) {
            ScrollView {
                VStack(spacing: HomeDesign.searchSpacing) {
                    HomeSearchResults(apps: model.searchResults, query: query, metrics: metrics)
                    if query.isEmpty {
                        HomeHiddenApps(metrics: metrics)
                    }
                }
                // Inside the scroll view, so it scrolls from the margins too.
                .padMaximumWidth(Self.padMaximumWidth)
                .padding(.horizontal, HomeDesign.searchMargin)
                .padding(.top, HomeDesign.searchSpacing)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)

            HomeSearchField(
                text: $model.searchText,
                isFocused: $isFieldFocused,
                onSubmit: model.openFirstSearchResult,
                onClose: model.closeSearch
            )
            .padMaximumWidth(Self.padMaximumWidth)
            .padding(.horizontal, HomeDesign.searchMargin)
            .padding(.bottom, HomeDesign.searchSpacing / 2)

            // The keyboard covers the bottom of the screen while it's up, so
            // the Home button shows under the field once it goes away.
            if showsHomeButton {
                HomeButton(action: model.goHome)
                    .padding(.bottom, HomeDesign.homeButtonBarPadding)
                    .transition(.opacity)
            }
        }
        .animation(HomeDesign.modeChange, value: showsHomeButton)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        // A pull down shows search before it opens; the field takes the
        // keyboard once it does.
        .onChange(of: model.isSearching, initial: true) {
            if model.isSearching {
                focusField()
            }
        }
        .task(id: model.isSearching) {
            guard model.isSearching else {
                return
            }
            await showHomeButtonIfUnfocused()
        }
        .onChange(of: isFieldFocused, fieldFocusChanged)
        .onReceive(OnScreenKeyboard.changes, perform: keyboardChanged)
    }

    /// The widest search's panels and field get on iPad, about Spotlight's.
    /// HomeAppGrid fits its columns to it.
    static let padMaximumWidth = 600.0

    private func focusField() {
        isFieldFocused = true
    }

    /// Shows the Home button when the field still hasn't got the keyboard a
    /// moment after search opened, so it never stays missing. On iPad it goes
    /// by whether an on-screen keyboard came up.
    private func showHomeButtonIfUnfocused() async {
        try? await Task.sleep(for: HomeDesign.searchFocusWait)
        guard !Task.isCancelled else {
            return
        }
        showsHomeButton = SharedModel.isPhone ? !isFieldFocused : !isKeyboardUp
    }

    private func fieldFocusChanged(from wasFocused: Bool, to isFocused: Bool) {
        guard SharedModel.isPhone else {
            return
        }
        showsHomeButton = !isFocused
    }

    /// On iPad, shows the Home button whenever no on-screen keyboard covers
    /// the bottom, focused field or not, and hides it while one does.
    private func keyboardChanged(_ notification: Notification) {
        guard !SharedModel.isPhone else {
            return
        }
        isKeyboardUp = OnScreenKeyboard.isUp(after: notification)
        showsHomeButton = !isKeyboardUp
    }
}
