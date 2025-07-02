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
		let _ = print(recorder.state)
		VStack {
			HStack {
				AsyncButton(action: {
					switch recorder.state {
					case .idle: try await recorder.record()
					case .recording: recorder.pause()
					case .paused: try recorder.resume()
					}
				}) {
					Image(systemName: recorder.state.imageName)
				}
				
				if recorder.state != .idle {
					Button(action: { recorder.stop() }) {
						Image(systemName: "stop.fill")
					}
				}
			}
		}
		.onAppear {
		}
	}
}

#Preview {
	ContentView()
}
