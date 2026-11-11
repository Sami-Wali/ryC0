//
//  AddToHomeScreenJITSection.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Whether the icon opens the app with JIT, in Add to Home Screen's sheet. An
/// app that always opens with JIT, because it's 32-bit or Always Open with JIT
/// is on for it, shows the switch on, and says why.
struct AddToHomeScreenJITSection: View {
    @ObservedObject var app: LCAppModel
    @Binding var opensWithJIT: Bool

    var body: some View {
        let alwaysOpensWithJIT = app.uiIsJITNeeded || app.uiIs32bit
        Section {
            Toggle("ryc0.home.openWithJIT".loc, isOn: alwaysOpensWithJIT ? .constant(true) : $opensWithJIT)
                .disabled(alwaysOpensWithJIT)
        } footer: {
            Text(footerKey.loc)
        }
    }

    /// Why the icon opens the app with JIT, or what the switch does.
    private var footerKey: String {
        if app.uiIs32bit {
            "ryc0.shortcut.jitFooter32bit"
        } else if app.uiIsJITNeeded {
            "ryc0.shortcut.jitFooterAlways"
        } else {
            "ryc0.shortcut.jitFooter"
        }
    }
}
