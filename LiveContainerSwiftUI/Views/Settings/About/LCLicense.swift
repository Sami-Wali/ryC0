//
//  LCLicense.swift
//  LiveContainerSwiftUI
//
//  A license whose text comes with the app, in its Licenses folder, as the About
//  page shows it.
//

import Foundation

struct LCLicense: Identifiable, Sendable {
    /// What the license covers, written the way its project writes its name.
    let name: String

    /// The license's own name, like "MIT License". Not translated.
    let licenseName: String

    /// The text's file in the app's Licenses folder.
    let fileName: String

    /// The same text online, opened when the file can't be read.
    let url: URL

    var id: String { fileName }

    /// The text from its file, or nil when the file is missing. Read off the main
    /// actor, since the longest is 35 KB.
    @concurrent
    func text() async -> String? {
        guard let fileURL = Bundle.main.url(forResource: fileName, withExtension: nil, subdirectory: "Licenses"),
              let text = try? String(contentsOf: fileURL, encoding: .utf8)
        else { return nil }

        return Self.paragraphs(of: text)
    }

    /// The text with each paragraph's lines joined into one, so it wraps to the
    /// screen rather than at the 80 columns it was written for. A list item
    /// starts a line of its own. Only the spacing changes; the words are the
    /// license's own.
    private static func paragraphs(of text: String) -> String {
        var paragraphs: [String] = []
        var lines: [String] = []
        func endParagraph() {
            if !lines.isEmpty {
                paragraphs.append(lines.joined(separator: "\n"))
                lines = []
            }
        }

        for rawLine in text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                endParagraph()
            } else if lines.isEmpty || startsListItem(line) {
                lines.append(line)
            } else {
                lines[lines.count - 1] += " " + line
            }
        }
        endParagraph()
        return paragraphs.joined(separator: "\n\n")
    }

    /// Whether a line begins a list item, like "* Redistributions" in a BSD
    /// license whose items have no blank line between them.
    private static func startsListItem(_ line: String) -> Bool {
        line.hasPrefix("* ") || line.hasPrefix("- ")
    }
}

extension LCLicense {
    /// ryC0's own license, which it keeps from LiveContainer: the LICENSE
    /// file at the root of the source.
    static let ryC0 = LCLicense(
        name: "ryC0",
        licenseName: "GNU Affero General Public License v3.0",
        fileName: "ryC0.txt",
        url: LCAboutLinks.license
    )

    /// The open source software inside the app, in the order of the
    /// acknowledgements. Each license asks for its text to come with every copy,
    /// so the build copies them into the app's Licenses folder: the Xcode
    /// target's Run Script and Scripts/ryc0/assemble.py, from the projects' own
    /// LICENSE files, or from Resources/Licenses for those the source doesn't
    /// otherwise hold. Update the copy and its link along with the project.
    static let thirdParty = [
        LCLicense(
            name: "OpenSSL",
            licenseName: "Apache License 2.0",
            fileName: "OpenSSL.txt",
            url: URL(string: "https://github.com/openssl/openssl/blob/openssl-3.3.3/LICENSE.txt")!
        ),
        LCLicense(
            name: "ElleKit",
            licenseName: "BSD 3-Clause License",
            fileName: "ElleKit.txt",
            url: URL(string: "https://github.com/evelyneee/ellekit/blob/main/LICENSE")!
        ),
        // zsign's license when LiveContainer took Feather's version of it, late
        // in 2024. zsign moved to the MIT License in 2025.
        LCLicense(
            name: "zsign",
            licenseName: "BSD 3-Clause License",
            fileName: "zsign.txt",
            url: URL(string: "https://github.com/zhlynn/zsign/blob/5076ab496343e9c94059ff8a1122cdb12f27ee91/LICENSE")!
        ),
        // Feather, whose changes to zsign LiveContainer uses.
        LCLicense(
            name: "Feather",
            licenseName: "GNU General Public License v3.0",
            fileName: "Feather.txt",
            url: URL(string: "https://github.com/khcrysalis/Feather/blob/main/LICENSE")!
        ),
        LCLicense(
            name: "litehook",
            licenseName: "MIT License",
            fileName: "litehook.txt",
            url: URL(string: "https://github.com/LiveContainer/litehook/blob/a7e9f599d7f0b3d77008ad62bf10cb10dab6eca9/LICENSE")!
        ),
        LCLicense(
            name: "CFastFind",
            licenseName: "MIT License",
            fileName: "CFastFind.txt",
            url: URL(string: "https://github.com/pinauten/PatchfinderUtils/blob/68f6e7f430d94bc01315b0f1e753e3764b9cc31d/LICENSE")!
        ),
    ]
}
