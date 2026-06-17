import Foundation
import zlib

enum TarArchiveReader {
    private static let blockSize = 512

    struct EntryInfo: Equatable {
        let path: String
        let uncompressedSize: Int64
        let modificationDate: Date?
        let isDirectory: Bool
    }

    private struct Entry {
        let path: String
        let size: Int64
        let modificationDate: Date?
        let dataOffset: Int
        let isDirectory: Bool

        var info: EntryInfo {
            EntryInfo(
                path: path,
                uncompressedSize: isDirectory ? 0 : size,
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
        guard !entry.isDirectory, entry.size > 0 else { return Data() }

        let start = entry.dataOffset
        let end = start + Int(entry.size)
        guard start >= 0, end <= data.count else { return nil }
        return Data(data[start..<end])
    }

    static func decompressedTarData(from raw: Data) -> Data? {
        if isGzipCompressed(raw) {
            return gunzip(raw)
        }
        if isXzCompressed(raw) {
            return nil
        }
        return raw
    }

    static func payload(from archiveURL: URL) -> Data? {
        guard let raw = ArchiveSandboxAccess.readData(from: archiveURL) else { return nil }
        return decompressedTarData(from: raw)
    }

    static func isGzipCompressed(_ data: Data) -> Bool {
        data.count >= 2 && data[0] == 0x1f && data[1] == 0x8b
    }

    static func isXzCompressed(_ data: Data) -> Bool {
        data.count >= 6 && data.prefix(6).elementsEqual([0xFD, 0x37, 0x7A, 0x58, 0x5A, 0x00])
    }

    static func gunzip(_ data: Data) -> Data? {
        guard !data.isEmpty else { return Data() }

        var stream = z_stream()
        let initResult = inflateInit2_(
            &stream,
            15 + 32,
            ZLIB_VERSION,
            Int32(MemoryLayout<z_stream>.size)
        )
        guard initResult == Z_OK else { return nil }
        defer { inflateEnd(&stream) }

        let initialCapacity = max(data.count * 4, 64)
        var output = [UInt8](repeating: 0, count: initialCapacity)

        var status: Int32 = Z_OK
        let inputConsumed = data.withUnsafeBytes { inputBuffer -> Bool in
            guard let inputPtr = inputBuffer.bindMemory(to: Bytef.self).baseAddress else { return false }
            stream.next_in = UnsafeMutablePointer(mutating: inputPtr)
            stream.avail_in = uInt(inputBuffer.count)

            while status == Z_OK {
                if stream.total_out >= uLong(output.count) {
                    output.append(contentsOf: [UInt8](repeating: 0, count: output.count))
                }

                stream.next_out = output.withUnsafeMutableBytes { outputBuffer in
                    outputBuffer.bindMemory(to: Bytef.self).baseAddress!
                        .advanced(by: Int(stream.total_out))
                }
                stream.avail_out = uInt(output.count) - uInt(stream.total_out)

                status = inflate(&stream, Z_NO_FLUSH)
                if status == Z_STREAM_END { break }
                if status != Z_OK { return false }
            }
            return status == Z_STREAM_END
        }

        guard inputConsumed else { return nil }
        return Data(output.prefix(Int(stream.total_out)))
    }

    private static func entries(in data: Data) -> [Entry] {
        var result: [Entry] = []
        var offset = 0
        var pendingLongName: String?
        var consecutiveZeroBlocks = 0

        while offset + blockSize <= data.count {
            let header = data[offset..<(offset + blockSize)]
            if isZeroBlock(header) {
                consecutiveZeroBlocks += 1
                if consecutiveZeroBlocks >= 2 { break }
                offset += blockSize
                continue
            }
            consecutiveZeroBlocks = 0

            let typeFlag = header[156]
            let size = parseOctal(header, offset: 124, length: 12)
            let mtime = TimeInterval(parseOctal(header, offset: 136, length: 12))
            let modificationDate = mtime > 0 ? Date(timeIntervalSince1970: mtime) : nil
            let name = parseName(header)

            offset += blockSize

            if typeFlag == 0x4c {
                pendingLongName = readString(from: data, offset: offset, length: Int(size))
                offset += paddedSize(size)
                continue
            }

            if typeFlag == 0x78 || typeFlag == 0x67 {
                offset += paddedSize(size)
                continue
            }

            let path = pendingLongName ?? name
            pendingLongName = nil
            guard !path.isEmpty else {
                offset += paddedSize(size)
                continue
            }

            let isDirectory = typeFlag == 0x35 || path.hasSuffix("/")
            result.append(
                Entry(
                    path: path,
                    size: size,
                    modificationDate: modificationDate,
                    dataOffset: offset,
                    isDirectory: isDirectory
                )
            )

            offset += paddedSize(size)
        }

        return result
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

    private static func normalize(_ path: String) -> String {
        var normalized = path
        if normalized.hasPrefix("./") {
            normalized = String(normalized.dropFirst(2))
        }
        while normalized.hasPrefix("/") {
            normalized.removeFirst()
        }
        return normalized
    }

    private static func parseName(_ header: Data.SubSequence) -> String {
        let name = readCString(header, offset: 0, length: 100)
        let prefix = readCString(header, offset: 345, length: 155)
        if prefix.isEmpty { return name }
        return "\(prefix)/\(name)"
    }

    private static func readCString(_ header: Data.SubSequence, offset: Int, length: Int) -> String {
        let start = header.startIndex + offset
        let end = min(header.startIndex + offset + length, header.endIndex)
        guard start < end else { return "" }

        var bytes: [UInt8] = []
        bytes.reserveCapacity(length)
        for byte in header[start..<end] {
            if byte == 0 { break }
            bytes.append(byte)
        }
        return String(bytes: bytes, encoding: .utf8) ?? ""
    }

    private static func readString(from data: Data, offset: Int, length: Int) -> String? {
        guard offset >= 0, length >= 0, offset + length <= data.count else { return nil }
        let slice = data[offset..<(offset + length)]
        let trimmed = slice.prefix { $0 != 0 }
        return String(bytes: trimmed, encoding: .utf8)
    }

    private static func parseOctal(_ header: Data.SubSequence, offset: Int, length: Int) -> Int64 {
        let field = readCString(header, offset: offset, length: length)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\0"))
        guard !field.isEmpty, let value = Int64(field, radix: 8) else { return 0 }
        return value
    }

    private static func paddedSize(_ size: Int64) -> Int {
        let length = max(0, Int(size))
        return ((length + blockSize - 1) / blockSize) * blockSize
    }

    private static func isZeroBlock(_ header: Data.SubSequence) -> Bool {
        header.allSatisfy { $0 == 0 }
    }
}
