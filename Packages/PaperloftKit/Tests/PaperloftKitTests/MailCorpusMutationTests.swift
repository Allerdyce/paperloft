import Foundation
import Testing
@testable import PaperloftKit

struct MailCorpusMutationTests {
    @Test func tenThousandDiverseCorpusMutationsRemainBoundedAndDeterministic() throws {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { root.deleteLastPathComponent() }
        let fixtureRoot = root.appendingPathComponent("Tests/MailFixtures")
        let files = try FileManager.default.contentsOfDirectory(at: fixtureRoot, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "eml" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        try #require(files.count == 80)
        let seeds = try files.map { try Data(contentsOf: $0) }
        let originals = try seeds.map { try MailDocument.parse($0) }
        var state: UInt64 = 0x4D494D455F46555A
        func next(_ limit: Int) -> Int {
            state ^= state << 13; state ^= state >> 7; state ^= state << 17
            return Int(state % UInt64(limit))
        }
        var accepted = 0, rejected = 0
        let start = ContinuousClock.now
        for iteration in 0..<10_000 {
            var bytes = Array(seeds[iteration % seeds.count])
            let operation = (iteration / seeds.count) % 8
            switch operation {
            case 0:
                bytes.insert(contentsOf: Array("X-Fuzz-Case: \(iteration)\r\n".utf8), at: 0)
            case 1:
                bytes.removeLast(next(bytes.count) + 1)
            case 2:
                for _ in 0..<(next(8) + 1) { bytes[next(bytes.count)] = UInt8(next(256)) }
            case 3:
                bytes.insert(contentsOf: (0..<32).map { _ in UInt8(next(256)) }, at: next(bytes.count + 1))
            case 4:
                for _ in 0..<(next(12) + 1) {
                    bytes.insert(contentsOf: Array("Content-Type: message/rfc822\r\n\r\n".utf8), at: 0)
                }
            case 5:
                bytes = Array("Content-Type: text/plain\r\nContent-Transfer-Encoding: base64\r\n\r\n".utf8) + bytes
            case 6:
                bytes.removeAll { $0 == 10 || $0 == 13 }
            default:
                let part = "--stress\r\nContent-Type: text/plain\r\n\r\ntext\r\n"
                bytes = Array(("Content-Type: multipart/mixed; boundary=stress\r\n\r\n"
                    + String(repeating: part, count: next(110) + 1) + "--stress--\r\n").utf8)
            }
            try autoreleasepool {
                let input = Data(bytes)
                do {
                    let document = try MailDocument.parse(input)
                    accepted += 1
                    if operation == 0 { #expect(document == originals[iteration % seeds.count]) }
                    #expect(document.pdfs.count <= MailDocument.maximumPDFs)
                    #expect(document.images.count <= MailDocument.maximumImages)
                    #expect(document.pdfs.allSatisfy { $0.data.count <= MailDocument.maximumPDFBytes })
                    #expect(document.images.allSatisfy { $0.data.count <= MailDocument.maximumImageBytes })
                    if iteration % 97 == 0 { #expect(try MailDocument.parse(input) == document) }
                } catch is MailDocument.Failure {
                    rejected += 1
                    #expect(operation != 0, "Adding an unused header must preserve every valid seed")
                }
            }
        }
        #expect(accepted > 0 && rejected > 0)
        #expect(accepted + rejected == 10_000)
        #expect(start.duration(to: .now) < .seconds(120))
        print("Corpus MIME mutations: \(accepted) parsed, \(rejected) safely rejected; elapsed \(start.duration(to: .now)).")
    }
}
