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

		// Configuration-time sanity check: warn early if the host forgot the usage strings.
		#if DEBUG
			warnAboutMissingUsageDescriptions()
		#endif
	}

	@discardableResult public func requestMicrophone() async -> Bool {
		if microphone == .granted { return true }

		#if DEBUG
			guard Self.hasUsageDescription("NSMicrophoneUsageDescription", requesting: "microphone") else { microphone = .denied; return false }
		#endif

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

		#if DEBUG
			guard Self.hasUsageDescription("NSSpeechRecognitionUsageDescription", requesting: "speech recognition") else { speechRecognition = .denied; return false }
		#endif

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

	#if DEBUG
		private static var warnedKeys: Set<String> = []

		private func warnAboutMissingUsageDescriptions() {
			_ = Self.hasUsageDescription("NSMicrophoneUsageDescription", requesting: "microphone")
			_ = Self.hasUsageDescription("NSSpeechRecognitionUsageDescription", requesting: "speech recognition")
		}

		/// True if the Info.plist declares `key`. Otherwise shows a one-time alert — requesting
		/// the permission without it hard-crashes the app, so callers should skip the request.
		private static func hasUsageDescription(_ key: String, requesting purpose: String) -> Bool {
			if Bundle.main.object(forInfoDictionaryKey: key) != nil { return true }
			guard warnedKeys.insert(key).inserted else { return false }
			let message = "Your app's Info.plist is missing \(key).\n\nAdd it, or requesting \(purpose) access will crash the app."
			Task { @MainActor in presentTapeDeckSetupAlert(message) }
			return false
		}
	#endif
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

#if DEBUG
@MainActor private func presentTapeDeckSetupAlert(_ message: String) {
	#if canImport(UIKit)
		let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
		let window = scenes.first { $0.activationState == .foregroundActive }?.keyWindow ?? scenes.first?.keyWindow
		guard var top = window?.rootViewController else { return }
		while let presented = top.presentedViewController { top = presented }
		let alert = UIAlertController(title: "TapeDeck Setup", message: message, preferredStyle: .alert)
		alert.addAction(UIAlertAction(title: "OK", style: .default))
		top.present(alert, animated: true)
	#elseif canImport(AppKit)
		let alert = NSAlert()
		alert.messageText = "TapeDeck Setup"
		alert.informativeText = message
		alert.runModal()
	#endif
}
#endif
