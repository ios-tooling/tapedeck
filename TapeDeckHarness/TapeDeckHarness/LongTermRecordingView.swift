//
//  LongTermRecordingView.swift
//  TapeDeckHarness
//
//  Created by Ben Gottlieb on 10/12/24.
//

import Suite
import TapeDeck
import FileBrowser

struct LongTermRecordingView: View {
	let root = URL.documents
	@State var url: URL?
	@State var recording: OutputSegmentedRecording?
	@ObservedObject var recorder = Recorder.instance
	@State var fileBrowserURL: URL?
	@State var listingRecordings = false
	
	func start() async throws {
		_ = try? await Microphone.instance.stop()
		try? await Task.sleep(for: .seconds(0.2))
 
		url = root.appendingPathComponent(Date.now.formatted(.iso8601).replacingOccurrences(of: ":", with: ";"))
		
		recording = OutputSegmentedRecording(in: url!, outputType: .m4a, bufferDuration: 5)
		try await recorder.startRecording(to: recording!)
	}
	
	func stop() async throws {
		try await recorder.stop()
		recording = nil
	}
	
	var body: some View {
		HStack {
			Button("Files") { fileBrowserURL = root }
			.fullScreenCover(item: $fileBrowserURL) { url in
				FileBrowserView(root: url)
			}
			
			Button("Recordings") { listingRecordings.toggle() }
				.sheet(isPresented: $listingRecordings) { RecordingList(url: root, selectedRecording: $recording) }
		}
		
		SoundLevelsView(verticallyCentered: true, segmentWidth: 1, spacerWidth: 2)
			.frame(height: 200)
			.task { _ = try? await Microphone.instance.start() }
		
		if let recording {
			HStack {
				Text("Recording")
			}
			AsyncButton(action: {
				try await stop()
				try? await Task.sleep(for: .seconds(0.2))
				_ = try? await Microphone.instance.start()
			}) {
				Image(systemName: "stop.circle.fill")
					.foregroundStyle(.red)
			}
			
			SegmentedRecordingFileList(recording: recording)
			
		} else {
			Text("Start Recording")
			AsyncButton(action: { try await start() }) {
				Image(systemName: "circle.fill")
					.foregroundStyle(.red)
			}
		}
	}
}

#Preview {
	LongTermRecordingView()
}
