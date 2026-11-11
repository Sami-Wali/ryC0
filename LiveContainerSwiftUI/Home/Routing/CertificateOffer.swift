//
//  CertificateOffer.swift
//  LiveContainerSwiftUI
//

import Foundation

/// A certificate sent to ryC0 that ZSign opened with its password and
/// that belongs to ryC0's own team, while the person is asked whether
/// ryC0 should sign apps with it.
struct CertificateOffer: Equatable {
    let certificate: CertificateLink
    /// The team the certificate belongs to.
    let teamID: String
    /// Whether ryC0 already has a certificate, which this one replaces.
    let replacesCurrent: Bool
    /// How the certificate reached ryC0.
    let source: CertificateSource
}
