//
//  AppHomeButtonSection.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Lets an app use the bar when the floating button would cover its content.
struct AppHomeButtonSection: View {
    /// The app whose settings show.
    @ObservedObject var model: LCAppModel

    @AppStorage(LCGuestHomeControlKey) private var homeControl = LCGuestHomeControl.bar

    var body: some View {
        Section {
            Toggle("ryc0.homeReturn.floating".loc, isOn: $model.uiShowsHomeButton)
                .disabled(homeControl != .floatingButton)
        } footer: {
            Text((homeControl == .floatingButton ? "ryc0.homeReturn.appFallback" : "ryc0.homeReturn.chooseFloating").loc)
        }
    }
}
