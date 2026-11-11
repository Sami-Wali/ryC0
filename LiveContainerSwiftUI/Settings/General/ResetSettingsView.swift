//
//  ResetSettingsView.swift
//  LiveContainerSwiftUI
//

import SwiftUI
import UserNotifications

/// Settings > General > Reset, like the Reset choices of the Settings app:
/// putting the Home Screen back the way it first was, and clearing the
/// notifications the apps inside ryC0 sent. The tools that delete app
/// data are in Data Management.
struct ResetSettingsView: View {
    @Environment(HomeScreenModel.self) private var home

    @State private var isConfirmingHomeScreenReset = false
    /// Goes up by one after each reset, for the haptic that confirms it.
    @State private var resetCount = 0

    var body: some View {
        List {
            Section {
                Button("ryc0.settings.reset.homeScreen".loc, action: confirmHomeScreenReset)
                    .confirmationDialog(
                        "ryc0.settings.reset.homeScreenTitle".loc,
                        isPresented: $isConfirmingHomeScreenReset,
                        titleVisibility: .visible
                    ) {
                        Button("ryc0.settings.reset.homeScreenConfirm".loc, role: .destructive, action: resetHomeScreen)
                    } message: {
                        Text("ryc0.settings.reset.homeScreenMessage".loc)
                    }
            }

            Section {
                Button("lc.settings.clearNotifications".loc, action: clearNotifications)
            } footer: {
                Text("ryc0.settings.reset.notificationsFooter".loc)
            }
        }
        .navigationTitle("lc.common.reset".loc)
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.success, trigger: resetCount)
    }

    private func confirmHomeScreenReset() {
        isConfirmingHomeScreenReset = true
    }

    private func resetHomeScreen() {
        home.resetLayout()
        resetCount += 1
    }

    /// Removes the notifications delivered and waiting to be delivered, and
    /// the badge on ryC0's icon, which the apps inside set.
    private func clearNotifications() {
        LCSharedUtils.resetGuestNotifications()
        let center = UNUserNotificationCenter.current()
        center.removeAllDeliveredNotifications()
        center.removeAllPendingNotificationRequests()
        center.setBadgeCount(0)
        resetCount += 1
    }
}
