//
//  HomeRouter+LaunchChecks.swift
//  LiveContainerSwiftUI
//

import SwiftUI

/// The checks `start(in:)` runs when the main window opens. Each one reports
/// what it finds through `launchProblem` or `crashReport`.
extension HomeRouter {
    /// Shows the error the last app launch left, or that ryC0 stopped
    /// while signing an app, then forgets it.
    func checkLastLaunchError() {
        var errorStr = UserDefaults.standard.string(forKey: "error")
        if errorStr == nil && UserDefaults.standard.bool(forKey: "SigningInProgress") {
            errorStr = "lc.signer.crashDuringSignErr".loc
            UserDefaults.standard.removeObject(forKey: "SigningInProgress")
        }
        guard let errorStr else {
            return
        }
        UserDefaults.standard.removeObject(forKey: "error")
        crashReport = errorStr
        isShowingCrashReport = true
    }

    /// Remembers the team ryC0 is signed by. A secondary ryC0 has
    /// to be signed by the primary one's team, or it reports a mismatch.
    func checkTeamId() {
        if let certificateTeamId = UserDefaults.standard.string(forKey: "LCCertificateTeamId") {
            if sharedModel.multiLCStatus != 2 {
                return
            }
            guard let primaryLCTeamId = Bundle.main.infoDictionary?["PrimaryLiveContainerTeamId"] as? String else {
                print("Unable to find PrimaryLiveContainerTeamId")
                return
            }
            if certificateTeamId != primaryLCTeamId {
                launchProblem = "lc.settings.multiLC.teamIdMismatch".loc
            }
            return
        }

        guard let currentTeamId = LCSharedUtils.teamIdentifier() else {
            print("Failed to determine team id.")
            return
        }

        if sharedModel.multiLCStatus == 2 {
            guard let primaryLCTeamId = Bundle.main.infoDictionary?["PrimaryLiveContainerTeamId"] as? String else {
                print("Unable to find PrimaryLiveContainerTeamId")
                return
            }
            if currentTeamId != primaryLCTeamId {
                launchProblem = "lc.settings.multiLC.teamIdMismatch".loc
                return
            }
        }
        UserDefaults.standard.set(currentTeamId, forKey: "LCCertificateTeamId")
    }

    /// Records a secondary ryC0's bundle ID for the primary one, and
    /// checks once that the bundle ID in Info.plist matches the App ID
    /// ryC0 was signed with.
    func checkAndSaveBundleId() {
        if sharedModel.multiLCStatus == 2 {
            let scheme = UserDefaults.lcAppUrlScheme() ?? ""
            LCUtils.appGroupUserDefault.set(Bundle.main.bundleIdentifier, forKey: "LCBundleID.\(scheme)")
        }

        if UserDefaults.standard.bool(forKey: "LCBundleIdChecked") {
            return
        }

        let task = SecTaskCreateFromSelf(nil)
        guard let value = SecTaskCopyValueForEntitlement(task, "application-identifier" as CFString, nil),
              let appIdentifier = value.takeRetainedValue() as? String else {
            launchProblem = "Unable to determine application-identifier"
            return
        }

        guard let bundleId = Bundle.main.bundleIdentifier else {
            return
        }

        var correctBundleId = ""
        if appIdentifier.count > 11 {
            let startIndex = appIdentifier.index(appIdentifier.startIndex, offsetBy: 11)
            correctBundleId = String(appIdentifier[startIndex...])
        }

        if bundleId != correctBundleId {
            launchProblem = "lc.settings.bundleIdMismatch %@ %@".localizeWithFormat(bundleId, correctBundleId)
        }
        UserDefaults.standard.set(true, forKey: "LCBundleIdChecked")
    }


    /// Reports when ryC0 isn't signed with a development certificate,
    /// which it needs to sign and run the apps inside it.
    func checkGetTaskAllow() {
        let task = SecTaskCreateFromSelf(nil)
        guard let value = SecTaskCopyValueForEntitlement(task, "get-task-allow" as CFString, nil),
              (value.takeRetainedValue() as? NSNumber)?.boolValue ?? false else {
            launchProblem = "lc.settings.notDevCert".loc
            return
        }
    }

    /// Saves a bookmark to the Documents folder once, which the extensions use
    /// to reach the private apps.
    func checkPrivateContainerBookmark() {
        if sharedModel.multiLCStatus == 2 {
            return
        }
        if LCUtils.appGroupUserDefault.object(forKey: "LCLaunchExtensionPrivateDocBookmark") != nil {
            return
        }

        guard let bookmark = LCUtils.bookmark(for: LCPath.docPath) else {
            launchProblem = "Failed to create bookmark for Documents folder?"
            return
        }
        LCUtils.appGroupUserDefault.set(bookmark, forKey: "LCLaunchExtensionPrivateDocBookmark")
    }
}
