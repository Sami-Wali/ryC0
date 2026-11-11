//
//  OnboardingDiagnosisSheet.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The JIT-less diagnosis from Settings > Advanced, opened from Check Setup
/// when signing fails: what ryC0 holds of its certificate, app group
/// and entitlements, and what Apple says about the certificate. It's a sheet
/// with a navigation stack of its own, since its pages push with
/// NavigationLink's destination form, which onboarding's stack doesn't use.
struct OnboardingDiagnosisSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            LCJITLessDiagnoseView()
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("lc.common.done".loc, action: close)
                    }
                }
        }
    }

    private func close() {
        dismiss()
    }
}
