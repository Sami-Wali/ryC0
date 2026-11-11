//
//  CertificateSource.swift
//  LiveContainerSwiftUI
//

import Foundation

enum CertificateSource: Equatable {
    /// A `certificate?cert=&password=` link, which any app can open.
    case link
    /// A .p12 (or .pfx) file opened with ryC0, once its password was
    /// typed.
    case file
}
