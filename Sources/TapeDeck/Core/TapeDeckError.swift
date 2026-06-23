//
//  TapeDeckError.swift
//  TapeDeck
//
//  Created by Ben Gottlieb on 6/11/26.
//

import Foundation

public enum TapeDeckError: Error, Sendable {
	case microphonePermissionDenied
	case speechRecognitionPermissionDenied
	case alreadyRecording
	case notRecording
	case notPaused
	case audioEngineUnavailable
	case unsupportedAudioFormat
	case transcriptionUnavailable
	case transcriptionAssetsUnavailable
	case fileNotFound(URL)
	case exportRangeOutOfBounds
	case exportFailed
}
