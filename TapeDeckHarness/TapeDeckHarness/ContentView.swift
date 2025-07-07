//
//  ContentView.swift
//  TapeDeckHarness
//
//  Created by Ben Gottlieb on 10/1/24.
//

import Suite
import TapeDeck
import Journalist

class Test {
	@SceneStorage("sceneID") var sceneID = UUID().uuidString
}

struct ContentView: View {
	@State var manager: TranscriptionManager = .instance
	@State var recorder = TranscriptionManager.instance.activeRecorder
	
	var body: some View {
		//let _ = print(recorder.state)
		VStack {
			HStack {
				AsyncButton(action: {
					do {
						switch recorder.state {
						case .idle: try await recorder.record()
						case .recording: recorder.pause()
						case .paused: try recorder.resume()
						}
					} catch {
						print("Failed: \(error)")
					}
				}) {
					Image(systemName: recorder.state.imageName)
				}
				
				if recorder.state != .idle {
					AsyncButton(action: { await recorder.stop() }) {
						Image(systemName: "stop.fill")
					}
				}
			}
			.font(.system(size: 60))
		}
		.onAppear {
		}
	}
}

#Preview {
	ContentView()
}
