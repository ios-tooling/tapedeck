//
//  RecordingList.swift
//  TapeDeckHarness
//
//  Created by Ben Gottlieb on 10/13/24.
//

import SwiftUI
import TapeDeck

struct RecordingList: View {
	let url: URL
	
	@State var recordingURLs: [URL] = []
	@State var transcripts: [Transcript] = []
	
	var body: some View {
		List {
			ForEach(transcripts) { transcript in
				HStack(spacing: 0) {
					Text(transcript.startDate.formatted())
					Spacer()
					Text(transcript.duration.durationString(style: .minutes, showLeadingZero: true))
					let secondsOnly = Int(transcript.duration) % 60
					Text(String(format: ":%02d", secondsOnly))
						.opacity(0.5)
				}
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
				
				transcripts = urls.compactMap { try? Transcript.load(in: $0) }
			} catch {
				print("Failed to list audio files: \(error)")
			}
		}
	}
}

#Preview {
	RecordingList(url: .documents)
}
