//
//  OnboardingFeature.swift
//  LiveContainerSwiftUI
//

import Foundation

/// What ryC0 does, in the order the welcome screen lists it.
enum OnboardingFeature: Int, CaseIterable, Identifiable {
    case oneSlot
    case certificateSigning
    case homeScreen

    var id: Self { self }

    /// The SF Symbol on the feature's icon.
    var systemImage: String {
        switch self {
        case .oneSlot: "square.grid.2x2.fill"
        case .certificateSigning: "bolt.fill"
        case .homeScreen: String.homeScreenSymbol
        }
    }

    var title: String {
        switch self {
        case .oneSlot: "ryc0.onboarding.feature.oneSlot".loc
        case .certificateSigning: "ryc0.onboarding.feature.certificateSigning".loc
        case .homeScreen: "ryc0.onboarding.feature.homeScreen".loc
        }
    }

    var message: String {
        switch self {
        case .oneSlot: "ryc0.onboarding.feature.oneSlotDetail".loc
        case .certificateSigning: "ryc0.onboarding.feature.certificateSigningDetail".loc
        case .homeScreen: "ryc0.onboarding.feature.homeScreenDetail".deviceLoc
        }
    }
}
