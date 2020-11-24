import UIKit

class ListViewController: UIViewController {
	let tableView: UITableView = UITableView(frame: .zero)

	var requesting = [String]()
	var data: [Book]

	let haptic = UINotificationFeedbackGenerator()

	var task: URLSessionDataTask? = nil
	let api = API()
	let jsonEncoder = JSONEncoder()

	required init() {
		if let raw = UserDefaults.standard.data(forKey: "books"), !raw.isEmpty {
			data = try! JSONDecoder().decode([Book].self, from: raw)
		} else {
			data = []
		}

		super.init(nibName: nil, bundle: nil)
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override var prefersStatusBarHidden: Bool {
		true
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		haptic.prepare()

		toolbarItems = [ UIBarButtonItem.flexibleSpace(), UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(add))]
		view.addSubview(tableView)

		tableView.delegate = self
		tableView.dataSource = self
		tableView.rowHeight = UITableView.automaticDimension
		tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)

		navigationController?.isNavigationBarHidden = true
		navigationController?.isToolbarHidden = false
	}

	override func viewWillLayoutSubviews() {
		super.viewWillLayoutSubviews()

		tableView.frame = view.bounds
	}
}

extension ListViewController {
	@objc func add() {
		let scannerViewController = ScannerViewController()
		scannerViewController.delegate = self
		navigationController?.pushViewController(scannerViewController, animated: true)
	}

	func kickstart() {
		if task != nil {
			return
		}

		guard let isbn = requesting.first else {
			return
		}

		task = api.request(isbn: isbn, completion: { result in
			switch result {
			case .success(let book):
				DispatchQueue.main.async {
					self.task = nil

					self.requesting.remove(at: 0)

					self.data.append(book)

					self.tableView.reloadData()

					let lastIndexPath = IndexPath(row: self.data.count - 1, section: 0)
					self.tableView.scrollToRow(at: lastIndexPath, at: .bottom, animated: true)

					do {
						let json = try self.jsonEncoder.encode(self.data)
						UserDefaults.standard.set(json, forKey: "books")
					} catch let error {
						print(error)
					}
				}

				DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
					self.kickstart()
				}

				print(book)
			case .failure(let error):
				print(error)
			}
		})

		task?.resume()
	}
}

extension ListViewController : ScannerViewControllerDelegate {
	func scannerViewController(_ scannerViewController: ScannerViewController, didScan isbn: String) {
		if !requesting.contains(isbn) && !data.flatMap({ $0.isbn13 ?? [] }).contains(isbn) {
			haptic.notificationOccurred(.success)

			requesting.append(isbn)

			kickstart()
		}

		navigationController?.popViewController(animated: true)
	}
}

extension ListViewController : UITableViewDataSource {
	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return data.count
	}

	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "cell") ?? UITableViewCell(style: .default, reuseIdentifier: "cell")
		cell.textLabel?.text = data[indexPath.row].title.capitalized
		cell.textLabel?.numberOfLines = 0
		return cell
	}
}

extension ListViewController : UITableViewDelegate {
	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		tableView.deselectRow(at: indexPath, animated: true)
	}
}
