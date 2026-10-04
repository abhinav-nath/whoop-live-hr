import Foundation

/// Extracts BPM from a Bluetooth Heart Rate Measurement characteristic (2A37).
enum HeartRatePacketParser {
    /// Returns nil when the flags or heart-rate bytes are missing.
    /// Optional fields following the heart-rate value are ignored.
    static func parse(_ data: Data) -> Int? {
        var bytes = data.makeIterator()
        guard let flags = bytes.next(), let lowByte = bytes.next() else {
            return nil
        }

        // Bit 0 selects an 8-bit value or a little-endian 16-bit value.
        guard flags & 0x01 != 0 else {
            return Int(lowByte)
        }

        guard let highByte = bytes.next() else {
            return nil
        }

        return Int(UInt16(lowByte) | (UInt16(highByte) << 8))
    }
}
