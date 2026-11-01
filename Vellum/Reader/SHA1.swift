import Foundation

/// SHA-1, needed only to undo EPUB font obfuscation, whose key is defined as a SHA-1 hash.
/// Not used for anything security-related.
nonisolated enum SHA1 {
	static func hash(_ message: [UInt8]) -> [UInt8] {
		var h: [UInt32] = [0x67452301, 0xEFCDAB89, 0x98BADCFE, 0x10325476, 0xC3D2E1F0]

		var data = message
		let bitLength = UInt64(message.count) * 8
		data.append(0x80)
		while data.count % 64 != 56 {
			data.append(0)
		}
		for shift in stride(from: 56, through: 0, by: -8) {
			data.append(UInt8((bitLength >> UInt64(shift)) & 0xFF))
		}

		for chunk in stride(from: 0, to: data.count, by: 64) {
			var w = [UInt32](repeating: 0, count: 80)
			for i in 0..<16 {
				let j = chunk + i * 4
				w[i] = UInt32(data[j]) << 24 | UInt32(data[j + 1]) << 16 | UInt32(data[j + 2]) << 8 | UInt32(data[j + 3])
			}
			for i in 16..<80 {
				w[i] = (w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16]).rotatedLeft(by: 1)
			}

			var (a, b, c, d, e) = (h[0], h[1], h[2], h[3], h[4])
			for i in 0..<80 {
				let (f, k): (UInt32, UInt32) = switch i {
				case 0..<20: ((b & c) | (~b & d), 0x5A827999)
				case 20..<40: (b ^ c ^ d, 0x6ED9EBA1)
				case 40..<60: ((b & c) | (b & d) | (c & d), 0x8F1BBCDC)
				default: (b ^ c ^ d, 0xCA62C1D6)
				}
				let temp = a.rotatedLeft(by: 5) &+ f &+ e &+ k &+ w[i]
				(e, d, c, b, a) = (d, c, b.rotatedLeft(by: 30), a, temp)
			}

			h[0] &+= a
			h[1] &+= b
			h[2] &+= c
			h[3] &+= d
			h[4] &+= e
		}

		return h.flatMap { value in (0..<4).map { UInt8((value >> UInt32(24 - $0 * 8)) & 0xFF) } }
	}
}

nonisolated private extension UInt32 {
	func rotatedLeft(by count: UInt32) -> UInt32 {
		self << count | self >> (32 - count)
	}
}
