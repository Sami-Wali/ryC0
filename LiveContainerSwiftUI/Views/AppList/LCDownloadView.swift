//
//  LCDownloadView.swift
//  LiveContainerSwiftUI
//
//  Created by s s on 2025/1/22.
//

import SwiftUI

@MainActor
public final class DownloadHelper : ObservableObject {
    @Published var downloadProgress : Float = 0.0
    @Published var downloadedSize : Int64 = 0
    @Published var totalSize : Int64 = 0
    @Published var isDownloading = false
    @Published var cancelled = false
    private var downloadTask: URLSessionDownloadTask?
    private var continuation: CheckedContinuation<Void, Error>?
    /// The session of the download under way. A session keeps its delegate,
    /// and with it this helper, until it is invalidated.
    private var session: URLSession?

    func download(url: URL, to: URL) async throws {
        guard !isDownloading else { throw URLError(.resourceUnavailable) }
        try Task.checkCancellation()
        cancelled = false
        downloadProgress = 0
        downloadedSize = 0
        totalSize = 0
        isDownloading = true

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { c in
                continuation = c
                // The owning queue outlives every screen. A foreground session
                // avoids abandoned background sessions after a classic guest
                // replaces the host process; durable queued jobs restart on return.
                let config = URLSessionConfiguration.default
                config.httpMaximumConnectionsPerHost = 8
                config.waitsForConnectivity = true
                config.timeoutIntervalForResource = 24 * 60 * 60
                let session = URLSession(configuration: config, delegate: DownloadDelegate(progressCallback: { progress, downloaded, total in
                    MainActor.assumeIsolated {
                    self.downloadProgress = progress
                    self.downloadedSize = downloaded
                    self.totalSize = total
                    }
                }, completeCallback: { endedSession, tempFileURL, error in
                    // Delegate callbacks run on .main, so completion and cancel
                    // cannot race or resume the continuation twice.
                    MainActor.assumeIsolated {
                        guard endedSession === self.session, let continuation = self.continuation else { return }
                        self.continuation = nil
                        self.session = nil
                        self.downloadTask = nil
                        self.isDownloading = false
                        do {
                            if let error { throw error }
                            guard let tempFileURL else { throw URLError(.zeroByteResource) }
                            try FileManager.default.moveItem(at: tempFileURL, to: to)
                            continuation.resume()
                        } catch { continuation.resume(throwing: error) }
                    }
                }), delegateQueue: .main)
                self.session = session
                downloadTask = session.downloadTask(with: url)
                downloadTask?.resume()
                session.finishTasksAndInvalidate()
            }
        } onCancel: {
            Task { @MainActor in self.cancel() }
        }
    }
    
    func cancel() {
        cancelled = true
        let pending = continuation
        continuation = nil
        downloadTask?.cancel()
        session?.invalidateAndCancel()
        session = nil
        isDownloading = false
        pending?.resume(throwing: CancellationError())
    }
}

struct DownloadAlert : View {
    @StateObject var helper : DownloadHelper
    var body: some View {
        
        Color.black.opacity(0.2) // Semi-transparent grey background
            .edgesIgnoringSafeArea(.all) // Covers entire screen
        
        VStack {
            Text("lc.download.downloading".loc)
                .font(.headline)
                .padding(.top)
            
            ProgressView(value: helper.downloadProgress, total: 1)
                .padding()
            
            Text("\(formatBytes(helper.downloadedSize)) / \(formatBytes(helper.totalSize))")
                .font(.subheadline)
                .padding(.bottom)
            
            Button(action: cancelDownload) {
                Text("lc.common.cancel".loc)
                    .foregroundColor(.red)
                    .padding(.bottom)
            }
        }
        .frame(width: 300)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(radius: 10)
        .padding()
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB] // Allow KB, MB, and GB
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    func cancelDownload() {
        helper.cancel()
    }
}

public struct DownloadAlertModifier: ViewModifier {
    @ObservedObject var helper : DownloadHelper
    @State var show = false
    
    public func body(content: Content) -> some View {

        ZStack {
            content
            if show {
                DownloadAlert(helper: helper)
                
            }
            
        }
        .onChange(of: helper.isDownloading) { newVal in
            withAnimation(.easeInOut(duration: 0.1)) {
                show = newVal
            }
        }
    }
}

class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    let progressCallback: (Float, Int64, Int64) -> Void
    let completeCallback: (URLSession, URL?, Error?) -> Void

    init(progressCallback: @escaping (Float, Int64, Int64) -> Void,
         completeCallback: @escaping (URLSession, URL?, Error?) -> Void) {
        self.progressCallback = progressCallback
        self.completeCallback = completeCallback
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progress = totalBytesExpectedToWrite > 0 ? min(1, Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)) : 0
        progressCallback(progress, totalBytesWritten, totalBytesExpectedToWrite)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        if let httpResponse = downloadTask.response as? HTTPURLResponse {
            let statusCode = httpResponse.statusCode

            // Check if the status code is in the 2xx range
            if (200...299).contains(statusCode) {
                completeCallback(session, location, nil)
            } else {
                completeCallback(session, nil, NSError(domain: "", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP Error: \(statusCode)"]))
            }
        } else {
            completeCallback(session, nil, NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"]))
        }
        

    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            completeCallback(session, nil, error)
        } else {

        }
    }
}

extension View {
    public func downloadAlert(helper: DownloadHelper) -> some View {
        self.modifier(DownloadAlertModifier(helper: helper))
    }
}
