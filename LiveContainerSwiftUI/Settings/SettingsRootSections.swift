//
//  SettingsRootSections.swift
//  LiveContainerSwiftUI
//

import SwiftUI

struct SettingsRootSections: View {
    @Environment(SigningStatus.self) private var connection
    @Environment(OnboardingModel.self) private var onboarding

    var body: some View {
        Section {
            SettingsPageLink(page: .signing) {
                SigningCard()
            }
        }

        if let attention = connection.attention {
            Section {
                if attention == .notSetUp {
                    Button(action: onboarding.present) {
                        SigningAttentionRow(attention: attention, showsChevron: true)
                    }
                } else {
                    SettingsPageLink(page: .attention) {
                        SigningAttentionRow(attention: attention)
                    }
                }
            }
        }

        Section {
            SettingsPageLink(page: .general) {
                SettingsRow(title: "ryc0.settings.general".loc, systemImage: "gear", color: .gray)
            }

            SettingsPageLink(page: .appearance) {
                SettingsRow(title: "ryc0.settings.appearance".loc, systemImage: "circle.lefthalf.filled", color: .blue)
            }

            SettingsPageLink(page: .wallpaper) {
                SettingsRow(title: "ryc0.settings.wallpaper".loc, systemImage: "camera.macro", color: .cyan)
            }
        }

        Section {
            SettingsPageLink(page: .apps) {
                SettingsRow(title: "lc.tabView.apps".loc, systemImage: "square.grid.2x2.fill", color: .indigo)
            }

            SettingsAddAppRow()
        }

        Section {
            SettingsPageLink(page: .advanced) {
                SettingsRow(title: "ryc0.settings.advanced".loc, systemImage: "hammer.fill", color: .gray)
            }
        }
    }
}
