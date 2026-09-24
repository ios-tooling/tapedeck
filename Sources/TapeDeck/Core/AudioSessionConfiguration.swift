//
//  AudioSessionConfiguration.swift
//  TapeDeck
//
//	 How the shared microphone configures the iOS audio session. Platform-neutral
//	 so it can be set from cross-platform code; only iOS acts on it.
//
//	 `.measurement` selects the `.record` category with `.measurement` mode, which
//	 disables automatic gain control so meter levels reflect true dynamic range —
//	 required for level-based detection (e.g. loudness / disturbance monitoring).
//
//	 `.alongsideOtherAudio` records while other apps keep playing, over the speaker or
//	 Bluetooth. It never takes input from a Bluetooth headset: doing so switches the
//	 headset to its call profile and drops everyone's playback to call quality.
//
//  Created by Ben Gottlieb on 6/21/26.
//

import Foundation

public struct AudioSessionConfiguration: Sendable, Equatable {
	public enum Category: Sendable { case playAndRecord, record }
	public enum Mode: Sendable { case `default`, measurement }

	public var category: Category
	public var mode: Mode
	public var defaultToSpeaker: Bool
	// allow a Bluetooth headset's mic (HFP); when false, input stays on the built-in mic
	public var allowsBluetoothInput: Bool

	public init(category: Category, mode: Mode = .default, defaultToSpeaker: Bool = true, allowsBluetoothInput: Bool = true) {
		self.category = category
		self.mode = mode
		self.defaultToSpeaker = defaultToSpeaker
		self.allowsBluetoothInput = allowsBluetoothInput
	}

	// the historical default: playback + record, routed to the speaker
	public static let playback = AudioSessionConfiguration(category: .playAndRecord, mode: .default, defaultToSpeaker: true)

	// AGC disabled for accurate level measurement
	public static let measurement = AudioSessionConfiguration(category: .record, mode: .measurement, defaultToSpeaker: false)

	// records without silencing other apps; the record-only category always silences them
	public static let alongsideOtherAudio = AudioSessionConfiguration(category: .playAndRecord, mode: .default, defaultToSpeaker: true, allowsBluetoothInput: false)
}
