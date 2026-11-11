//
//  SigningAttention.swift
//  LiveContainerSwiftUI
//

import Foundation

enum SigningAttention: Equatable {
    /// No certificate is stored.
    case notSetUp
    /// Storing or checking the certificate went wrong, or Check Setup found
    /// that signing fails.
    case problem
    /// The certificate has expired.
    case expired
    /// Apple revoked the certificate.
    case revoked

    /// The row's text.
    var title: String {
        switch self {
        case .notSetUp:
            "ryc0.settings.attention.notSetUp".loc
        case .problem:
            "ryc0.settings.attention.problem".loc
        case .expired:
            "ryc0.settings.attention.expired".loc
        case .revoked:
            "ryc0.settings.attention.revoked".loc
        }
    }
}
