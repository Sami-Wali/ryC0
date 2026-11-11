//
//  PendingInstallKind.swift
//  LiveContainerSwiftUI
//

/// Where an app waiting in PendingInstallQueue came from, as the record
/// PendingInstallStore keeps of it says.
enum PendingInstallKind: String, Codable {
    /// An install link, whose IPA downloads into the app's folder.
    case link

    /// An IPA opened with ryC0 or shared to it, which its bookmark
    /// finds again.
    case openedFile

    /// An IPA picked in Files, whose copy moved into the app's folder.
    case pickedFile

}
