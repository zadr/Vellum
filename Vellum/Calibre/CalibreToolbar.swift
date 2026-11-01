import SwiftUI

struct CalibreToolbar: ToolbarContent {
	@Environment(CalibreLibrary.self) private var calibre

	@Binding var sort: CalibreSort
	@Binding var showsDownloadedOnly: Bool

	let done: () -> Void
	let editServer: () -> Void

	var body: some ToolbarContent {
		ToolbarItem(placement: .cancellationAction) {
			Button(role: .close, action: done)
		}

		ToolbarItem(placement: .topBarTrailing) {
			Menu("Options", systemImage: "line.3.horizontal.decrease") {
				Picker("Sort By", selection: $sort) {
					ForEach(CalibreSort.allCases) { sort in
						Label(sort.label, systemImage: sort.systemImage)
							.tag(sort)
					}
				}

				Section {
					Toggle("Downloaded Only", systemImage: "arrow.down.circle", isOn: $showsDownloadedOnly)
				}

				Section(calibre.serverAddress) {
					Button("Change Server", systemImage: "server.rack", action: editServer)
				}
			}
		}
	}
}
