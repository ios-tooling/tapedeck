//
//  ContentView.swift
//  TapeDeckHarness
//
//  Created by Ben Gottlieb on 10/1/24.
//

import Suite
import TapeDeck
import Journalist

struct ContentView: View {
	@State var text: String = ""
	@State var isRunning = false
	@State var isListening = false
	@ObservedObject var mic = Microphone.instance
	@ObservedObject var recorder = Recorder.instance
	var body: some View {
		VStack {
			SoundLevelsView()
			SpeechRecognitionContainer(text: $text, running: isRunning) { trans in
				
				TextField("Speak!", text: $text, axis: .vertical)
				
			}
			
			Button(action: { isRunning.toggle() }) {
				Text(!isRunning ? "Start Recording" : "Stop Recording")
			}
			
			AsyncButton(action: {
				if mic.isListening {
					try await mic.stop()
					try await recorder.stop()
				} else {
					try await mic.start()
					try await recorder.startRecording()
				}
			}) {
				Text(mic.isListening ? "Stop Listening" : "Start Listening")
			}
		}
		.task {
		}
		.padding()
	}
}

#Preview {
	ContentView()
}
