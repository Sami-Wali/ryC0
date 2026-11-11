//
//  Shared.swift
//  LiveContainerSwiftUI
//
//  Created by s s on 2024/8/22.
//

import SwiftUI
import UniformTypeIdentifiers
import SafariServices
import Security
import Combine

struct LCPath {
    public static let docPath = {
        let fm = FileManager()
        return fm.urls(for: .documentDirectory, in: .userDomainMask).last!
    }()
    public static let bundlePath = docPath.appendingPathComponent("Applications")
    public static let dataPath = docPath.appendingPathComponent("Data/Application")
    public static let appGroupPath = docPath.appendingPathComponent("Data/AppGroup")
    public static let tweakPath = docPath.appendingPathComponent("Tweaks")
    
    public static let lcGroupDocPath = {
        // Without an app group, shared apps live with the private ones.
        if let appGroupPathUrl = LCSharedUtils.appGroupPath() {
            return appGroupPathUrl.appendingPathComponent("LiveContainer")
        } else {
            return docPath
        }
    }()
    public static let lcGroupBundlePath = lcGroupDocPath.appendingPathComponent("Applications")
    public static let lcGroupDataPath = lcGroupDocPath.appendingPathComponent("Data/Application")
    public static let lcGroupAppGroupPath = lcGroupDocPath.appendingPathComponent("Data/AppGroup")
    public static let lcGroupTweakPath = lcGroupDocPath.appendingPathComponent("Tweaks")
    
    public static func ensureAppGroupPaths() throws {
        let fm = FileManager()
        if !fm.fileExists(atPath: LCPath.lcGroupBundlePath.path) {
            try fm.createDirectory(at: LCPath.lcGroupBundlePath, withIntermediateDirectories: true)
        }
        if !fm.fileExists(atPath: LCPath.lcGroupDataPath.path) {
            try fm.createDirectory(at: LCPath.lcGroupDataPath, withIntermediateDirectories: true)
        }
        if !fm.fileExists(atPath: LCPath.lcGroupTweakPath.path) {
            try fm.createDirectory(at: LCPath.lcGroupTweakPath, withIntermediateDirectories: true)
        }
    }
}

class SharedModel: ObservableObject {
    @Published var isHiddenAppUnlocked = false
    @Published var developerMode = false
    // 0 = current liveContainer is the primary one,
    // 2 = current liveContainer is not the primary one
    @Published var multiLCStatus = 0
    @Published var isJITModalOpen = false

    @Published var appDataFolderNames: [String] = []
    @Published var tweakFolderNames: [String] = []
    
    @Published var apps : [LCAppModel] = []
    @Published var arm32EmuApps : [LCAppModel] = []
    @Published var hiddenApps : [LCAppModel] = []
    
    @Published var pidCallback : ((NSNumber, Error?) -> Void)? = nil
    
    static let isPhone: Bool = {
        UIDevice.current.userInterfaceIdiom == .phone
    }()
    
    static let isLiquidGlassEnabled = {
        if #available(iOS 19.0, *), (dyld_get_program_sdk_version() >= 0x1a0000 || UserDefaults.standard.bool(forKey: "com.apple.SwiftUI.IgnoreSolariumLinkedOnCheck")) {
            if let compatibilityEnabled = Bundle.main.infoDictionary?["UIDesignRequiresCompatibility"] as? Bool, compatibilityEnabled {
                return false
            }
            
            return true
        }
        return false
    }()
    
    var mainWindowOpened = false
    
    public static let keychainAccessGroupCount = 128
    
    func updateMultiLCStatus() {
        if LCUtils.appUrlScheme()?.lowercased() != LCSharedUtils.hostAppUrlScheme().lowercased() {
            multiLCStatus = 2
        } else {
            multiLCStatus = 0
        }
    }
    
    init() {
        updateMultiLCStatus()
    }
}

class DataManager {
    static let shared = DataManager()
    let model = SharedModel()
}

class AlertHelper<T> : ObservableObject {
    @Published var show = false
    private var result : T?
    private var c : UnsafeContinuation<Void, Never>? = nil
    
    func open() async -> T? {
        await withUnsafeContinuation { c in
            self.c = c
            Task { await MainActor.run {
                self.show = true
            }}
        }
        return self.result
    }
    
    func close(result: T?) {
        if let c {
            self.result = result
            c.resume()
            self.c = nil
        }
        DispatchQueue.main.async {
            self.show = false
        }

    }
}

typealias YesNoHelper = AlertHelper<Bool>

class InputHelper : AlertHelper<String> {
    @Published var initVal = ""
    
    func open(initVal: String) async -> String? {
        self.initVal = initVal
        return await super.open()
    }
    
    override func open() async -> String? {
        self.initVal = ""
        return await super.open()
    }
}

extension String: @retroactive Error {}
extension String: @retroactive LocalizedError {
    public var errorDescription: String? { return self }
        
    private static var enBundle : Bundle? = {
        let language = "en"
        let path = Bundle.main.path(forResource:language, ofType: "lproj")
        let bundle = Bundle(path: path!)
        return bundle
    }()
    
    var loc: String {
        let message = NSLocalizedString(self, comment: "")
        if message != self {
            return message
        }

        if let forcedString = String.enBundle?.localizedString(forKey: self, value: nil, table: nil){
            return forcedString
        }else {
            return self
        }
    }
    
    func localizeWithFormat(_ arguments: CVarArg...) -> String{
        String.localizedStringWithFormat(self.loc, arguments)
    }
    
    func sanitizeNonACSII() -> String  {
        filter { $0.isASCII }
    }
}

extension UTType {
    static let ipa = UTType(filenameExtension: "ipa")!
    static let tipa = UTType(filenameExtension: "tipa")!
    static let dylib = UTType(filenameExtension: "dylib")!
    static let lcFramework = UTType(filenameExtension: "framework", conformingTo: .package)!
    static let p12 = UTType(filenameExtension: "p12")!
}

struct SiteAssociationDetailItem : Codable {
    var appID: String?
    var appIDs: [String]?
    
    func getBundleIds() -> [String] {
        var ans : [String] = []
        // get rid of developer id
        if let appID = appID, appID.count > 11 {
            let index = appID.index(appID.startIndex, offsetBy: 11)
            let modifiedString = String(appID[index...])
            ans.append(modifiedString)
        }
        if let appIDs = appIDs {
            for appID in appIDs {
                if appID.count > 11 {
                    let index = appID.index(appID.startIndex, offsetBy: 11)
                    let modifiedString = String(appID[index...])
                    ans.append(modifiedString)
                }
            }
        }
        return ans
    }
}

struct AppLinks : Codable {
    var details : [SiteAssociationDetailItem]?
}

struct SiteAssociation : Codable {
    var applinks: AppLinks?
}


struct JITStreamerEBMountResponse : Codable {
    let ok: Bool
    let mounting: Bool
    let error: String?
}




enum BatchMoveError: LocalizedError {
    case emptySource(URL)
    case sourceDoesNotExist(URL)
    case sourceIsNotReachable(URL, underlying: Error)
    case sourceParentIsNotWritable(URL)
    case destinationAlreadyExists(URL)
    case destinationParentDoesNotExist(URL)
    case destinationParentIsNotDirectory(URL)
    case destinationParentIsNotWritable(URL)
    case duplicateSource(URL)
    case duplicateDestination(URL)
    case sourceEqualsDestination(URL)
    case moveWouldPlaceDirectoryInsideItself(source: URL, destination: URL)
    case moveFailed(source: URL, destination: URL, underlying: Error)

    var errorDescription: String? {
        switch self {
        case .emptySource(let url):
            return "Source URL is invalid: \(url)"
        case .sourceDoesNotExist(let url):
            return "Source does not exist: \(url.path)"
        case .sourceIsNotReachable(let url, let error):
            return "Source is not reachable: \(url.path). \(error)"
        case .sourceParentIsNotWritable(let url):
            return "Source parent is not writable: : \(url.path)"
        case .destinationAlreadyExists(let url):
            return "Destination already exists: \(url.path). Delete or rename this file/folder to continue."
        case .destinationParentDoesNotExist(let url):
            return "Destination parent directory does not exist: \(url.path)"
        case .destinationParentIsNotDirectory(let url):
            return "Destination parent is not a directory: \(url.path)"
        case .destinationParentIsNotWritable(let url):
            return "Destination parent is not writable: \(url.path)"
        case .duplicateSource(let url):
            return "Duplicate source URL in move list: \(url.path)"
        case .duplicateDestination(let url):
            return "Duplicate destination URL in move list: \(url.path)"
        case .sourceEqualsDestination(let url):
            return "Source and destination are the same: \(url.path)"
        case .moveWouldPlaceDirectoryInsideItself(let source, let destination):
            return "Cannot move directory \(source.path) inside itself at \(destination.path)"
        case .moveFailed(let source, let destination, let error):
            return "Failed to move \(source.path) to \(destination.path). \(error)"
        }
    }

}
