//
//  TapeDeckPermissions.swift
//  TapeDeck
//
//	 Observable record of every permission the framework uses — what's been
//	 requested, granted, and denied. Refreshes from system state when the app
//	 returns to the foreground, since users can change permissions in Settings.
//
//  Created by Ben Gottlieb on 6/12/26.
//

import AVFoundation
import Speech
#if canImport(UIKit)
	import UIKit
#else
	import AppKit
#endif

@MainActor @Observable public class TapeDeckPermissions {
	public static let instance = TapeDeckPermissions()

	public enum Status: Sendable, Equatable {
		case notDetermined, denied, granted
	}

	public private(set) var microphone = Status.notDetermined
	public private(set) var speechRecognition = Status.notDetermined

	public var allGranted: Bool { microphone == .granted && speechRecognition == .granted }
	public var isDenied: Bool { microphone == .denied || speechRecognition == .denied }
	public var notYetAuthorized: Bool { microphone != .granted || speechRecognition != .granted }

	init() {
		refresh()

		let name: Notification.Name
		#if canImport(UIKit)
			name = UIApplication.willEnterForegroundNotification
		#else
			name = NSApplication.willBecomeActiveNotification
		#endif
		NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { _ in
			Task { @MainActor in TapeDeckPermissions.instance.refresh() }
		}
	}

	@discardableResult public func requestMicrophone() async -> Bool {
		if microphone == .granted { return true }

		#if os(iOS)
			let granted = await AVAudioApplication.requestRecordPermission()
		#else
			let granted = await AVCaptureDevice.requestAccess(for: .audio)
		#endif

		microphone = granted ? .granted : .denied
		return granted
	}

	@discardableResult public func requestSpeechRecognition() async -> Bool {
		if speechRecognition == .granted { return true }

		let status = await Self.requestSpeechAuthorization()
		speechRecognition = Status(status)
		return speechRecognition == .granted
	}

	// `SFSpeechRecognizer.requestAuthorization` invokes its completion on a background
	// queue. Keeping the continuation in a `nonisolated` context avoids inheriting this
	// type's `@MainActor` isolation, which would trip the executor-isolation assertion
	// when the background callback resumes it.
	private nonisolated static func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
		await withCheckedContinuation { continuation in
			SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
		}
	}

	public func refresh() {
		#if os(iOS)
			switch AVAudioApplication.shared.recordPermission {
			case .granted: microphone = .granted
			case .denied: microphone = .denied
			case .undetermined: microphone = .notDetermined
			@unknown default: microphone = .notDetermined
			}
		#else
			switch AVCaptureDevice.authorizationStatus(for: .audio) {
			case .authorized: microphone = .granted
			case .denied, .restricted: microphone = .denied
			case .notDetermined: microphone = .notDetermined
			@unknown default: microphone = .notDetermined
			}
		#endif

		speechRecognition = Status(SFSpeechRecognizer.authorizationStatus())
	}
}

extension TapeDeckPermissions.Status {
	init(_ status: SFSpeechRecognizerAuthorizationStatus) {
		switch status {
		case .authorized: self = .granted
		case .denied, .restricted: self = .denied
		case .notDetermined: self = .notDetermined
		@unknown default: self = .notDetermined
		}
	}
}
