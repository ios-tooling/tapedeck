//
//  AudioSession.swift
//  TapeDeck
//
//	 Ref-counted AVAudioSession activation, iOS only. macOS has no session concept.
//
//  Created by Ben Gottlieb on 6/11/26.
//

#if os(iOS)
import AVFoundation

@MainActor final class AudioSession {
	static let instance = AudioSession()

	var defaultToSpeaker = true

	private let session = AVAudioSession.sharedInstance()
	private var activeCount = 0

	func activate() throws {
		activeCount += 1
		guard activeCount == 1 else { return }

		var options: AVAudioSession.CategoryOptions = [.allowBluetoothA2DP, .allowBluetoothHFP, .overrideMutedMicrophoneInterruption, .mixWithOthers]
		if defaultToSpeaker { options.insert(.defaultToSpeaker) }

		try session.setCategory(.playAndRecord, options: options)
		try session.setActive(true)
	}

	func deactivate() {
		guard activeCount > 0 else { return }
		activeCount -= 1

		if activeCount == 0 {
			try? session.setActive(false, options: .notifyOthersOnDeactivation)
		}
	}
}
#endif
