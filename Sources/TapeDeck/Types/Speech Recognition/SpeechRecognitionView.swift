//
//  SpeechRecognitionView.swift
//  TapeDeck
//
//  Created by Ben Gottlieb on 9/8/24.
//

import Suite

@available(iOS 17.0, *)
public struct SpeechRecognitionView: View {
   @StateObject var transcript = SpeechTranscriptionist()

	public init() { }
	
	var imageName: String {
		if Gestalt.isOnSimulator { return "mic.slash.circle" }
		if transcript.isRunning { return "stop.circle.fill" }
		return "mic.circle.fill"
	}
	
	public var body: some View {
		HStack {
			ScrollView {
				Text(transcript.currentTranscription.confidentText + " ").foregroundStyle(.primary) + Text(transcript.currentTranscription.recentText).foregroundStyle(.secondary)
			}
			.frame(maxWidth: .infinity, alignment: .leading)
			
			AsyncButton(action: { try await toggle() }) {
				Image(systemName: imageName)
					.font(.system(size: 32))
					.foregroundStyle(Gestalt.isOnSimulator ? .red : .accentColor)
					.padding()
			}
		}
		.background {
			RoundedRectangle(cornerRadius: 4)
				.stroke(Color.primary.opacity(0.25), lineWidth: 0.5)
		}
    }
	
	func toggle() async throws {
		if transcript.isRunning {
			transcript.stop()
		} else {
			try await transcript.start()
		}
	}
}

#Preview {
	if #available(iOS 17.0, *) {
		SpeechRecognitionView()
	}
}
