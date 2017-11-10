import Foundation
/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Dispatch

import Console

class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    let ctx: Context
    let completion: (URL) -> Void
    let sema: DispatchSemaphore
    let progress: ProgressBar

    init(ctx: Context, completion: @escaping (URL) -> Void, sema: DispatchSemaphore) {
        self.ctx = ctx
        self.completion = completion
        self.sema = sema

        // Adjust the width to fit everything nicely.
        let width = ctx.console.size.width - 22
        self.progress = ctx.console.progressBar(title: "downloading", width: width)
    }

    func finish() {
        progress.progress = 1
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        progress.progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo outputUrl: URL) {
        finish()
        defer { ctx.system.delete(outputUrl) }

        completion(outputUrl)
        sema.signal()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        if let error = error {
            finish()
            ctx.fail("error downloading file: \(error.localizedDescription)")
        }
    }
}

class FileDownloader {
    class func download(ctx: Context, from url: URL, _ completion: @escaping (URL) -> Void) {
        ctx.note("Downloading \(url.absoluteString)...")

        let sema = DispatchSemaphore(value: 0)
        let session = URLSession(configuration: URLSessionConfiguration.default,
                                 delegate: DownloadDelegate(ctx: ctx, completion: completion, sema: sema),
                                 delegateQueue: nil)

        let task = session.downloadTask(with: url)
        task.resume()
        _ = sema.wait(timeout: DispatchTime.distantFuture)
    }
}
