//
//  SegmentedRecordingFileList.swift
//  TapeDeckHarness
//
//  Created by Ben Gottlieb on 10/13/24.
//

import Suite
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
				Row(chunk: chunk)
			}
		}
		.task {
			await updateChunks()
		}
		.onChange(of: recording) {
			Task { await updateChunks() }
		}
		.onReceive(recording.objectWillChange) { _ in
			Task { await updateChunks() }
		}
	}
	
	struct Row: View {
		let chunk: SegmentedRecordingChunkInfo
		
		var body: some View {
			Button(action: {
					chunk.play()
			}) {
				VStack {
					Text(chunk.timeDescription)
					BarLevelsView(url: chunk.url)
				}
			}
		}
		
	}
}
