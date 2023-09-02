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
import AVFoundation

public class RecordingStore: ObservableObject {
	public static let instance = RecordingStore()
	
	public var recordings: [Recording] = []
	var externalRecordings: [Recording] = []
	public static var silenceDbThreshold: Float { return -50.0 } // everything below -50 dB will be clipped
	
	public private(set) var mainRecordingDirectory = FileManager.documentsDirectory
	public var extraDirectories: [URL] = []
	var cancellables: Set<AnyCancellable> = []
	
	public func setup(root: URL) {
		if mainRecordingDirectory == root { return }
		mainRecordingDirectory = root
		updateRecordings()
	}
	
	public var fileExtensions = [Recorder.AudioFileType.m4a.fileExtension, Recorder.AudioFileType.wav.fileExtension, Recorder.AudioFileType.mp3.fileExtension, RecordingPackage.fileExtension]
	
	public func updateRecordings() {
		var recordings: [Recording] = []
		
		do {
			for url in [self.mainRecordingDirectory] + extraDirectories {
				try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
				let urls = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]).filter { fileExtensions.contains($0.pathExtension) }
				recordings += urls.map { Recording(url: $0) }
			}
			
			self.recordings = (recordings + externalRecordings).sorted()
		} catch {
			logg(error: error, "Error when loading recordings: \(error)")
		}
		objectWillChange.sendOnMain()
	}
	
	init() {
		Recorder.instance.objectWillChange
			.sink { [weak self] _ in
				self?.objectWillChange.sendOnMain()
			}
			.store(in: &cancellables)
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
	
	public func addAudio(at urls: [URL]) {
		urls.forEach {
			externalRecordings.append(Recording(url: $0))
		}
		self.updateRecordings()
	}
	
	func didStartRecording() {
		updateRecordings()
	}
	
	func didEndRecording() {
		objectWillChange.sendOnMain()
	}
	
	func didFinishPostRecording() {
		updateRecordings()
		objectWillChange.sendOnMain()
	}
}
