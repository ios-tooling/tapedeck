//
//  File.swift
//  
//
//  Created by Ben Gottlieb on 9/2/23.
//

#if os(iOS)
import Foundation

extension RecordingStore {
	public struct Notifications {
		public static let didStartRecording = Notification.Name("TapeDeck.RecordingStore.didStartRecording")
		public static let didEndRecording = Notification.Name("TapeDeck.RecordingStore.didEndRecording")
		public static let didEndPostRecording = Notification.Name("TapeDeck.RecordingStore.didEndPostRecording")
	}
}
#endif
