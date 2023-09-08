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
	public var duration: TimeInterval?
	public var state: State = .ready
	
	public enum State { case preparing, ready, playing }
	
	var segmentInfo: [SegmentPlaybackInfo] = []
	var currentSegmentIndex = 0
	weak var playbackTimer: Timer?
	public var playbackStartedAt: Date?
	
	public var runningDuration: TimeInterval? {
		if let playbackStartedAt { return Date().timeIntervalSince(playbackStartedAt) }
		if isActive { return Date().timeIntervalSince(startedAt) }
		return nil
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
		if !Recorder.instance.isRecording { return false }
		return Recorder.instance.output?.containerURL?.deletingPathExtension().lastPathComponent == url.deletingPathExtension().lastPathComponent
	}
	
	public static func <(lhs: SavedRecording, rhs: SavedRecording) -> Bool {
		lhs.startedAt < rhs.startedAt
	}
	
	func loadSegments() async {
		do {
			state = .preparing
			segmentInfo = try buildSegmentPlaybackInfo()
			duration = segmentInfo.map { $0.duration }.sum()
			state = .ready
		} catch {
			print("Failed to load segments: \(error)")
		}
	}
	
	init(url: URL) {
		self.url = url
		
		startedAt = url.createdAt ?? startedAt
		if isPackage {
			Task {
				await loadSegments()
				objectWillChange.sendOnMain()
			}
		} else {
			duration = url.audioDuration
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
