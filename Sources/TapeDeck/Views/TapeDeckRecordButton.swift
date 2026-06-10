//
//  File.swift
//  TapeDeck
//
//  Created by Ben Gottlieb on 6/10/26.
//

import Suite

public struct TapeDeckRecordButton<Content: View>: View {
	let content: (Bool) -> Content
	let action: @MainActor () async throws -> Void
	let useContentBlock: Bool

	@ObservedObject private var transcriptionist = SpeechTranscriptionist.instance
	@State private var isShowSettingsAlert = false
	
	public init(content: @escaping (Bool) -> Content) {
		self.content = content
		useContentBlock = true
		self.action = { }
	}
	
	public var body: some View {
		if !useContentBlock {
			AsyncButton(action: {
				if TapeDeckPermissions.instance.isDenied {
					isShowSettingsAlert = true
				} else {
					try? await action()
				}
			}) {
				Image(systemName: transcriptionist.isRunning ? "mic.circle" : "mic.slash.circle")
					.padding()
			}
			.font(.system(size: 32))
			.alert("Access Denied", isPresented: $isShowSettingsAlert) {
				Button("OK") { }
				Button("Open Settings") { UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!) }
			} message: {
				Text("You need to authorize microphone and speech recognition in your application's system settings.")
			}

		} else {
			content(transcriptionist.isRunning)
		}
	}
	
}



extension TapeDeckRecordButton where Content == EmptyView {
	public init(action: @escaping () async throws -> Void) {
		self.content = { _ in EmptyView() }
		self.action = action
		self.useContentBlock = false
	}
}
