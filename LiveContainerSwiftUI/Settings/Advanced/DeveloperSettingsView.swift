//
//  DeveloperSettingsView.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// Settings > Advanced > Developer, which shows after tapping the version
/// under Advanced five times: LiveContainer's developer settings, the files
/// that can be copied out for debugging, and the symbol cache and FLEX.
struct DeveloperSettingsView: View {
    @AppStorage("LCLoadTweaksToSelf") private var injectToLCItself = false
    @AppStorage("LCIgnoreJITOnLaunch") private var ignoreJITOnLaunch = false
    @AppStorage("LCKeepSelectedWhenQuit") private var keepSelectedWhenQuit = false
    @AppStorage("LCWaitForDebugger") private var waitForDebugger = false
    @AppStorage("LCSharePrivateDataWithLiveProcess") private var sharePrivateDataWithLiveProcess = false
    @AppStorage("BKNoWatchdogs") private var disableLiveProcessWatchdog = false

    /// What an export wrote, while the message saying so shows.
    @State private var exportedFiles: [String]?
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                Toggle("lc.settings.injectLCItself".loc, isOn: $injectToLCItself)
            } footer: {
                Text("lc.settings.injectLCItselfDesc".loc)
            }

            Section {
                Toggle("ryc0.settings.developer.ignoreJIT".loc, isOn: $ignoreJITOnLaunch)
                Toggle("ryc0.settings.developer.keepSelected".loc, isOn: $keepSelectedWhenQuit)
                Toggle("ryc0.settings.developer.waitForDebugger".loc, isOn: $waitForDebugger)
                Toggle("ryc0.settings.developer.sharePrivateData".loc, isOn: $sharePrivateDataWithLiveProcess)
                Toggle("ryc0.settings.developer.noWatchdog".loc, isOn: $disableLiveProcessWatchdog)
            }

            Section {
                Button("ryc0.settings.developer.exportCertificate".loc, action: exportCertificate)
                Button("ryc0.settings.developer.exportDyld".loc, action: exportDyld)
                Button("ryc0.settings.developer.exportBundle".loc, action: exportMainBundle)
            } footer: {
                Text("ryc0.settings.developer.exportFooter".loc)
            }

            Section {
                Button("ryc0.settings.developer.resetSymbolOffsets".loc, action: DeveloperTools.resetSymbolOffsets)
                Button("ryc0.settings.developer.flex".loc, action: DeveloperTools.showFLEXOverlay)
                    .disabled(!DeveloperTools.isFLEXAvailable)
            }
        }
        .navigationTitle("ryc0.settings.developer".loc)
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            "lc.common.success".loc,
            isPresented: Binding<Bool>.isPresented(for: $exportedFiles),
            presenting: exportedFiles
        ) { _ in
            Button("lc.common.ok".loc) { }
        } message: { files in
            Text(exportMessage(for: files))
        }
        .alert(
            "lc.common.error".loc,
            isPresented: Binding<Bool>.isPresented(for: $errorMessage),
            presenting: errorMessage
        ) { _ in
            Button("lc.common.ok".loc) { }
        } message: { message in
            Text(message)
        }
    }

    private func exportCertificate() {
        export(with: DeveloperTools.exportCertificate)
    }

    private func exportDyld() {
        export(with: DeveloperTools.exportDyld)
    }

    private func exportMainBundle() {
        export(with: DeveloperTools.exportMainBundle)
    }

    /// Runs an export and says what it wrote, or what went wrong.
    private func export(with tool: () throws -> [String]) {
        do {
            exportedFiles = try tool()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func exportMessage(for files: [String]) -> String {
        if files.isEmpty {
            "ryc0.settings.developer.exportedNothing".loc
        } else {
            "ryc0.settings.developer.exported %@".localizeWithFormat(files.formatted())
        }
    }
}
