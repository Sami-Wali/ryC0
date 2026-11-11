//
//  AddToHomeScreenHeader.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The top of Add to Home Screen's sheet, as in Safari's: the icon the Home
/// Screen will show, with ryC0's frame when Frame Shortcut Icons is on,
/// beside the name under it, which the person can change, and the app it
/// opens.
struct AddToHomeScreenHeader: View {
    let app: LCAppModel
    /// The icon's style, as ryC0's Home Screen shows it.
    let style: GeneratedIconStyle
    @Binding var name: String

    @ScaledMetric(relativeTo: .body) private var iconSize = SettingsDesign.shortcutIconSize
    /// The icon the web clip gets, drawn once the sheet is up.
    @State private var icon: UIImage?

    var body: some View {
        let appName = app.appInfo.displayName() ?? ""
        HStack(spacing: SettingsDesign.shortcutSpacing) {
            Image(uiImage: icon ?? UIImage())
                .resizable()
                .scaledToFill()
                .frame(width: iconSize, height: iconSize)
                .clipShape(.rect(cornerRadius: iconSize * SettingsDesign.iconCornerRatio))
                .overlay {
                    RoundedRectangle(cornerRadius: iconSize * SettingsDesign.iconCornerRatio)
                        .strokeBorder(.separator, lineWidth: SettingsDesign.iconOutlineWidth)
                }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: SettingsDesign.subtitleSpacing) {
                TextField("ryc0.shortcut.name".loc, text: $name, prompt: Text(appName))
                    .submitLabel(.done)
                Text("ryc0.shortcut.opensIn %@".localizeWithFormat(appName))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear(perform: drawIcon)
    }

    private func drawIcon() {
        icon = app.appInfo.generateLiveContainerWrappedIcon(with: style)
    }
}
