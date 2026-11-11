//
//  LockedCertificate.swift
//  LiveContainerSwiftUI
//

import Foundation

/// A .p12 file ryC0 was asked to open, while the person is asked for
/// the password that opens it.
struct LockedCertificate: Equatable {
    /// The certificate and its private key, as a .p12.
    let data: Data
    /// Whether the last password typed didn't open it, so the question says so.
    let isRetry: Bool
}
