//
//  SigningCertificateValidity.swift
//  LiveContainerSwiftUI
//

import Foundation

/// What Apple says about the certificate, asked over OCSP the way the
/// JIT-less diagnosis asks.
enum SigningCertificateValidity: Equatable {
    /// Not asked yet.
    case unknown
    /// Waiting for Apple's answer.
    case checking
    /// Apple says the certificate is good.
    case valid
    /// Apple revoked the certificate, so apps signed with it won't open.
    case revoked
    /// Apple couldn't be asked or gave no clear answer, for this reason.
    case unavailable(String)
}
