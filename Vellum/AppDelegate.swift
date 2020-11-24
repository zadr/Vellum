import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
	var window: UIWindow?

	func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
		UserDefaults.standard.register(defaults: [
			"active-list": "Main",
			"lists": ["Main"]
		])

		window = UIWindow(frame: UIScreen.main.bounds)
		window?.tintColor = UIColor(red: (195.0 / 255.0), green: (95.0 / 255.0), blue: (235.0 / 255.0), alpha: 1.0)
		window?.rootViewController = UINavigationController(rootViewController: ListViewController())

		return true
	}

	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
		window?.makeKeyAndVisible()

		return true
	}
}
