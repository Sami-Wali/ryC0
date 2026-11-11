//
//  CertificateLink.swift
//  LiveContainerSwiftUI
//

import Foundation

struct CertificateLink: Equatable {
    /// The certificate and its private key, as a .p12.
    let certificateData: Data
    /// The password that opens the .p12.
    let password: String

    init(certificateData: Data, password: String) {
        self.certificateData = certificateData
        self.password = password
    }

    /// Reads the certificate from a `certificate` link. Returns nil when the
    /// link lacks the certificate or its password, or the certificate isn't
    /// valid Base64. Query item names are read without regard to case.
    init?(url: URL) {
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        var values: [String: String] = [:]
        for item in queryItems {
            values[item.name.lowercased()] = item.value
        }
        guard let encoded = values["cert"]?.removingPercentEncoding,
              let password = values["password"],
              let certificateData = Data(base64Encoded: encoded) else {
            return nil
        }
        self.certificateData = certificateData
        self.password = password
    }
}
