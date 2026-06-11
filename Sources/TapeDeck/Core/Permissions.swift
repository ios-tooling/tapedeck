//
//  Permissions.swift
//  TapeDeck
//
//	 Microphone and speech recognition permission requests. Each subsystem calls
//	 these automatically on start; apps can also call them explicitly up front.
//
//  Created by Ben Gottlieb on 6/11/26.
//

import AVFoundation
import Speech

public enum Permissions {
	public static var hasMicrophonePermission: Bool {
		#if os(iOS)
			AVAudioApplication.shared.recordPermission == .granted
		#else
			AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
		#endif
	}

	public static var hasSpeechRecognitionPermission: Bool {
		SFSpeechRecognizer.authorizationStatus() == .authorized
	}

	@discardableResult public static func requestMicrophone() async -> Bool {
		if hasMicrophonePermission { return true }

		#if os(iOS)
			return await AVAudioApplication.requestRecordPermission()
		#else
			return await AVCaptureDevice.requestAccess(for: .audio)
		#endif
	}

	@discardableResult public static func requestSpeechRecognition() async -> Bool {
		if hasSpeechRecognitionPermission { return true }

		return await withCheckedContinuation { continuation in
			SFSpeechRecognizer.requestAuthorization { status in
				continuation.resume(returning: status == .authorized)
			}
		}
	}
}
