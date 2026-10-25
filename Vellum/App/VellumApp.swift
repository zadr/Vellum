import SwiftUI

@main
struct VellumApp: App {
	@State private var library = Library()

	init() {
		// Covers are fetched with AsyncImage, which relies on the shared URL cache. Give it room so shelves load instantly.
		URLCache.shared = URLCache(memoryCapacity: 32_000_000, diskCapacity: 256_000_000)
	}

	var body: some Scene {
		WindowGroup {
			ShelfView()
				.environment(library)
				.task {
					await library.backfillAuthors()
				}
		}
	}
}
