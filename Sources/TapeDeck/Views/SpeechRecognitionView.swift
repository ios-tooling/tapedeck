//
//  SpeechRecognitionView.swift
//  TapeDeck
//
//  Created by Ben Gottlieb on 9/8/24.
//

#if os(iOS)
import Suite

public struct SpeechRecognitionView: View {
	@State var isRunning = false
	@Binding var fixedIsRunning: Bool
	let useState: Bool
	
	public init(isRunning: Binding<Bool>? = nil) {
		_fixedIsRunning = isRunning ?? .constant(false)
		useState = isRunning == nil || Gestalt.isAttachedToDebugger
	}
	
	public var body: some View {
		SpeechRecognitionContainer(running: $isRunning) { transcript in
			HStack {
				ScrollView {
					TranscribedText(transcript: transcript)
				}
				.frame(maxWidth: .infinity, alignment: .leading)
				
				if useState {
					TapeDeckRecordButton { try await toggle() }
				}
			}
			.background {
				RoundedRectangle(cornerRadius: 4)
					.stroke(Color.primary.opacity(0.25), lineWidth: 0.5)
			}
		}
    }
	
	var imageName: String {
		if TapeDeckPermissions.instance.notYetAuthorized { return "mic.slash.circle" }
		if Gestalt.isOnSimulator { return "mic.slash.circle" }
		let binding = useState ? $isRunning : $fixedIsRunning
		
		if binding.wrappedValue { return "stop.circle.fill" }
		return "mic.circle.fill"
	}
	
	var imageColor: Color {
		if TapeDeckPermissions.instance.isDenied { return .red }
		if TapeDeckPermissions.instance.notYetAuthorized { return .primary.opacity(0.25) }

		guard let hasPermission = TapeDeckPermissions.instance.hasRecordingPermissions else { return .primary.opacity(0.25) }
		
		if hasPermission { return .primary }
		return .red
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
#endif
