//
//  SpeechRecognitionView.swift
//  TapeDeck
//
//  Created by Ben Gottlieb on 9/8/24.
//

import Suite

@available(iOS 17.0, *)
public struct SpeechRecognitionView: View {
	@State var isRunning = false
	let fixedIsRunning: Bool?
	
	public init(isRunning: Bool? = nil) {
		fixedIsRunning = isRunning
	}
	
	var imageName: String {
		if Gestalt.isOnSimulator { return "mic.slash.circle" }
		
		if (fixedIsRunning ?? isRunning) { return "stop.circle.fill" }
		return "mic.circle.fill"
	}
	
	public var body: some View {
		SpeechRecognitionContainer(running: fixedIsRunning ?? isRunning) { transcript in
			HStack {
				ScrollView {
					Text(transcript.confidentText + " ").foregroundStyle(.primary) + Text(transcript.recentText).foregroundStyle(.secondary)
				}
				.frame(maxWidth: .infinity, alignment: .leading)
				
				if fixedIsRunning == nil {
					AsyncButton(action: { try await toggle() }) {
						Image(systemName: imageName)
							.font(.system(size: 32))
							.foregroundStyle(Gestalt.isOnSimulator ? .red : .accentColor)
							.padding()
					}
				}
			}
			.background {
				RoundedRectangle(cornerRadius: 4)
					.stroke(Color.primary.opacity(0.25), lineWidth: 0.5)
			}
		}
    }
	
	func toggle() async throws {
		isRunning.toggle()
	}
}

#Preview {
	if #available(iOS 17.0, *) {
		SpeechRecognitionView()
	}
}
