//
//  LCAppModel+NewContainer.swift
//  LiveContainerSwiftUI
//

import Foundation

extension LCAppModel {
    /// Makes a new, empty container for this app and selects it, so the next
    /// launch uses it, as Open in New Container does. The container is named
    /// "Container 2", "Container 3" and so on, gets a keychain group no other
    /// container of the app uses, and becomes the default when the app had
    /// none. Throws when the folder can't be made or every keychain group is
    /// taken.
    @MainActor
    @discardableResult
    func makeNewContainer(sharedModel: SharedModel) throws -> LCContainer {
        let bundleIdentifier: String = appInfo.bundleIdentifier()
        var freeKeychainGroups = Set(0..<SharedModel.keychainAccessGroupCount)
        for container in uiContainers {
            freeKeychainGroups.remove(container.keychainGroupId)
        }
        guard let keychainGroup = freeKeychainGroups.randomElement() else {
            throw "lc.container.notEnoughKeychainGroup".loc
        }

        let folderName = UUID().uuidString
        let dataFolder = uiIsShared ? LCPath.lcGroupDataPath : LCPath.dataPath
        try FileManager.default.createDirectory(at: dataFolder.appending(path: folderName), withIntermediateDirectories: true)
        // Only private data folders are listed, and a shared app's is in the
        // app group.
        if !uiIsShared {
            sharedModel.appDataFolderNames.append(folderName)
        }

        let name = "ryc0.home.containerName %lld".localizeWithFormat(uiContainers.count + 1)
        let container = LCContainer(folderName: folderName, name: name, isShared: uiIsShared)
        uiContainers.append(container)
        if uiDefaultDataFolder == nil {
            uiDefaultDataFolder = folderName
            appInfo.dataUUID = folderName
        }
        appInfo.containers = uiContainers
        container.makeLCContainerInfoPlist(appIdentifier: bundleIdentifier, keychainGroupId: keychainGroup)
        uiSelectedContainer = container
        return container
    }
}
