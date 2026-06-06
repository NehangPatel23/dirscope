import Foundation
import zlib

enum ZipArchiveReader {
    private static let localHeaderSignature: UInt32 = 0x04034b50
    private static let centralDirectorySignature: UInt32 = 0x02014b50
    private static let endOfCentralDirectorySignature: UInt32 = 0x06054b50

    struct EntryInfo: Equatable {
        let path: String
        let uncompressedSize: Int64
        let modificationDate: Date?
        let isDirectory: Bool
    }

    struct Entry {
        let path: String
        let compressionMethod: UInt16
        let compressedSize: UInt32
        let uncompressedSize: UInt32
        let modificationDate: Date?
        let localHeaderOffset: UInt32

        var isDirectory: Bool { path.hasSuffix("/") }

        var info: EntryInfo {
            EntryInfo(
                path: path,
                uncompressedSize: isDirectory ? 0 : Int64(uncompressedSize),
                modificationDate: modificationDate,
                isDirectory: isDirectory
            )
        }
    }

    static func listEntryPaths(in data: Data) -> [String] {
        entries(in: data).map(\.path)
    }

    static func listEntryInfos(in data: Data) -> [EntryInfo] {
        entries(in: data).map(\.info)
    }

    static func extractEntry(path: String, from data: Data) -> Data? {
        guard let entry = matchingEntry(for: path, in: entries(in: data)) else {
            return nil
        }
        return extract(entry: entry, from: data)
    }

    private static func entries(in data: Data) -> [Entry] {
        guard let eocdOffset = locateEndOfCentralDirectory(in: data) else { return [] }

        let totalEntries = Int(readUInt16(data, eocdOffset + 10))
        let centralDirectoryOffset = Int(readUInt32(data, eocdOffset + 16))
        guard totalEntries > 0, centralDirectoryOffset < data.count else { return [] }

        var result: [Entry] = []
        var offset = centralDirectoryOffset

        for _ in 0..<totalEntries {
            guard offset + 46 <= data.count else { break }
            guard readUInt32(data, offset) == centralDirectorySignature else { break }

            let dosTime = readUInt16(data, offset + 12)
            let dosDate = readUInt16(data, offset + 14)
            let compressionMethod = readUInt16(data, offset + 10)
            let compressedSize = readUInt32(data, offset + 20)
            let uncompressedSize = readUInt32(data, offset + 24)
            let fileNameLength = Int(readUInt16(data, offset + 28))
            let extraFieldLength = Int(readUInt16(data, offset + 30))
            let commentLength = Int(readUInt16(data, offset + 32))
            let localHeaderOffset = readUInt32(data, offset + 42)

            let nameStart = offset + 46
            let nameEnd = nameStart + fileNameLength
            guard nameEnd <= data.count else { break }

            let path = String(data: data[nameStart..<nameEnd], encoding: .utf8) ?? ""
            if !path.isEmpty {
                result.append(
                    Entry(
                        path: path,
                        compressionMethod: compressionMethod,
                        compressedSize: compressedSize,
                        uncompressedSize: uncompressedSize,
                        modificationDate: dateFromDOS(date: dosDate, time: dosTime),
                        localHeaderOffset: localHeaderOffset
                    )
                )
            }

            offset = nameEnd + extraFieldLength + commentLength
        }

        return result
    }

    private static func extract(entry: Entry, from data: Data) -> Data? {
        let offset = Int(entry.localHeaderOffset)
        guard offset + 30 <= data.count else { return nil }
        guard readUInt32(data, offset) == localHeaderSignature else { return nil }

        let fileNameLength = Int(readUInt16(data, offset + 26))
        let extraFieldLength = Int(readUInt16(data, offset + 28))
        let dataStart = offset + 30 + fileNameLength + extraFieldLength
        let dataEnd = dataStart + Int(entry.compressedSize)
        guard dataEnd <= data.count else { return nil }

        let compressedData = Data(data[dataStart..<dataEnd])
        switch entry.compressionMethod {
        case 0:
            return compressedData
        case 8:
            return inflateDeflate(compressedData, uncompressedSize: entry.uncompressedSize)
        default:
            return nil
        }
    }

    private static func matchingEntry(for path: String, in entries: [Entry]) -> Entry? {
        let normalized = normalize(path)
        if let exact = entries.first(where: { normalize($0.path) == normalized }) {
            return exact
        }
        return entries.first { entry in
            let entryPath = normalize(entry.path)
            return entryPath.hasSuffix("/\(normalized)") || entryPath.hasSuffix(normalized)
        }
    }

    private static func inflateDeflate(_ data: Data, uncompressedSize: UInt32) -> Data? {
        guard !data.isEmpty else { return Data() }

        var stream = z_stream()
        let initResult = inflateInit2_(
            &stream,
            -Int32(MAX_WBITS),
            ZLIB_VERSION,
            Int32(MemoryLayout<z_stream>.size)
        )
        guard initResult == Z_OK else { return nil }
        defer { inflateEnd(&stream) }

        let initialCapacity = max(Int(uncompressedSize), data.count * 4, 64)
        var output = [UInt8](repeating: 0, count: initialCapacity)

        var status: Int32 = Z_OK
        let inputConsumed = data.withUnsafeBytes { inputBuffer -> Bool in
            guard let inputPtr = inputBuffer.bindMemory(to: Bytef.self).baseAddress else { return false }
            stream.next_in = UnsafeMutablePointer<Bytef>(mutating: inputPtr)
            stream.avail_in = uInt(inputBuffer.count)
            return true
        }
        guard inputConsumed else { return nil }

        while true {
            let produced = output.withUnsafeMutableBytes { outputBuffer -> Int in
                guard let outputPtr = outputBuffer.bindMemory(to: Bytef.self).baseAddress else { return 0 }
                stream.next_out = outputPtr
                stream.avail_out = uInt(outputBuffer.count)
                status = inflate(&stream, Z_FINISH)
                return outputBuffer.count - Int(stream.avail_out)
            }

            if status == Z_STREAM_END {
                return Data(output.prefix(produced))
            }

            if status == Z_BUF_ERROR || (status == Z_OK && produced == output.count) {
                output.append(contentsOf: [UInt8](repeating: 0, count: max(output.count, 64_384)))
                continue
            }

            return nil
        }
    }

    private static func locateEndOfCentralDirectory(in data: Data) -> Int? {
        let minimumSize = 22
        guard data.count >= minimumSize else { return nil }

        let maxCommentLength = 65_535
        let searchStart = max(0, data.count - minimumSize - maxCommentLength)
        var offset = data.count - minimumSize
        while offset >= searchStart {
            if readUInt32(data, offset) == endOfCentralDirectorySignature {
                return offset
            }
            offset -= 1
        }
        return nil
    }

    private static func dateFromDOS(date dosDate: UInt16, time dosTime: UInt16) -> Date? {
        let second = Int(dosTime & 0x1F) * 2
        let minute = Int((dosTime >> 5) & 0x3F)
        let hour = Int((dosTime >> 11) & 0x1F)
        let day = Int(dosDate & 0x1F)
        let month = Int((dosDate >> 5) & 0x0F)
        let year = Int((dosDate >> 9) & 0x7F) + 1980

        guard (1...12).contains(month), (1...31).contains(day) else { return nil }

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second
        return Calendar.current.date(from: components)
    }

    private static func normalize(_ path: String) -> String {
        var normalized = path
        if normalized.hasPrefix("./") {
            normalized = String(normalized.dropFirst(2))
        }
        return normalized
    }

    private static func readUInt16(_ data: Data, _ offset: Int) -> UInt16 {
        UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    }

    private static func readUInt32(_ data: Data, _ offset: Int) -> UInt32 {
        UInt32(data[offset])
            | (UInt32(data[offset + 1]) << 8)
            | (UInt32(data[offset + 2]) << 16)
            | (UInt32(data[offset + 3]) << 24)
    }
}
