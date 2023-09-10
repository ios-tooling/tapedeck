//
//  RecordingPackage.swift
//  
//
//  Created by Ben Gottlieb on 1/3/21.
//

import Foundation
import AVFoundation

public class RecordingPackage {
	public let url: URL
	
	public var recording: OutputSegmentedRecording!
	public static var fileExtension = "recording"
	public var levelSummary: LevelsSummary?
	
	public var timeFrameString: String? { levelSummary?.timeFrameString }

	public init?(url: URL, bufferDuration: TimeInterval = 60) {
		self.url = url.deletingPathExtension().appendingPathExtension(Self.fileExtension)
		try? FileManager.default.createDirectory(at: soundFilesURL, withIntermediateDirectories: true, attributes: nil)
		levelSummary = try? LevelsSummary.loadJSON(file: levelsURL)
		recording = OutputSegmentedRecording(in: soundFilesURL, bufferDuration: 60)
	}
	
	public var startedAt: Date? { levelSummary?.startedAt }
	
	let levelsFileName = "levels.json"
	let soundsDirectoryName = "sounds"
	
	var levelsURL: URL { url.appendingPathComponent(levelsFileName) }
	var soundFilesURL: URL { url.appendingPathComponent(soundsDirectoryName) }
	
	public func start() async throws {
		try await Recorder.instance.startRecording(to: recording)
	}
	
	public func stop() async throws {
		do {
			try Recorder.instance.levelsSummary.save(to: levelsURL)
			try await Recorder.instance.stop()
		} catch {
			try? await Recorder.instance.stop()
			throw error
		}

	}
}

extension RecordingPackage: RecorderOutput {
	public func prepareToRecord() async throws {
		try await recording.prepareToRecord()
	}

	public func handle(buffer: CMSampleBuffer) {
		recording.handle(buffer: buffer)
	}

	public func endRecording() async throws {
		try await recording.endRecording()
	}
	
	public var containerURL: URL? { recording.containerURL }

}
