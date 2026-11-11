//
//  LCLicensesView.swift
//  LiveContainerSwiftUI
//
//  Settings > About ryC0 > Licenses: the license of each open source
//  project inside the app, each opening its full text.
//

import SwiftUI

struct LCLicensesView: View {
    var body: some View {
        Form {
            Section {
                ForEach(LCLicense.thirdParty) { license in
                    NavigationLink {
                        LCLicenseView(license: license)
                    } label: {
                        LCAboutRowLabel(title: license.name, detail: license.licenseName)
                    }
                }
            } footer: {
                Text("lc.about.licensesFooter".loc)
            }
        }
        .navigationTitle("lc.about.licenses".loc)
        .navigationBarTitleDisplayMode(.inline)
    }
}
