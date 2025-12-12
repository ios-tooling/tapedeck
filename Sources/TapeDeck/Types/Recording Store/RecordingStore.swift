//
//  RecordingStore.swift
//
//
//  Created by Ben Gottlieb on 8/13/23.
//

#if os(iOS)
import Foundation
import CoreAudio
import SwiftUI
import Suite
import AVFoundation

public class RecordingStore: ObservableObject {
	public static let instance = RecordingStore()
	
	public var recordings: [SavedRecording] = []
	var externalRecordings: [SavedRecording] = []
	public static var silenceDbThreshold: Float { return -50.0 } // everything below -50 dB will be clipped
	
	public private(set) var mainRecordingDirectory = FileManager.libraryDirectory
	public var extraDirectories: [URL] = []
	var cancellables: Set<AnyCancellable> = []
	
	public func setup(root: URL) {
		if mainRecordingDirectory == root { return }
		mainRecordingDirectory = root
		updateRecordings()
	}
	
	public var fileExtensions = [Recorder.AudioFileType.m4a.fileExtension, Recorder.AudioFileType.wav16k.fileExtension, Recorder.AudioFileType.mp3.fileExtension, RecordingPackage.fileExtension]
	
	public func updateRecordings() {
		var recordings: [SavedRecording] = []
		
		let sources = [self.mainRecordingDirectory] + extraDirectories
		
		for url in sources {
			try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
			guard let urls = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { continue }
			
			let filtered = urls.filter { fileExtensions.contains($0.pathExtension) }
			recordings += filtered.map { SavedRecording(url: $0) }
		}
		
		self.recordings = (recordings + externalRecordings).sorted()
		objectWillChange.sendOnMain()
	}
	
	init() {
		Recorder.instance.objectWillChange
			.sink { [weak self] _ in
				self?.objectWillChange.sendOnMain()
			}
			.store(in: &cancellables)
	}
	
	public func delete(recording: SavedRecording) {
		if let index = recordings.firstIndex(of: recording) {
			recordings.remove(at: index)
			recording.delete()
			objectWillChange.send()
		}
	}
	
	public func addDirectory(_ url: URL) {
		if !extraDirectories.contains(url) { extraDirectories.append(url) }
		updateRecordings()
	}
	
	public func addAudio(at url: URL) {
		externalRecordings.append(SavedRecording(url: url))
		self.updateRecordings()
	}
	
	public func addAudio(at urls: [URL]) {
		urls.forEach {
			externalRecordings.append(SavedRecording(url: $0))
		}
		self.updateRecordings()
	}
	
	func didStartRecording(to output: RecorderOutput?) {
		if let url = output?.containerURL {
			replace(SavedRecording(url: url, transcript: Recorder.instance.activeTranscript))
		}
		self.objectWillChange.sendOnMain()
		RecordingStore.Notifications.didStartRecording.notify()
	}
	
	func didEndRecording(to output: RecorderOutput?) {
		RecordingStore.Notifications.didEndRecording.notify()
	}
	
	func didFinishPostRecording(to output: RecorderOutput?) {
		objectWillChange.sendOnMain()
		RecordingStore.Notifications.didEndPostRecording.notify()
	}
	
	func replace(_ recording: SavedRecording) {
		if let index = recordings.firstIndex(where: { $0.url.isSameFile(as: recording.url) }) {
			recordings[index] = recording
		} else {
			recordings.append(recording)
		}
	}
}
#endif
