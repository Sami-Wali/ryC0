//
//  OnScreenKeyboard.swift
//  LiveContainerSwiftUI
//

import Combine
import Foundation
import UIKit

/// Tells from UIKit's keyboard notifications whether an on-screen keyboard
/// covers the bottom of the screen, which is when the Home button steps aside
/// on iPad. With a hardware keyboard, iPadOS sends the same notifications for
/// the small bar of shortcuts it shows instead, which covers nothing, so only
/// a keyboard taller than `minimumHeight` counts. The iPhone goes on following
/// the notifications that the keyboard shows and hides.
@MainActor
enum OnScreenKeyboard {
    /// The height a keyboard needs to count as the on-screen keyboard. The
    /// shortcuts bar shown with a hardware keyboard is well under it.
    static let minimumHeight = 150.0

    /// Every change to the keyboard's frame, and the keyboard going away.
    static var changes: Publishers.Merge<NotificationCenter.Publisher, NotificationCenter.Publisher> {
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)
            .merge(with: NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification))
    }

    /// Whether an on-screen keyboard is up once the change a notification
    /// from `changes` announces is over.
    static func isUp(after notification: Notification) -> Bool {
        guard notification.name != UIResponder.keyboardWillHideNotification,
              let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              frame.height > minimumHeight else {
            return false
        }
        // On its way out the keyboard ends below the screen, which the
        // notification names as its object.
        guard let screen = notification.object as? UIScreen else {
            return true
        }
        return frame.intersects(screen.bounds)
    }
}
