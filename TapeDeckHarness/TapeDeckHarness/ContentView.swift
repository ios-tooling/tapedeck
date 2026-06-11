//
//  ContentView.swift
//  TapeDeckHarness
//
//  Created by Ben Gottlieb on 10/1/24.
//

import SwiftUI
import TapeDeck

struct ContentView: View {
	var body: some View {
		TabView {
			Tab("Record", systemImage: "mic.circle") {
				RecordScreen()
			}

			Tab("Library", systemImage: "list.bullet") {
				LibraryScreen()
			}

			Tab("Dictate", systemImage: "text.bubble") {
				DictationScreen()
			}
		}
		.task {
			RecordingStore.instance.setup(root: URL.documentsDirectory.appendingPathComponent("Recordings"))
		}
	}
}

#Preview {
	ContentView()
}
