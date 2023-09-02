//
//  File.swift
//  
//
//  Created by Ben Gottlieb on 9/1/23.
//

import Foundation


public struct RecordingDate: Identifiable {
	public var id: Date { date }
	public var date: Date
	public var recordings: [RecordingStore.Recording] = []
	
	public var title: String { 
		if #available(iOS 15.0, *) {
			date.formatted(date: .complete, time: .omitted)
		} else {
			date.localTimeString(date: .none, time: .medium)
		}
	}
}

extension RecordingStore {
	public var recordingsByDate: [RecordingDate] {
		var dates: [RecordingDate] = []
		
		recordings.forEach { recording in
			if let date = dates.last?.date, date.isSameDay(as: recording.startedAt) {
				dates[dates.count - 1].recordings.append(recording)
			} else {
				dates.append(.init(date: recording.startedAt, recordings: [recording]))
			}
		}
		return dates
	}
}
