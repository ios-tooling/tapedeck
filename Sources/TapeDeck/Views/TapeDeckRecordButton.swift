//
//  File.swift
//  TapeDeck
//
//  Created by Ben Gottlieb on 6/10/26.
//

import Suite

public struct TapeDeckRecordButton<Content: View>: View {
	let content: Content
	let action: @MainActor () async throws -> Void

	@ObservedObject private var mic = Microphone.instance
	@State private var isShowSettingsAlert = false
	
	public init(content: () -> Content) {
		self.content = content()
		self.action = { }
	}
	
	public var body: some View {
		if content is EmptyView {
			AsyncButton(action: {
				if TapeDeckPermissions.instance.isDenied {
					isShowSettingsAlert = true
					
				} else {
					try? await action()
				}
			}) {
				Image(systemName: mic.isListening ? "mic.circle" : "mic.slash.circle")
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
			content
		}
	}
	
}



extension TapeDeckRecordButton where Content == EmptyView {
	public init(action: @escaping () async throws -> Void) {
		self.content = EmptyView()
		self.action = { }
	}
}
