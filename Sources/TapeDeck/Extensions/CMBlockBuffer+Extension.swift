//
//  CMBlockBuffer+Extensions.swift
//  
//
//  Created by Ben Gottlieb on 8/13/23.
//

import Foundation
import AVFoundation
import Suite
import Accelerate

extension CMBlockBuffer {
	var sampleInt16s: [Int16] {
		do {
			return try withUnsafeMutableBytes { buffer in
				let values = buffer.bindMemory(to: Int16.self)
				let array = Array(values)
				return array
			}
		} catch {
			logg(error: error, "Error when converting Floats in CMBlockBuffer")
			return []
		}
	}
	
	var samples: [Float] {
		do {
			return try withUnsafeMutableBytes { buffer in
				let values = buffer.bindMemory(to: Int16.self)
				let array = Array(values)
				var floats = [Float](repeating: 0, count: array.capacity)
				vDSP_vflt16(array, 1, &floats, 1, vDSP_Length(array.capacity))
				return floats
			}
		} catch {
			logg(error: error, "Error when converting Floats in CMBlockBuffer")
			return []
		}
	}
	
	var average: Float {
		return (try? withUnsafeMutableBytes { buffer in
			let values = buffer.bindMemory(to: Int16.self)
			let total: Double = values.reduce(0) {
				if $1 == 0 { return $0 }
				return $0 + 20 * log(abs(Double($1)))
			}
			return Float(total / Double(values.count))
		}) ?? 0
	}

	var max: Int16 {
		do {
			return try withUnsafeMutableBytes { buffer in
				let values = buffer.bindMemory(to: Int16.self)
				return values.max() ?? 0
			}
		} catch {
			logg(error: error, "Error when accessing raw bytes in CMBlockBuffer")
			return 0
		}
	}

	var normalized: [Float] {
		do {
			return try withUnsafeMutableBytes { buffer in
				let values = buffer.bindMemory(to: Int16.self)
				return values.map { Float($0) / Float(Int16.max) }
			}
		} catch {
			logg(error: error, "Error when accessing raw bytes in CMBlockBuffer")
			return []
		}
	}
}
