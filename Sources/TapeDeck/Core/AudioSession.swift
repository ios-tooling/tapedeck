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

	private let session = AVAudioSession.sharedInstance()
	private var activeCount = 0

	func activate(_ configuration: AudioSessionConfiguration) throws {
		activeCount += 1
		guard activeCount == 1 else { return }

		// A2DP and defaultToSpeaker are output-only options — valid only with a
		// playback-capable category. Including them with `.record` returns OSStatus -50.
		var options: AVAudioSession.CategoryOptions = [.allowBluetoothHFP, .overrideMutedMicrophoneInterruption, .mixWithOthers]
		if configuration.category == .playAndRecord {
			options.insert(.allowBluetoothA2DP)
			if configuration.defaultToSpeaker { options.insert(.defaultToSpeaker) }
		}

		try session.setCategory(configuration.category.avCategory, mode: configuration.mode.avMode, options: options)
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

private extension AudioSessionConfiguration.Category {
	var avCategory: AVAudioSession.Category {
		switch self {
		case .playAndRecord: .playAndRecord
		case .record: .record
		}
	}
}

private extension AudioSessionConfiguration.Mode {
	var avMode: AVAudioSession.Mode {
		switch self {
		case .default: .default
		case .measurement: .measurement
		}
	}
}
#endif
