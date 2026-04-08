//
//  RecordingPackage.swift
//  
//
//  Created by Ben Gottlieb on 1/3/21.
//

#if os(iOS)
import Foundation
import AVFoundation

public actor RecordingPackage {
	public let url: URL
	
	public var recording: OutputSegmentedRecording!
	public static var fileExtension = "recording"
	public var levelSummary: LevelsSummary?
	
	public var timeFrameString: String? { levelSummary?.timeFrameString }
	
	public let containerURL: URL?

	public init?(url: URL, bufferDuration: TimeInterval = 60) {
		self.url = url.deletingPathExtension().appendingPathExtension(Self.fileExtension)
		containerURL = url.soundFilesURL
		try? FileManager.default.createDirectory(at: url.soundFilesURL, withIntermediateDirectories: true, attributes: nil)
		levelSummary = try? LevelsSummary.loadJSON(file: url.levelsURL)
		recording = OutputSegmentedRecording(in: url.soundFilesURL, bufferDuration: 60)
	}
	
	public var startedAt: Date? { levelSummary?.startedAt }
	
	let levelsFileName = "levels.json"
	let soundsDirectoryName = "sounds"
		
	public func start() async throws {
		try await Recorder.instance.startRecording(to: recording)
	}
	
	public func stop() async throws {
		do {
			try await Recorder.instance.levelsSummary.save(to: url.levelsURL)
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

	public func handle(buffer: CMSampleBuffer) async {
		await recording.handle(buffer: buffer)
	}

	public func endRecording() async throws -> URL? {
		_ = try await recording.endRecording()
		return containerURL
	}
}

fileprivate extension URL {
	var levelsURL: URL { appendingPathComponent("levels.json") }
	var soundFilesURL: URL { appendingPathComponent("sounds") }
}
#endif
