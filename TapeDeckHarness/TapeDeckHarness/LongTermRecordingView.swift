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
	@State var format = Recorder.AudioFileType.m4a
	@State var url: URL?
	@State var recording: RecorderOutput?
	@ObservedObject var recorder = Recorder.instance
	@State var fileBrowserURL: URL?
	@State var listingRecordings = false
	@State var player = RawPlayback.instance

	var rawSampleData: Data? {
		guard let url = Bundle.main.url(forResource: "sample_buffer_data", withExtension: "") else { return nil }
		guard let data = try? Data(contentsOf: url) else { return nil }
		return data
	}
	var sampleData: [Int16]? {
		guard let data = rawSampleData else { return nil }
		let i16array = data.withUnsafeBytes {
				  Array($0.bindMemory(to: Int16.self)).map(Int16.init(bigEndian:))
			 }
		print("Found \(i16array.count) samples")
		return i16array
	}
	
	func start(format: Recorder.AudioFileType) async throws {
		_ = try? await Microphone.instance.stop()
		try? await Task.sleep(for: .seconds(0.2))
 
		url = root.appendingPathComponent(Date.now.filename).appendingPathExtension(format.fileExtension)
		
		if format == .raw {
			recording = RawDataRecorder(url: url!)
		} else {
			recording = OutputSegmentedRecording(in: url!, outputType: format, bufferDuration: format == .raw ? 1 : 5)
		}
		try await recorder.startRecording(to: recording!, shouldTranscribe: true)
	}
	
	func stop() async throws {
		if recorder.isRecording {
			try await recorder.stop()
			let url = url
			recording = nil
			try? await Task.sleep(for: .seconds(0.2))
			self.recording = try? await Transcript.load(in: url!).buildRecording()
		} else {
			recording = nil
		}
	}
	
	var body: some View {
		VStack {
			if let rawData = rawSampleData {
				Button("Play") {
					player.playAudio(from: rawData)
//					player.play(samples: rawData)
				}
			}
			HStack {
				Button("Files") { fileBrowserURL = root }
					.fullScreenCover(item: $fileBrowserURL) { url in
						FileBrowserView(root: url) { fileURL, placement in
							if fileURL.pathExtension == "data" {
								if placement == .details {
									Button("Play Raw") {
										RawPlayback.instance.playAudio(from: fileURL)
									}
									.buttonStyle(.bordered)
								} else {
									Button(action: { RawPlayback.instance.playAudio(from: fileURL) }) {
										Image(systemName: "play.fill")
									}
								}
							}
						}
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
				
				if let recording = recording as? OutputSegmentedRecording {
					SegmentedRecordingFileList(recording: recording)
					
					AsyncButton("Delete") {
						await recording.delete()
						self.recording = nil
					}
				}
				
			} else {
				AsyncButton(action: { try await start(format: .m4a) }) {
					HStack {
						Text("Start Recording m4a")
						Image(systemName: "circle.fill")
							.foregroundStyle(.red)
					}
				}
				
				AsyncButton(action: { try await start(format: .wav48k) }) {
					HStack {
						Text("Start Recording WAV")
						Image(systemName: "circle.fill")
							.foregroundStyle(.red)
					}
				}

				AsyncButton(action: { try await start(format: .raw) }) {
					HStack {
						Text("Start Recording Raw")
						Image(systemName: "circle.fill")
							.foregroundStyle(.red)
					}
				}
			}
		}
		.buttonStyle(.bordered)
	}
}

#Preview {
	LongTermRecordingView()
}
