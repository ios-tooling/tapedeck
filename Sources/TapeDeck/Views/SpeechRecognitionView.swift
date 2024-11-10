//
//  SpeechRecognitionView.swift
//  TapeDeck
//
//  Created by Ben Gottlieb on 9/8/24.
//

import Suite

public struct SpeechRecognitionView: View {
	@State var isRunning = false
	@Binding var fixedIsRunning: Bool
	let useState: Bool
	
	public init(isRunning: Binding<Bool>? = nil) {
		_fixedIsRunning = isRunning ?? .constant(false)
		useState = isRunning == nil
	}
	
	var imageName: String {
		if Gestalt.isOnSimulator { return "mic.slash.circle" }
		let binding = useState ? $isRunning : $fixedIsRunning
		
		if binding.wrappedValue { return "stop.circle.fill" }
		return "mic.circle.fill"
	}
	
	public var body: some View {
		SpeechRecognitionContainer(running: $isRunning) { transcript in
			HStack {
				ScrollView {
					TranscribedText(transcript: transcript)
				}
				.frame(maxWidth: .infinity, alignment: .leading)
				
				if useState {
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
