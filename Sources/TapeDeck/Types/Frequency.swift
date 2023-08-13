//
//  Frequency.swift
//  
//
//  Created by Ben Gottlieb on 8/13/23.
//

import Foundation

public struct Frequency: ExpressibleByFloatLiteral, ExpressibleByIntegerLiteral {
	public typealias FloatLiteralType = Double
	public typealias IntegerLiteralType = Int
	let freq: Double
	
	public init(hertz: Double) {
		self.freq = hertz
	}
	
	public init(floatLiteral value: FloatLiteralType) {
		self.freq = value
	}

	public init(integerLiteral value: IntegerLiteralType) {
		self.freq = Double(value)
	}

	public var hertz: Double { freq }
	public var timeInterval: TimeInterval { 1 / freq }
}

public enum Volume: Codable, CustomStringConvertible, Equatable, Comparable {
	case dB(Double)
	case unit(Double)
	
	public init?(detectedRoomVolume: Double?) {
		guard let volume = detectedRoomVolume else {
			self = .silence
			return nil
		}
		self = .dB(volume + Self.fullScaleConstant)
	}
	
	static let maxDB = 90.0
	static let fullScaleConstant = 90.0
	public static let baselineDBAdjustment = 40.0
	public static let silence = Volume.unit(0)
	public static let max = Volume.dB(Self.maxDB)
	public static let defaultMaxVolume = Volume.dB(70)

	public var db: Double {
		switch self {
		case .dB(let db): return db
		case .unit(let vol): return vol * Self.maxDB
		}
	}
	
	public var unit: Double {
		switch self {
		case .dB(let db): return db / Self.maxDB
		case .unit(let vol): return vol
		}
	}
	
	public var description: String {
		switch self {
		case .dB(let db): return "\(db) dB"
		case .unit(let vol): return String(format: "%.2f%%", vol)
		}
	}
	
	enum CodingKeys: CodingKey { case unit, db }
	public func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		switch self {
		case .dB(let db): try container.encode(db, forKey: .db)
		case .unit(let vol): try container.encode(vol, forKey: .unit)
		}
	}
	
	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		if let db = try? container.decode(Double.self, forKey: .db) {
			self = .dB(db)
		} else if let vol = try? container.decode(Double.self, forKey: .unit) {
			self = .unit(vol)
		} else {
			self = .silence
		}
	}
	
	public static func ==(lhs: Volume, rhs: Volume) -> Bool { lhs.db == rhs.db }
	public static func <(lhs: Volume, rhs: Volume) -> Bool { lhs.db < rhs.db }
}
