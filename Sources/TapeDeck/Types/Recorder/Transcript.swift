//
//  Transcript.swift
//
//
//  Created by Ben Gottlieb on 9/8/23.
//

import Suite
import AVFoundation

public class Transcript: Codable, Identifiable, CustomStringConvertible {
	public var soundLevels: [SoundLevel] = []
	public var segments: [Segment] = []
	public var startDate = Date()
	public var transcriptions: [Transcription] = []
	public var recordedSoundLevelAt = Date.distantPast
	public var soundLevelInterval = 1.0
	public var duration: TimeInterval = 0
	public var saveURL: URL
	
	public var id: URL { saveURL }
	
	static let transcriptFilename = "transcript"

	var isEmpty: Bool { segments.isEmpty }
	public var description: String {
		duration.durationString(style: .minutes, showLeadingZero: true)
	}
	
	public func deleteRecording() throws {
		try FileManager.default.removeItem(at: saveURL.deletingLastPathComponent())
	}
	
	public static func load(in url: URL) throws -> Transcript {
		let jsonURL = url.appendingPathComponent(transcriptFilename, conformingTo: .json)
		if let data = try? Data(contentsOf: jsonURL), var transcript = try? JSONDecoder().decode(Self.self, from: data) {
			transcript.saveURL = jsonURL
			return transcript
		}
		
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
	
	public struct Segment: Codable {
		public let offset: TimeInterval
		public let filename: String
		public let samples: Int
		
		func url(basedOn base: URL) -> URL { base.appendingPathComponent(filename).appendingPathExtension("m4a") }
		func playerItem(basedOn base: URL) -> AVPlayerItem { AVPlayerItem(url: url(basedOn: base)) }
	}
	
	public struct SoundLevel: Codable {
		public let offset: TimeInterval
		public let level: Double
	}
	
	public struct Transcription: Codable {
		public let text: String
		public let date: Date
	}
}
