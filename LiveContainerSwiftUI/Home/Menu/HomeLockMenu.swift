//
//  HomeLockMenu.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The Face ID actions in an app's menu, named for the iPhone's Face ID,
/// Touch ID or passcode as on iOS. An unlocked app offers Require Face ID and
/// Hide and Require Face ID; a locked one offers Don't Require Face ID, and
/// hiding when it isn't hidden yet. They use LiveContainer's app lock.
struct HomeLockMenu: View {
    @ObservedObject var app: LCAppModel

    @Environment(HomeScreenModel.self) private var model

    var body: some View {
        let biometry = HomeBiometry.current
        if app.uiIsLocked {
            Button(biometry.dontRequireTitle, systemImage: biometry.systemImage, action: unlock)
            if !app.uiIsHidden {
                Button(biometry.hideTitle, systemImage: "eye.slash", action: hide)
            }
        } else {
            Menu(biometry.requireTitle, systemImage: biometry.systemImage) {
                Button(biometry.requireTitle, systemImage: biometry.systemImage, action: lock)
                Button(biometry.hideTitle, systemImage: "eye.slash", action: hide)
            }
        }
    }

    private func lock() {
        model.requireAuthentication(for: app, hiding: false)
    }

    private func hide() {
        model.requireAuthentication(for: app, hiding: true)
    }

    private func unlock() {
        model.stopRequiringAuthentication(for: app)
    }
}
