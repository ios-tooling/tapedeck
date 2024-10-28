//
//  SavedRecording.swift
//
//
//  Created by Ben Gottlieb on 9/1/23.
//

import Foundation
import CoreAudio
import SwiftUI
import Suite
import AVFoundation
import Journalist

public class SavedRecording: ObservableObject, Identifiable, Equatable, CustomStringConvertible, Comparable {
	public let url: URL
	public var startedAt: Date = Date()
	public var id: URL { url }
	public var duration: TimeInterval? { transcript?.duration }
	public var state: State = .ready
	
	public enum State { case preparing, ready, playing }
	
	var transcript: Transcript!
	var currentSegmentIndex = 0
	weak var playbackTimer: Timer?
	public var playbackStartedAt: Date?
	public var playbackProgress: Double? {
		guard let playbackStartedAt, let duration else { return nil }
		
		return (Date().timeIntervalSince(playbackStartedAt) / duration)
	}
	
	public var runningDuration: TimeInterval? {
		get async {
			if let playbackStartedAt { return Date().timeIntervalSince(playbackStartedAt) }
			if await isActive { return Date().timeIntervalSince(startedAt) }
			return nil
		}
	}
	
	public var isPackage: Bool { url.pathExtension == RecordingPackage.fileExtension }
	
	public var title: String {
		url.pathExtension.fileExtensionToName + " recorded at \(startedAt.localTimeString(date: .none, time: .short))"
	}
		
	public func togglePlaying() {
		if state == .playing {
			stopPlayback()
		} else {
			report { try self.startPlayback() }
		}
	}
	
	public var isActive: Bool {
		get async {
			if await !Recorder.instance.isRecording { return false }
			return await Recorder.instance.output?.containerURL?.deletingPathExtension().lastPathComponent == url.deletingPathExtension().lastPathComponent
		}
	}
	
	public static func <(lhs: SavedRecording, rhs: SavedRecording) -> Bool {
		lhs.startedAt < rhs.startedAt
	}
	
	func loadSegments() async {
		do {
			state = .preparing
			transcript = try Transcript.load(in: url)
			state = .ready
		} catch {
			print("Failed to load segments: \(error)")
		}
	}
	
	public init(url: URL, transcript: Transcript? = nil) {
		self.url = url
		self.transcript = transcript
		
		startedAt = url.createdAt ?? startedAt
		if isPackage {
			Task {
				if transcript == nil { await loadSegments() }
				objectWillChange.sendOnMain()
			}
		}
	}
	
	public var description: String {
		let filename = url.pathExtension.fileExtensionToName + " recorded at \(startedAt.localTimeString(date: .none, time: .short))"

		var desc = isPackage ? "Recording package: \(filename)" : filename
		
		if let duration {
			desc += " " + duration.durationString(style: .centiseconds, showLeadingZero: true, roundUp: true)
		}
		
		return desc
}
	
	public var package: RecordingPackage? {
		guard isPackage else { return nil }
		return RecordingPackage(url: url)
	}
	
	public static func ==(lhs: SavedRecording, rhs: SavedRecording) -> Bool { lhs.url == rhs.url }
	
	func delete() {
		try? FileManager.default.removeItem(at: url)
	}
}

extension String {
	var fileExtensionToName: String {
		switch self.lowercased() {
		case RecordingPackage.fileExtension: return "Packaged Audio"
			
		case "m4a": return "MPEG-4"
			
		default:
			return self
		}
	}
}
