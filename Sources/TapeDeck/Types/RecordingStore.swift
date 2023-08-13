//
//  RecordingStore.swift
//  
//
//  Created by Ben Gottlieb on 8/13/23.
//

import Foundation
import CoreAudio
import SwiftUI
import Suite

public class RecordingStore: ObservableObject {
	public static let instance = RecordingStore()
	
	@Published public var recordings: [Recording] = []
	var externalRecordings: [Recording] = []
	public static var silenceDbThreshold: Float { return -50.0 } // everything below -50 dB will be clipped

	public var mainRecordingDirectory = FileManager.documentsDirectory { didSet { self.setupCurrentRecordings() }}
	public var extraDirectories: [URL] = []
	
	public var fileExtensions = [Recorder.AudioFileType.m4a.fileExtension, Recorder.AudioFileType.wav.fileExtension, Recorder.AudioFileType.mp3.fileExtension, RecordingPackage.fileExtension]
	
	public func updateRecordings() {
		var recordings: [Recording] = []
		
		do {
			for url in [self.mainRecordingDirectory] + extraDirectories {
				try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
				let urls = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]).filter { fileExtensions.contains($0.pathExtension) }
				recordings += urls.map { Recording(url: $0) }
			}
			
			self.recordings = recordings + externalRecordings
		} catch {
			logg(error: error, "Error when loading recordings: \(error)")
		}
	}
	
	init() {
		self.updateRecordings()
	}
	
	public func delete(recording: Recording) {
		if let index = recordings.firstIndex(of: recording) {
			recordings.remove(at: index)
			recording.delete()
		}
	}
	
	public func addDirectory(_ url: URL) {
		if !extraDirectories.contains(url) { extraDirectories.append(url) }
		updateRecordings()
	}
	
	public func addAudio(at url: URL) {
		externalRecordings.append(Recording(url: url))
		self.updateRecordings()
	}
	
	public class Recording: Identifiable, Equatable {
		public let url: URL
		public var id: URL { url }
		public var isPackage: Bool { url.pathExtension == RecordingPackage.fileExtension }
		
		public var name: String { url.lastPathComponent }
		
		init(url: URL) {
			self.url = url
		}
		
		public var package: RecordingPackage? {
			guard isPackage else { return nil }
			return RecordingPackage(url: url)
		}

		public static func ==(lhs: Recording, rhs: Recording) -> Bool { lhs.url == rhs.url }
		
		func delete() {
			try? FileManager.default.removeItem(at: url)
		}
	}
	
	public func addAudio(at urls: [URL]) {
		urls.forEach {
			externalRecordings.append(Recording(url: $0))
		}
		self.updateRecordings()
	}
	
	func setupCurrentRecordings() {
//		do {
//			try FileManager.default.createDirectory(at: self.mainRecordingDirectory, withIntermediateDirectories: true, attributes: nil)
//			let urls = try FileManager.default.contentsOfDirectory(at: self.mainRecordingDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
//			self.recordings = urls.map { AudioAnalysis(url: $0, andLoadSampleCount: 2000, range: 0...10) }
//		} catch {
//		}
	}
}
