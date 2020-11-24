import AVFoundation
import UIKit

protocol ScannerViewControllerDelegate {
	func scannerViewController(_ scannerViewController: ScannerViewController, didScan isbn: String)
}

class ScannerViewController: UIViewController {
	let input: AVCaptureDeviceInput!
	let session: AVCaptureSession = AVCaptureSession()
	let output: AVCaptureMetadataOutput = AVCaptureMetadataOutput()
	let preview: AVCaptureVideoPreviewLayer!

	weak var delegate: (ScannerViewControllerDelegate & AnyObject)?

	init() {
		let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [ .builtInWideAngleCamera ], mediaType: .video, position: .back)
		let camera = discoverySession.devices.first!
		do {
			try camera.lockForConfiguration()
			camera.whiteBalanceMode = .continuousAutoWhiteBalance
			camera.exposureMode = .continuousAutoExposure
			camera.unlockForConfiguration()

			input = try AVCaptureDeviceInput(device: camera)
			session.addInput(input)
			session.addOutput(output)

			preview = AVCaptureVideoPreviewLayer(session: session)
		} catch {
			fatalError()
		}

		super.init(nibName: nil, bundle: nil)
	}

	required init?(coder: NSCoder) {
		fatalError()
	}

	override var prefersStatusBarHidden: Bool {
		true
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		session.startRunning()

		output.setMetadataObjectsDelegate(self, queue: .main)
		output.metadataObjectTypes = [ .ean8, .ean13 ]

		preview.videoGravity = .resizeAspectFill
		view.layer.addSublayer(preview)
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)

		navigationController?.isNavigationBarHidden = true
		navigationController?.isToolbarHidden = true
	}

	override func viewWillLayoutSubviews() {
		super.viewWillLayoutSubviews()

		preview.frame = view.bounds
	}
}

extension ScannerViewController : AVCaptureMetadataOutputObjectsDelegate {
	func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
		metadataObjects
			.compactMap { $0 as? AVMetadataMachineReadableCodeObject }
			.compactMap { $0.stringValue }
			.forEach {
				delegate?.scannerViewController(self, didScan: $0)
			}
	}
}
