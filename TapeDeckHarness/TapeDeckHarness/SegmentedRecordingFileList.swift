//
//  SegmentedRecordingFileList.swift
//  TapeDeckHarness
//
//  Created by Ben Gottlieb on 10/13/24.
//

import SwiftUI
import TapeDeck

public struct SegmentedRecordingFileList: View {
	@ObservedObject var recording: OutputSegmentedRecording
	@State var chunks: [SegmentedRecordingChunkInfo] = []
	
	func updateChunks() async {
		chunks = await recording.recordingChunks
	}
	
	public var body: some View {
		List {
			ForEach(chunks) { chunk in
				Button(action: { chunk.play() }) {
					Text(chunk.timeDescription)
				}
			}
		}
		.task {
			await updateChunks()
		}
		.onReceive(recording.objectWillChange) { _ in
			Task { await updateChunks() }
		}
	}
}
