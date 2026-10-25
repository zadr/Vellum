import AVFoundation
import VisionKit

enum CameraAccess {
	case checking
	case granted
	case denied
	case unsupported

	/// Asks for camera permission if needed, and reports whether live scanning can be used.
	static func request() async -> CameraAccess {
		guard DataScannerViewController.isSupported else { return .unsupported }

		switch AVCaptureDevice.authorizationStatus(for: .video) {
		case .authorized:
			return .granted
		case .notDetermined:
			return await AVCaptureDevice.requestAccess(for: .video) ? .granted : .denied
		default:
			return .denied
		}
	}
}
