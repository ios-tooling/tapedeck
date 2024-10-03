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
			AmbientWaveformView(lineWidth: 1)
				.clipShape(.circle)
				.foregroundStyle(Color.siriPurple)
				.overlay {
					Circle()
						.stroke(.black, lineWidth: 2)
				}
				.background {
					Circle()
						.fill(RadialGradient(colors: [.black, .gray], center: .center, startRadius: 50, endRadius: 0))
				}
				.frame(width: 45, height: 45)

			SoundLevelsView()
			SpeechRecognitionContainer(text: $text, running: isRunning) { trans in
				
				TextField("Speak!", text: $text, axis: .vertical)
				
			}
			
			HStack {
				AsyncButton(action: { isRunning.toggle() }) {
					Image(systemName: !isRunning ? "circle.fill" : "stop.fill")
						.foregroundStyle(.red)
						.padding()
				}
				.font(.system(size: 32))

				AsyncButton(action: { try? await mic.toggle() }) {
					Image(systemName: mic.isListening ? "microphone.fill" : "microphone.slash")
						.padding()
				}
				.font(.system(size: 32))
				
				AsyncButton(action: {
					if recorder.isRecording {
						try await recorder.stop()
					} else {
						try await recorder.startRecording()
					}
				}) {
					Text(mic.isListening ? "Stop Listening" : "Start Listening")
				}
			}
		}
		.task {
			_ = try? await mic.start()
		}
		.padding()
	}
}

#Preview {
	ContentView()
}
