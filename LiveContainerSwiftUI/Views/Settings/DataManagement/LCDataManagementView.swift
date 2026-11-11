//
//  LCDataManagementView.swift
//  LiveContainer
//
//  Created by s s on 2025/4/18.
//

import SwiftUI

struct LCFolderPath {
    var path : URL
    var desc : String
}

struct LCDataManagementView : View {
    /// Whether an install is running, which uses temporary files.
    @Environment(AppLaunchCoordinator.self) private var coordinator
    @State var folderPaths : [LCFolderPath]
    @State var filzaInstalled = false
    @State var appeared = false
    
    @StateObject private var appFolderRemovalAlert = YesNoHelper()
    @State private var folderRemoveCount = 0
    
    @StateObject private var keyChainRemovalAlert = YesNoHelper()
    @StateObject private var tmpRemovalAlert = YesNoHelper()
    @StateObject private var cacheRemovalAlert = YesNoHelper()
    // Cleaning deletes off the main thread, so one asked for while another is
    // still deleting does nothing instead of deleting the same files at once.
    @State private var isCleaning = false


    @State var errorShow = false
    @State var errorInfo = ""
    @State var successShow = false
    @State var successInfo = ""
    
    @EnvironmentObject private var sharedModel : SharedModel
    
    init() {
        _folderPaths = State(initialValue: [
            LCFolderPath(path: LCPath.docPath, desc: "Private Container"),
            LCFolderPath(path: LCPath.lcGroupDocPath, desc: "App Group Container"),
            LCFolderPath(path: Bundle.main.bundleURL, desc: "ryC0 Bundle"),
        ])
    }
    
    var body: some View {
    
        Form {
            Section {
                if sharedModel.multiLCStatus != 2 {
                    Button {
                        moveAppGroupFolderFromPrivateToAppGroup()
                    } label: {
                        Text("lc.settings.appGroupPrivateToShare".loc)
                    }
                    Button {
                        moveAppGroupFolderFromAppGroupToPrivate()
                    } label: {
                        Text("lc.settings.appGroupShareToPrivate".loc)
                    }

                    Button {
                        Task { await moveDanglingFolders() }
                    } label: {
                        Text("lc.settings.moveDanglingFolderOut".loc)
                    }
                    Button(role:.destructive) {
                        Task { await cleanUpUnusedFolders() }
                    } label: {
                        Text("lc.settings.cleanDataFolder".loc)
                    }
                }

                Button(role:.destructive) {
                    Task { await removeKeyChain() }
                } label: {
                    Text("lc.settings.cleanKeychain".loc)
                }

                Button(role:.destructive) {
                    Task { await clearTemporaryFiles() }
                } label: {
                    Text("lc.settings.cleanTmp".loc)
                }
                // An install unpacks and signs in temporary files.
                .disabled(coordinator.isInstalling)
                
                Button(role:.destructive) {
                    Task { await clearCacheFiles() }
                } label: {
                    Text("lc.settings.cleanCaches".loc) 
                }

            }
            
            Section {
                Button {
                    Task { await clearIconCache() }
                } label: {
                    Text("lc.settings.clearIconCache".loc)
                }
            }
            
            Section {
                ForEach(folderPaths, id:\.desc) { path in
                    HStack(spacing: 10) {
                        Text(path.desc)
                        Spacer()
                        if filzaInstalled {
                            Button {
                                openInFilza(path: path.path)
                            } label: {
                                Text("Filza")
                            }
                            .buttonStyle(.bordered)
                        }
                        Button {
                            copy(text: path.path.path)
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .navigationTitle("lc.settings.dataManagement".loc)
        .navigationBarTitleDisplayMode(.inline)
        .alert("lc.common.error".loc, isPresented: $errorShow){
        } message: {
            Text(errorInfo)
        }
        .alert("lc.common.success".loc, isPresented: $successShow){
        } message: {
            Text(successInfo)
        }
        .alert("lc.settings.cleanDataFolder".loc, isPresented: $appFolderRemovalAlert.show) {
            if folderRemoveCount > 0 {
                Button(role: .destructive) {
                    appFolderRemovalAlert.close(result: true)
                } label: {
                    Text("lc.common.delete".loc)
                }
            }

            Button("lc.common.cancel".loc, role: .cancel) {
                appFolderRemovalAlert.close(result: false)
            }
        } message: {
            if folderRemoveCount > 0 {
                Text("lc.settings.cleanDataFolderConfirm %lld".localizeWithFormat(folderRemoveCount))
            } else {
                Text("lc.settings.noDataFolderToClean".loc)
            }

        }
        .alert("lc.settings.cleanKeychain".loc, isPresented: $keyChainRemovalAlert.show) {
            Button(role: .destructive) {
                keyChainRemovalAlert.close(result: true)
            } label: {
                Text("lc.common.delete".loc)
            }

            Button("lc.common.cancel".loc, role: .cancel) {
                keyChainRemovalAlert.close(result: false)
            }
        } message: {
            Text("lc.settings.cleanKeychainDesc".loc)
        }
        .alert("lc.settings.cleanTmp".loc, isPresented: $tmpRemovalAlert.show) {
            Button(role: .destructive) {
                tmpRemovalAlert.close(result: true)
            } label: {
                Text("lc.common.delete".loc)
            }

            Button("lc.common.cancel".loc, role: .cancel) {
                tmpRemovalAlert.close(result: false)
            }
        } message: {
            Text("lc.settings.cleanTmpConfirm".loc)
        }
        .alert("lc.settings.cleanCaches".loc, isPresented: $cacheRemovalAlert.show) {
    Button(role: .destructive) {
        cacheRemovalAlert.close(result: true)
    } label: {
        Text("lc.common.delete".loc)
    }

    Button("lc.common.cancel".loc, role: .cancel) {
        cacheRemovalAlert.close(result: false)
    }
} message: {
    Text("lc.settings.cleanCacheConfirm".loc) 
}

        .onAppear {
            onAppearFunc()
        }
    }
    
    func onAppearFunc() {
        if !appeared {
            for app in sharedModel.apps {
                if app.appInfo.bundleIdentifier() == "com.tigisoftware.Filza" {
                    filzaInstalled = true
                    break
                }
            }
            appeared = true
        }
    }
    
    func cleanUpUnusedFolders() async {
        guard !isCleaning else {
            return
        }

        // The containers in memory, which every change to an app's containers
        // saves. `appInfo.containers` would make each one again, resolving its
        // bookmark and reading its plist.
        var folderNameToAppDict : [String:LCAppModel] = [:]
        for app in sharedModel.apps {
            for container in app.uiContainers {
                folderNameToAppDict[container.folderName] = app;
            }
        }
        for app in sharedModel.hiddenApps {
            for container in app.uiContainers {
                folderNameToAppDict[container.folderName] = app;
            }
        }

        // A folder can be gone already, such as a removed container's, and a
        // name can be listed twice. Neither is counted or deleted.
        let fm = FileManager()
        var foldersToDelete : [String]  = []
        var goneFolders : Set<String> = []
        for appDataFolderName in sharedModel.appDataFolderNames where folderNameToAppDict[appDataFolderName] == nil {
            if !fm.fileExists(atPath: LCPath.dataPath.appendingPathComponent(appDataFolderName).path) {
                goneFolders.insert(appDataFolderName)
            } else if !foldersToDelete.contains(appDataFolderName) {
                foldersToDelete.append(appDataFolderName)
            }
        }
        sharedModel.appDataFolderNames.removeAll(where: { s in
            return goneFolders.contains(s)
        })
        folderRemoveCount = foldersToDelete.count

        guard let result = await appFolderRemovalAlert.open(), result else {
            return
        }
        isCleaning = true
        defer { isCleaning = false }
        // Data folders can hold gigabytes, so they're deleted off the main
        // thread. One that can't be deleted doesn't stop the others, and the
        // first error is shown once they're done.
        let (deletedFolders, failure) = await Task.detached(priority: .userInitiated) { [foldersToDelete] () -> ([String], Error?) in
            let fm = FileManager()
            var deletedFolders: [String] = []
            var failure: Error? = nil
            for folder in foldersToDelete {
                do {
                    try fm.removeItem(at: LCPath.dataPath.appendingPathComponent(folder))
                } catch {
                    if failure == nil {
                        failure = error
                    }
                    continue
                }
                LCUtils.removeAppKeychain(dataUUID: folder)
                deletedFolders.append(folder)
            }
            return (deletedFolders, failure)
        }.value
        sharedModel.appDataFolderNames.removeAll(where: { s in
            return deletedFolders.contains(s)
        })
        if let failure {
            errorInfo = failure.localizedDescription
            errorShow = true
        }

    }
    
    func removeKeyChain() async {
        guard let result = await keyChainRemovalAlert.open(), result else {
            return
        }
        
        [kSecClassGenericPassword, kSecClassInternetPassword, kSecClassCertificate, kSecClassKey, kSecClassIdentity].forEach {
          let status = SecItemDelete([
            kSecClass: $0,
            kSecAttrSynchronizable: kSecAttrSynchronizableAny
          ] as CFDictionary)
          if status != errSecSuccess && status != errSecItemNotFound {
              //Error while removing class $0
              errorInfo = status.description
              errorShow = true
          }
        }
    }

    func clearTemporaryFiles() async {
        guard !isCleaning, let result = await tmpRemovalAlert.open(), result else {
            return
        }
        isCleaning = true
        defer { isCleaning = false }

        let tmpDirectory = FileManager.default.temporaryDirectory

        do {
            // Deleting many files takes a while, so it runs off the main thread.
            let hadItems = try await Task.detached(priority: .userInitiated) {
                let fm = FileManager()
                let tmpItems = try fm.contentsOfDirectory(at: tmpDirectory, includingPropertiesForKeys: nil)
                for item in tmpItems {
                    try fm.removeItem(at: item)
                }
                return !tmpItems.isEmpty
            }.value

            successInfo = hadItems ? "lc.settings.cleanTmpComplete".loc : "lc.settings.noTmpToClean".loc
            successShow = true
        } catch {
            errorInfo = error.localizedDescription
            errorShow = true
        }
    }

    func clearCacheFiles() async {
        guard !isCleaning, let result = await cacheRemovalAlert.open(), result else {
            return
        }
        isCleaning = true
        defer { isCleaning = false }

        let allApps = sharedModel.apps + sharedModel.hiddenApps
        // Every container's caches, then ryC0's own.
        let cacheFolders = allApps.flatMap { app in
            app.uiContainers.map { container in
                container.containerURL.appendingPathComponent("Library/Caches")
            }
        } + FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).prefix(1)

        do {
            // Caches can hold gigabytes, so they're deleted off the main thread.
            let cleanedCount = try await Task.detached(priority: .userInitiated) {
                let fm = FileManager()
                var cleanedCount = 0
                for cacheFolder in cacheFolders where fm.fileExists(atPath: cacheFolder.path) {
                    let cacheItems = try fm.contentsOfDirectory(at: cacheFolder, includingPropertiesForKeys: nil)
                    for item in cacheItems {
                        try fm.removeItem(at: item)
                    }
                    cleanedCount += 1
                }
                return cleanedCount
            }.value

            if cleanedCount == 0 {
                successInfo = "lc.settings.noCacheToClean".loc
            } else {
                successInfo = "lc.settings.cleanCacheComplete".loc
            }
            successShow = true
        } catch {
            errorInfo = error.localizedDescription
            errorShow = true
        }
    }


    func moveDanglingFolders() async {
        let fm = FileManager()
        do {
            var appDataFoldersInUse : Set<String> = Set();
            var tweakFoldersInUse : Set<String> = Set();
            for app in sharedModel.apps {
                if !app.appInfo.isShared {
                    continue
                }
                for container in app.uiContainers {
                    appDataFoldersInUse.update(with: container.folderName);
                }


                if let folder = app.appInfo.tweakFolder {
                    tweakFoldersInUse.update(with: folder);
                }

            }
            
            for app in sharedModel.hiddenApps {
                if !app.appInfo.isShared {
                    continue
                }
                for container in app.uiContainers {
                    appDataFoldersInUse.update(with: container.folderName);
                }
                if let folder = app.appInfo.tweakFolder {
                    tweakFoldersInUse.update(with: folder);
                }

            }
            
            var movedDataFolderCount = 0
            let sharedDataFolders = try fm.contentsOfDirectory(atPath: LCPath.lcGroupDataPath.path)
            for sharedDataFolder in sharedDataFolders {
                if appDataFoldersInUse.contains(sharedDataFolder) {
                    continue
                }
                let movedDataURL = LCPath.dataPath.appendingPathComponent(sharedDataFolder)
                try fm.moveItem(at: LCPath.lcGroupDataPath.appendingPathComponent(sharedDataFolder), to: movedDataURL)
                movedDataFolderCount += 1
                // Added the way launch lists the data folders, so it shows
                // before ryC0 opens again.
                var isDataDirectory : ObjCBool = false
                if fm.fileExists(atPath: movedDataURL.path, isDirectory: &isDataDirectory), isDataDirectory.boolValue, !sharedModel.appDataFolderNames.contains(sharedDataFolder) {
                    sharedModel.appDataFolderNames.append(sharedDataFolder)
                }
            }
            
            var movedTweakFolderCount = 0
            let sharedTweakFolders = try fm.contentsOfDirectory(atPath: LCPath.lcGroupTweakPath.path)
            for tweakFolderInUse in sharedTweakFolders {
                if tweakFoldersInUse.contains(tweakFolderInUse) || tweakFolderInUse == "TweakLoader.dylib" {
                    continue
                }
                let movedTweakURL = LCPath.tweakPath.appendingPathComponent(tweakFolderInUse)
                try fm.moveItem(at: LCPath.lcGroupTweakPath.appendingPathComponent(tweakFolderInUse), to: movedTweakURL)
                movedTweakFolderCount += 1
                // Added the way launch lists the tweak folders: folders only,
                // since global tweaks are files here, named without
                // ".disabled", and each once.
                var isTweakDirectory : ObjCBool = false
                let tweakFolderName = tweakFolderInUse.hasSuffix(".disabled") ? String(tweakFolderInUse.dropLast(".disabled".count)) : tweakFolderInUse
                if fm.fileExists(atPath: movedTweakURL.path, isDirectory: &isTweakDirectory), isTweakDirectory.boolValue, !sharedModel.tweakFolderNames.contains(tweakFolderName) {
                    sharedModel.tweakFolderNames.append(tweakFolderName)
                }
            }
            successInfo = "lc.settings.moveDanglingFolderComplete %lld %lld".localizeWithFormat(movedDataFolderCount,movedTweakFolderCount)
            successShow = true
            
        } catch {
            errorInfo = error.localizedDescription
            errorShow = true
        }
    }
    
    func moveAppGroupFolderFromAppGroupToPrivate() {
        let fm = FileManager()
        do {
            if !fm.fileExists(atPath: LCPath.appGroupPath.path) {
                try fm.createDirectory(atPath: LCPath.appGroupPath.path, withIntermediateDirectories: true)
            }
            if !fm.fileExists(atPath: LCPath.lcGroupAppGroupPath.path) {
                try fm.createDirectory(atPath: LCPath.lcGroupAppGroupPath.path, withIntermediateDirectories: true)
            }
            
            let privateFolderContents = try fm.contentsOfDirectory(at: LCPath.appGroupPath, includingPropertiesForKeys: nil)
            let sharedFolderContents = try fm.contentsOfDirectory(at: LCPath.lcGroupAppGroupPath, includingPropertiesForKeys: nil)
            if privateFolderContents.count > 0 {
                errorInfo = "lc.settings.appGroupExistPrivate".loc
                errorShow = true
                return
            }
            for file in sharedFolderContents {
                try fm.moveItem(at: file, to: LCPath.appGroupPath.appendingPathComponent(file.lastPathComponent))
            }
            successInfo = "lc.settings.appGroup.moveSuccess".loc
            successShow = true
            
        } catch {
            errorInfo = error.localizedDescription
            errorShow = true
        }
    }
    
    func moveAppGroupFolderFromPrivateToAppGroup() {
        let fm = FileManager()
        do {
            if !fm.fileExists(atPath: LCPath.appGroupPath.path) {
                try fm.createDirectory(atPath: LCPath.appGroupPath.path, withIntermediateDirectories: true)
            }
            if !fm.fileExists(atPath: LCPath.lcGroupAppGroupPath.path) {
                try fm.createDirectory(atPath: LCPath.lcGroupAppGroupPath.path, withIntermediateDirectories: true)
            }
            
            let privateFolderContents = try fm.contentsOfDirectory(at: LCPath.appGroupPath, includingPropertiesForKeys: nil)
            let sharedFolderContents = try fm.contentsOfDirectory(at: LCPath.lcGroupAppGroupPath, includingPropertiesForKeys: nil)
            if sharedFolderContents.count > 0 {
                errorInfo = "lc.settings.appGroupExist Shared".loc
                errorShow = true
                return
            }
            for file in privateFolderContents {
                try fm.moveItem(at: file, to: LCPath.lcGroupAppGroupPath.appendingPathComponent(file.lastPathComponent))
            }
            successInfo = "lc.settings.appGroup.moveSuccess".loc
            successShow = true
            
        } catch {
            errorInfo = error.localizedDescription
            errorShow = true
        }
    }
    
    func copy(text: String) {
        UIPasteboard.general.string = text
    }
    
    func openInFilza(path: URL) {
        let launchURLStr = "filza://view\(path.path)/."
        Task {
            do {
                try await sharedModel.apps.first(where: { app in
                    return app.appInfo.bundleIdentifier() == "com.tigisoftware.Filza"
                })?.runApp(urlStr: launchURLStr)
            } catch {
                errorInfo = error.localizedDescription
                errorShow = true
            }
        }
    }
    
    func clearIconCache() async {
        for app in sharedModel.apps {
            app.appInfo.clearIconCache()
            // The views showing the app draw its icons again.
            app.iconGeneration += 1
        }
    }

}
