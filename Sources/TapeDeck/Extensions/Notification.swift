//
//  Notification.swift
//
//
//  Created by Ben Gottlieb on 8/13/23.
//

#if os(iOS)
import Foundation
import AVFoundation

public extension Notification {
	var interruptionReason: AVAudioSession.InterruptionReason? {
		if #available(iOS 14.5, *) {
			guard let rawValue = userInfo?[AVAudioSessionInterruptionReasonKey] as? UInt else { return nil }
			return AVAudioSession.InterruptionReason(rawValue: rawValue)
		} else {
			return nil
		}
	}

	var interruptionType: AVAudioSession.InterruptionType? {
		guard let rawValue = userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt else { return nil }
		return AVAudioSession.InterruptionType(rawValue: rawValue)
	}
}
#endif
