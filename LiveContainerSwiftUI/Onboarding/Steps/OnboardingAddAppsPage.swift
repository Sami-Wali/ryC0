//
//  OnboardingAddAppsPage.swift
//  LiveContainerSwiftUI
//

import SwiftUI

struct OnboardingAddAppsPage: View {
    @Environment(OnboardingModel.self) private var onboarding
    @Environment(SigningStatus.self) private var connection
    @Environment(OnboardingFlow.self) private var flow
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isChoosingFile = false

    var body: some View {
        let queue = onboarding.pendingInstalls

        OnboardingSetupForm {
            OnboardingHeader(systemImage: "square.and.arrow.down.fill", title: "ryc0.onboarding.apps.title".loc, message: "ryc0.onboarding.apps.message".loc)
        } content: {
            Section {
                ForEach(queue.items) { item in
                    OnboardingPendingInstallRow(item: item)
                }
            } header: {
                if !queue.items.isEmpty {
                    Text("ryc0.onboarding.apps.received".loc)
                }
            } footer: {
                Text("ryc0.onboarding.apps.footer".loc)
            }
        }
        .onboardingBottomBar {
            OnboardingFooter {
                if queue.items.isEmpty {
                    OnboardingPrimaryButton(title: "ryc0.onboarding.apps.addFromFiles".loc, action: chooseFile)
                    OnboardingSecondaryButton(title: "ryc0.onboarding.setUpLater".loc, action: skip)
                } else {
                    OnboardingPrimaryButton(title: "lc.common.continue".loc, action: continueTapped)
                    OnboardingSecondaryButton(title: "ryc0.onboarding.apps.addFromFiles".loc, action: chooseFile)
                }
            }
        }
        .animation(reduceMotion ? nil : OnboardingDesign.spring, value: queue.items.isEmpty)
        // A tap for each app that lands on the Home Screen.
        .sensoryFeedback(.success, trigger: queue.installedCount) { oldCount, newCount in
            newCount > oldCount
        }
        .betterFileImporter(
            isPresented: $isChoosingFile,
            types: [.ipa, .tipa],
            multiple: false,
            callback: filesPicked,
            onDismiss: filePickerClosed
        )
        // The steps before set up the certificate apps are signed with, so
        // the apps that were waiting install from here on.
        .onAppear(perform: queue.startInstalling)
    }

    private func chooseFile() {
        isChoosingFile = true
    }

    private func filePickerClosed() {
        isChoosingFile = false
    }

    /// Adds the IPA picked in Files, which Files copied for ryC0.
    private func filesPicked(_ urls: [URL]) {
        guard let url = urls.first else {
            return
        }
        onboarding.pendingInstalls.add(pickedFile: url)
    }

    private func continueTapped() {
        flow.advance(from: .addApps)
    }

    private func skip() {
        flow.skip(.addApps, hasCertificate: connection.hasCertificate)
    }
}
