//
//  File.swift
//  TapeDeck
//
//  Created by Ben Gottlieb on 6/10/26.
//

import Suite


public struct TapeDeckPermissionsView: View {
	let permissions = TapeDeckPermissions.instance
	
	public init() { }
	
	public var body: some View {
		HStack {
			if let recording = permissions.hasRecordingPermissions {
				Image(systemName: recording ? "microphone" : "microphone.slash")
					.foregroundStyle(recording ? Color.primary : Color.red)
			} else {
				Image(systemName: "microphone")
					.opacity(0.23)
			}
		}

		if let recording = permissions.hasTranscriptionPermissions {
			Image(systemName: recording ? "bubble.left" : "exclamationmark.bubble")
				.foregroundStyle(recording ? Color.primary : Color.red)
		} else {
			Image(systemName: "bubble.left")
				.opacity(0.23)
		}
	}
}
