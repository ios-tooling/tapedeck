//
//  TapeDeckPermissions.swift
//  TapeDeck
//
//  Created by Ben Gottlieb on 6/10/26.
//

import Suite
import AVFoundation
import Speech

@MainActor @Observable public class TapeDeckPermissions {
	public static let instance = TapeDeckPermissions()
	
	public var hasRecordingPermissions: Bool?
	public var hasTranscriptionPermissions: Bool?
	public var notYetAuthorized: Bool { hasRecordingPermissions != true || hasTranscriptionPermissions != true }
	public var isDenied: Bool { hasRecordingPermissions == false || hasTranscriptionPermissions == false }

	
	var cancellables: Set<AnyCancellable> = []
	init() {
		updatePermissions()
		UIApplication.willEnterForegroundNotification.publisher()
			.receive(on: RunLoop.main)
			.sink { _ in
				self.updatePermissions()
			}
			.store(in: &cancellables)
	}
	
	public func requestRecordingPermissions() async -> Bool {
		if hasRecordingPermissions == true { return true }
		if Gestalt.isOnSimulator { return false }

		hasRecordingPermissions = await AVAudioApplication.requestRecordPermission()
		updatePermissions()
		return hasRecordingPermissions == true
	}

	public func requestTranscriptionPermission() async -> Bool {
		if SFSpeechRecognizer.authorizationStatus() == .authorized {
			hasTranscriptionPermissions = true
			return true
		}

		return await withCheckedContinuation { continuation in
			SFSpeechRecognizer.requestAuthorization { status in
				self.hasTranscriptionPermissions = status == .authorized
				self.updatePermissions()
				continuation.resume(returning: self.hasTranscriptionPermissions == true)
			}
		}
	}
	
	func receivedPermissionsError() {
		updatePermissions()
	}
	
	func updatePermissions() {
		switch AVAudioApplication.shared.recordPermission {
		case .granted: hasRecordingPermissions = true
		case .denied: hasRecordingPermissions = false
		case .undetermined: break
		}
		
		switch SFSpeechRecognizer.authorizationStatus() {
		case .authorized: hasTranscriptionPermissions = true
		case .notDetermined: break
		case .denied: hasTranscriptionPermissions = false
		case .restricted: hasTranscriptionPermissions = false
		@unknown default:
			break
		}
		
		print("Permissions Updated: Record: \(hasRecordingPermissions, default: "--") Transcription: \(hasTranscriptionPermissions, default: "--")")
		
	}

}
