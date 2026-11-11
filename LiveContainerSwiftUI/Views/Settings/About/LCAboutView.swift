//
//  LCAboutView.swift
//  LiveContainerSwiftUI
//
//  Settings > About ryC0: who made LiveContainer, which ryC0 is
//  built on, where ryC0's source is, the notices the AGPL asks a
//  modified version to show, and the license texts that come with the app.
//

import SwiftUI

struct LCAboutView: View {
    var body: some View {
        Form {
            Section {
                LCAboutHeader()
            }
            .listRowBackground(Color.clear)

            Section {
                LCAboutLinkRow(title: "zContainer", detail: LCAboutLinks.display(LCAboutLinks.upstream), url: LCAboutLinks.upstream)
                LCAboutLinkRow(title: "LiveContainer", detail: LCAboutLinks.display(LCAboutLinks.liveContainer),
                               url: LCAboutLinks.liveContainer)
                LCAboutLinkRow(title: "Duy Tran (khanhduytran0)", detail: "lc.about.creator".loc,
                               url: LCAboutLinks.khanhduytran0)
                LCAboutLinkRow(title: "Huge_Black", detail: "lc.about.swiftUI".loc, url: LCAboutLinks.hugeBlack)
                LCAboutLinkRow(title: "lc.about.contributors".loc, detail: nil,
                               url: LCAboutLinks.liveContainerContributors)
            } header: {
                Text("lc.about.basedOn".loc)
            } footer: {
                Text("lc.about.modifiedNotice".loc)
            }

            Section {
                if let source = LCAboutLinks.source {
                    LCAboutLinkRow(title: "lc.about.sourceCode".loc, detail: LCAboutLinks.display(source), url: source)
                }
                NavigationLink {
                    LCLicenseView(license: .ryC0)
                } label: {
                    LCAboutRowLabel(title: LCLicense.ryC0.licenseName, detail: "lc.about.licenseDetail".loc)
                }
                NavigationLink {
                    LCLicensesView()
                } label: {
                    LCAboutRowLabel(title: "lc.about.licenses".loc, detail: "lc.about.licensesDetail".loc)
                }
            } header: {
                Text("lc.about.legal".loc)
            } footer: {
                Text("lc.about.licenseNotice".loc)
            }

            Section {
                ForEach(LCAcknowledgement.all) { item in
                    LCAboutLinkRow(title: item.name, detail: item.detail, url: item.url)
                }
            } header: {
                Text("lc.about.acknowledgements".loc)
            }
        }
        .navigationTitle("lc.about.title".loc)
        .navigationBarTitleDisplayMode(.inline)
    }
}
