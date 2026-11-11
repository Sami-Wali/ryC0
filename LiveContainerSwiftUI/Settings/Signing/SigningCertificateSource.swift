//
//  SigningCertificateSource.swift
//  LiveContainerSwiftUI
//

import Foundation

/// Where the certificate ryC0 signs apps with came from.
enum SigningCertificateSource: Equatable {
    /// No certificate is stored, so ryC0 can't sign apps.
    case none
    /// The person imported a .p12 of their own.
    case imported
}
