import Foundation

/// Downloads a file to a fixed location, reporting progress along the way.
nonisolated final class FileDownload: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
	private let destination: URL
	private let progress: @Sendable (Double) -> Void

	// Only touched on the session's serial delegate queue, after being set before the task starts.
	private var continuation: CheckedContinuation<Void, Error>?
	private var failure: Error?

	private init(destination: URL, progress: @escaping @Sendable (Double) -> Void) {
		self.destination = destination
		self.progress = progress
	}

	static func start(from source: URL, to destination: URL, progress: @escaping @Sendable (Double) -> Void) async throws {
		let download = FileDownload(destination: destination, progress: progress)
		let session = URLSession(configuration: .default, delegate: download, delegateQueue: nil)
		defer { session.finishTasksAndInvalidate() }

		let task = session.downloadTask(with: source)
		try await withTaskCancellationHandler {
			try await withCheckedThrowingContinuation { continuation in
				download.continuation = continuation
				task.resume()
			}
		} onCancel: {
			task.cancel()
		}
	}

	func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
		guard totalBytesExpectedToWrite > 0 else { return }
		progress(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
	}

	func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
		switch (downloadTask.response as? HTTPURLResponse)?.statusCode ?? 0 {
		case 200..<300:
			break
		case 404:
			failure = CalibreError.notFound
			return
		default:
			failure = CalibreError.unavailable
			return
		}

		// The temporary file is deleted as soon as this returns, so it has to be moved now.
		do {
			let fileManager = FileManager.default
			try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
			try? fileManager.removeItem(at: destination)
			try fileManager.moveItem(at: location, to: destination)
		} catch {
			failure = error
		}
	}

	func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
		if let error = error as? URLError {
			continuation?.resume(throwing: error.code == .cancelled ? CancellationError() : CalibreError.offline)
		} else if let error = error ?? failure {
			continuation?.resume(throwing: error)
		} else {
			continuation?.resume()
		}
		continuation = nil
	}
}
