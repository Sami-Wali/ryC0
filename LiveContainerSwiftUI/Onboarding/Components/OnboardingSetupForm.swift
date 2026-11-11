//
//  OnboardingSetupForm.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// A step of onboarding laid out like iOS's own setup: a header on the page
/// itself, then grouped sections, so every step's header sits in the same
/// place. On iPad the header and the rows keep to one readable column, as
/// wide as the footer's buttons under them.
struct OnboardingSetupForm<Header: View, Content: View>: View {
    @ViewBuilder let header: Header
    @ViewBuilder let content: Content

    var body: some View {
        Form {
            Section {
                header
            }
            .listRowBackground(Color.clear)

            content
        }
        // A page that fits stays put, like a page of iOS's own setup.
        .scrollBounceBehavior(.basedOnSize)
        .readableContentWidth(OnboardingDesign.contentWidth)
    }
}
