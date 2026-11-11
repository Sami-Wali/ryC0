//
//  AddToHomeScreenSheet.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Add to Home Screen's sheet: first how the icon opens the app, then, once
/// the person taps Add, Safari offering the web clip's profile, in the same
/// sheet. iOS has the person allow the download and install the profile in
/// Settings, so once Safari shows, the sheet closes when ryC0 goes to
/// the background, as it does on the way there, and isn't left open for the
/// person's return.
struct AddToHomeScreenSheet: View {
    let request: AppShortcutRequest

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @State private var options: AppShortcutOptions
    /// The profile Safari offers, once the person has tapped Add.
    @State private var webClipLink: URL?
    @State private var errorMessage: String?

    init(request: AppShortcutRequest) {
        self.request = request
        _options = State(initialValue: AppShortcutOptions(app: request.app))
    }

    var body: some View {
        Group {
            if let webClipLink {
                SafariView(url: .constant(webClipLink))
            } else {
                AddToHomeScreenForm(app: request.app, style: request.style, options: $options, add: add)
            }
        }
        .onChange(of: scenePhase) {
            if scenePhase == .background && webClipLink != nil {
                dismiss()
            }
        }
        .alert(
            "lc.common.error".loc,
            isPresented: Binding<Bool>.isPresented(for: $errorMessage),
            presenting: errorMessage
        ) { _ in
            Button("lc.common.ok".loc) { }
        } message: { message in
            Text(message)
        }
    }

    private func add() {
        do {
            webClipLink = try AppShortcuts.webClipLink(for: request.app, options: options, style: request.style)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
