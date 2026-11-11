//
//  SigningCheckResult.swift
//  LiveContainerSwiftUI
//

import Foundation

/// How one part of the setup stands after Check Setup looked at it.
enum SigningCheckResult: Equatable {
    /// Check Setup hasn't looked at it yet.
    case notChecked
    /// Check Setup is looking at it now.
    case checking
    /// It works.
    case passed
    /// An optional part is missing. ryC0 works without it.
    case missing
    /// It doesn't work, for this reason.
    case failed(String)

    /// Why it failed, or nil when it didn't.
    var failure: String? {
        if case .failed(let reason) = self {
            reason
        } else {
            nil
        }
    }
}
