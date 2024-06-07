//
//  Transcript.swift
//
//
//  Created by Ben Gottlieb on 9/8/23.
//

import Foundation
import AVFoundation

public class Transcript: Codable {
	var soundLevels: [SoundLevel] = []
	var segments: [Segment] = []
	var startDate = Date()
	var transcriptions: [Transcription] = []
	var recordedSoundLevelAt = Date.distantPast
	var soundLevelInterval = 1.0
	var duration: TimeInterval = 0
	var saveURL: URL
	
	static let transcriptFilename = "transcript"

	var isEmpty: Bool { segments.isEmpty }

	
	static func load(in url: URL) throws -> Transcript {
		let jsonURL = url.appendingPathComponent(transcriptFilename, conformingTo: .json)
		if let data = try? Data(contentsOf: jsonURL), let transcript = try? JSONDecoder().decode(Self.self, from: data) { return transcript }
		
		return Transcript(container: url)
	}
	
	init(forOutputURL url: URL) {
		saveURL = url.appendingPathComponent(Self.transcriptFilename, conformingTo: .json)
	}
	
	init(container url: URL) {
		saveURL = url.appendingPathComponent(Self.transcriptFilename, conformingTo: .json)
		Task { await self.load(url: url) }
	}
	
	func load(url: URL) async {
		do {
			let urls = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
			
			var offset: TimeInterval = 0
			let names = urls.map { $0.lastPathComponent }.sorted()
			
			for name in names {
				let fullURL = url.appendingPathComponent(name, conformingTo: .audio)
				if let duration = try await fullURL.audioDuration {
					segments.append(.init(offset: offset, filename: name, samples: 0))
					offset += duration
				}
			}
			self.duration = offset
		} catch {
			print("Transcript load failed: \(error)")
		}
	}
	
	func save() {
		try? FileManager.default.removeItem(at: saveURL)
		do {
			let data = try JSONEncoder().encode(self)
			try data.write(to: saveURL)
		} catch {
			print("Problem writing transcript: \(error)")
		}
	}
	
	func beginTranscribing() {
		startDate = Date()
	}
	
	func endTranscribing() {
		duration = Date().timeIntervalSince(startDate)
	}
	
	public func transcribed(text: String, at date: Date) {
		guard !text.isEmpty else { return }
		
		transcriptions.append(.init(text: text, date: date))
		save()
	}
	
	func recordSoundLevel(_ volume: Volume) {
		let now = Date()
		if now.timeIntervalSince(recordedSoundLevelAt) > soundLevelInterval {
			recordedSoundLevelAt = now
			soundLevels.append(.init(offset: now.timeIntervalSince(startDate), level: volume.unit))
		}
	}
	
	func addSegment(start: TimeInterval, filename: String, samples: Int) {
		segments.append(.init(offset: start, filename: filename, samples: samples))
	}
	
	struct Segment: Codable {
		let offset: TimeInterval
		let filename: String
		let samples: Int
		
		func url(basedOn base: URL) -> URL { base.appendingPathComponent(filename).appendingPathExtension("m4a") }
		func playerItem(basedOn base: URL) -> AVPlayerItem { AVPlayerItem(url: url(basedOn: base)) }
	}
	
	struct SoundLevel: Codable {
		let offset: TimeInterval
		let level: Double
	}
	
	struct Transcription: Codable {
		let text: String
		let date: Date
	}
}
