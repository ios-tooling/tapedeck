//
//  RecordingList.swift
//  TapeDeckHarness
//
//  Created by Ben Gottlieb on 10/13/24.
//

import Suite
import TapeDeck

struct RecordingList: View {
	let url: URL
	@Binding var selectedRecording: OutputSegmentedRecording?

	@State var recordingURLs: [URL] = []
	@State var transcripts: [Transcript] = []
	
	var body: some View {
		List {
			ForEach(transcripts) { transcript in
				RecordingRow(transcript: transcript, selectedRecording: $selectedRecording)
			}
			.onDelete { indices in
				for transcript in transcripts[indices] {
					do {
						try transcript.deleteRecording()
					} catch {
						print("Failed to delete transcript: \(error)")
					}
				}
			}
		}
		.task {
			do {
				let urls = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
				
				transcripts = urls.compactMap {
					if $0.pathExtension != "transcript" { return nil }
					return try? Transcript.load(in: $0)
				}
			} catch {
				print("Failed to list audio files: \(error)")
			}
		}
	}
	
	struct RecordingRow: View {
		@Environment(\.dismiss) var dismiss
		let transcript: Transcript
		@Binding var selectedRecording: OutputSegmentedRecording?

		var body: some View {
			AsyncButton(action: {
				if let recording = try? await transcript.buildRecording() {
					selectedRecording = recording
					dismiss()
				}
			}) {
				HStack(spacing: 0) {
					Text(transcript.startDate.formatted())
					Spacer()
					Text(transcript.duration.durationString(style: .minutes, showLeadingZero: true))
					let secondsOnly = Int(transcript.duration) % 60
					Text(String(format: ":%02d", secondsOnly))
						.opacity(0.5)
				}
			}
		}
	}
}
