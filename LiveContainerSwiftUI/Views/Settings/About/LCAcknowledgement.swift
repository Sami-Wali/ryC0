//
//  LCAcknowledgement.swift
//  LiveContainerSwiftUI
//
//  Open source work ryC0 ships or builds on, besides LiveContainer.
//

import Foundation

struct LCAcknowledgement: Identifiable {
    let name: String
    /// Who made it, and its license where it ships inside the app.
    let detail: String
    let url: URL

    var id: String { name }

    static let all: [LCAcknowledgement] = [
        LCAcknowledgement(name: "OpenSSL", detail: "Apache License 2.0",
                          url: URL(string: "https://www.openssl.org")!),
        LCAcknowledgement(name: "ElleKit", detail: "Évelyne Bélanger, BSD License",
                          url: URL(string: "https://github.com/evelyneee/ellekit")!),
        LCAcknowledgement(name: "zsign", detail: "zhlynn, BSD License, with Feather's changes by khcrysalis, GPL 3.0",
                          url: URL(string: "https://github.com/zhlynn/zsign")!),
        LCAcknowledgement(name: "litehook", detail: "Lars Fröder (opa334), MIT License",
                          url: URL(string: "https://github.com/opa334/litehook")!),
        LCAcknowledgement(name: "CFastFind", detail: "Linus Henze, MIT License",
                          url: URL(string: "https://github.com/pinauten/PatchfinderUtils")!),
        LCAcknowledgement(name: "FrontBoardAppLauncher", detail: "Duy Tran",
                          url: URL(string: "https://github.com/khanhduytran0/FrontBoardAppLauncher")!),
        LCAcknowledgement(name: "Restoring Dyld Memory Loading", detail: "Adam Chester (xpn)",
                          url: URL(string: "https://blog.xpnsec.com/restoring-dyld-memory-loading")!),
    ]
}
