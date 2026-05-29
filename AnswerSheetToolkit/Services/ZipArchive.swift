import Foundation

/// A minimal, dependency-free ZIP archive writer using the STORE method (no
/// compression). This is sufficient for producing valid `.xlsx` files, which are
/// just ZIP containers of XML; Excel/Numbers/Sheets read stored entries fine.
struct ZipArchive {
    private struct Entry {
        let name: String
        let data: Data
        let crc32: UInt32
        var offset: UInt32 = 0
    }

    private var entries: [Entry] = []

    mutating func addFile(path: String, data: Data) {
        entries.append(Entry(name: path, data: data, crc32: CRC32.checksum(data)))
    }

    mutating func addFile(path: String, string: String) {
        addFile(path: path, data: Data(string.utf8))
    }

    /// Serializes all added files into a complete ZIP byte stream.
    func build() -> Data {
        var output = Data()
        var local = entries
        let dosTime: UInt16 = 0
        let dosDate: UInt16 = 0x21 // 1980-01-01, deterministic output

        // Local file headers + data
        for i in local.indices {
            local[i].offset = UInt32(output.count)
            let nameBytes = Array(local[i].name.utf8)
            output.append(littleEndian: UInt32(0x04034b50)) // local file header signature
            output.append(littleEndian: UInt16(20))         // version needed
            output.append(littleEndian: UInt16(0))          // flags
            output.append(littleEndian: UInt16(0))          // method = store
            output.append(littleEndian: dosTime)
            output.append(littleEndian: dosDate)
            output.append(littleEndian: local[i].crc32)
            output.append(littleEndian: UInt32(local[i].data.count)) // compressed size
            output.append(littleEndian: UInt32(local[i].data.count)) // uncompressed size
            output.append(littleEndian: UInt16(nameBytes.count))
            output.append(littleEndian: UInt16(0))          // extra length
            output.append(contentsOf: nameBytes)
            output.append(local[i].data)
        }

        // Central directory
        let centralStart = UInt32(output.count)
        for entry in local {
            let nameBytes = Array(entry.name.utf8)
            output.append(littleEndian: UInt32(0x02014b50)) // central dir signature
            output.append(littleEndian: UInt16(20))         // version made by
            output.append(littleEndian: UInt16(20))         // version needed
            output.append(littleEndian: UInt16(0))          // flags
            output.append(littleEndian: UInt16(0))          // method
            output.append(littleEndian: dosTime)
            output.append(littleEndian: dosDate)
            output.append(littleEndian: entry.crc32)
            output.append(littleEndian: UInt32(entry.data.count))
            output.append(littleEndian: UInt32(entry.data.count))
            output.append(littleEndian: UInt16(nameBytes.count))
            output.append(littleEndian: UInt16(0))          // extra length
            output.append(littleEndian: UInt16(0))          // comment length
            output.append(littleEndian: UInt16(0))          // disk number start
            output.append(littleEndian: UInt16(0))          // internal attrs
            output.append(littleEndian: UInt32(0))          // external attrs
            output.append(littleEndian: entry.offset)       // local header offset
            output.append(contentsOf: nameBytes)
        }
        let centralSize = UInt32(output.count) - centralStart

        // End of central directory record
        output.append(littleEndian: UInt32(0x06054b50))
        output.append(littleEndian: UInt16(0))              // disk number
        output.append(littleEndian: UInt16(0))              // disk with central dir
        output.append(littleEndian: UInt16(local.count))    // entries on this disk
        output.append(littleEndian: UInt16(local.count))    // total entries
        output.append(littleEndian: centralSize)
        output.append(littleEndian: centralStart)
        output.append(littleEndian: UInt16(0))              // comment length

        return output
    }
}

private extension Data {
    mutating func append(littleEndian value: UInt16) {
        append(UInt8(value & 0xff))
        append(UInt8((value >> 8) & 0xff))
    }

    mutating func append(littleEndian value: UInt32) {
        append(UInt8(value & 0xff))
        append(UInt8((value >> 8) & 0xff))
        append(UInt8((value >> 16) & 0xff))
        append(UInt8((value >> 24) & 0xff))
    }
}

/// CRC-32 (IEEE 802.3) used by the ZIP format.
enum CRC32 {
    private static let table: [UInt32] = {
        (0..<256).map { i -> UInt32 in
            var c = UInt32(i)
            for _ in 0..<8 {
                c = (c & 1) != 0 ? (0xEDB88320 ^ (c >> 1)) : (c >> 1)
            }
            return c
        }
    }()

    static func checksum(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data {
            let index = Int((crc ^ UInt32(byte)) & 0xFF)
            crc = table[index] ^ (crc >> 8)
        }
        return crc ^ 0xFFFFFFFF
    }
}
