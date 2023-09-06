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

public class SavedRecording: ObservableObject, Identifiable, Equatable, CustomStringConvertible, Comparable {
	public let url: URL
	public var startedAt: Date = Date()
	public var id: URL { url }
	public var duration: TimeInterval?
	public var runningDuration: TimeInterval? {
		if isActive { return Date().timeIntervalSince(startedAt) }
		return nil
	}
	public var isPackage: Bool { url.pathExtension == RecordingPackage.fileExtension }
	
	public var title: String {
		url.pathExtension.fileExtensionToName + " recorded at \(startedAt.localTimeString(date: .none, time: .short))"
	}
	
	public var isPlaying: Bool { RecordingPlayer.instance.current == self }
	
	public func togglePlaying() {
		if isPlaying {
			stopPlayback()
		} else {
			startPlayback()
		}
	}
	
	public var isActive: Bool {
		if !Recorder.instance.isRecording { return false }
		return Recorder.instance.output?.containerURL?.deletingPathExtension().lastPathComponent == url.deletingPathExtension().lastPathComponent
	}
	
	public static func <(lhs: SavedRecording, rhs: SavedRecording) -> Bool {
		lhs.startedAt < rhs.startedAt
	}
	
	init(url: URL) {
		self.url = url
		
		startedAt = url.createdAt ?? startedAt
		if url.pathExtension != RecordingPackage.fileExtension {
			Task {
				let asset = AVURLAsset(url: url, options: nil)
				
				if #available(iOS 15, *) {
					do {
						let cmtime = try await asset.load(.duration)
						duration = cmtime.seconds
						objectWillChange.sendOnMain()
					} catch {
						print("Failed to load asset: \(error) at \(url.path)")
					}
				}
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