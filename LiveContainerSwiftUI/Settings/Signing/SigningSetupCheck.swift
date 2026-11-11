//
//  SigningSetupCheck.swift
//  LiveContainerSwiftUI
//

import SwiftUI

enum SigningSetupCheck: CaseIterable, Hashable {
    case sharedStorage
    /// The keychain groups, one per container, which keep each container's
    /// sign-ins apart.
    case separateLogins
    /// Signing a test library with the certificate and checking that iOS
    /// accepts it, as it has to for the apps inside to open without JIT.
    case signing

    /// The row's name.
    var title: String {
        switch self {
        case .sharedStorage:
            "ryc0.settings.setup.sharedStorage".loc
        case .separateLogins:
            "ryc0.settings.setup.separateLogins".loc
        case .signing:
            "ryc0.settings.setup.signing".loc
        }
    }

    /// What the part does, under the row's name.
    var detail: String {
        switch self {
        case .sharedStorage:
            "ryc0.settings.setup.sharedStorageDetail".loc
        case .separateLogins:
            "ryc0.settings.setup.separateLoginsDetail".loc
        case .signing:
            "ryc0.settings.setup.signingDetail".loc
        }
    }

    /// The symbol on the row's icon.
    var systemImage: String {
        switch self {
        case .sharedStorage:
            "folder.fill"
        case .separateLogins:
            "key.fill"
        case .signing:
            "checkmark.seal.fill"
        }
    }

    /// The color of the row's icon.
    var color: Color {
        switch self {
        case .sharedStorage:
            .blue
        case .separateLogins:
            .gray
        case .signing:
            .indigo
        }
    }

    /// What is lost while it's missing, under the row's name, for the parts
    /// ryC0 works without.
    var missingDetail: String {
        switch self {
        case .sharedStorage:
            "ryc0.settings.setup.sharedStorageMissing".loc
        case .separateLogins:
            "ryc0.settings.setup.separateLoginsMissing".loc
        case .signing:
            detail
        }
    }

    var isOptional: Bool {
        self != .signing
    }
}
