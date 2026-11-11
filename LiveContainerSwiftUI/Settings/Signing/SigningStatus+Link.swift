//
//  SigningStatus+Link.swift
//  LiveContainerSwiftUI
//

import Foundation

extension SigningStatus {
    var isSameTeam: Bool? {
        guard hasCertificate, let teamID, let ownTeamID else {
            return nil
        }
        return teamID == ownTeamID
    }

    /// Whether the stored certificate can sign apps, as far as is known
    /// without signing anything: it hasn't expired, Apple hasn't revoked it,
    /// and storing or checking it found nothing wrong.
    var isCertificateUsable: Bool {
        hasCertificate && !isExpired && validity != .revoked && problem == nil
    }

    var isReadyToSign: Bool {
        isCertificateUsable && isSameTeam == true
    }

}
