import Foundation
import PDFKit
import XCTest
@testable import AstroMalik

enum ReportTestSupport {
    static func referenceChart(name: String = "Referencia Madrid", birthTime: String = "20:33") throws -> NatalChart {
        AstroEngine.configure(ephePath: nil)
        let jd = try julianDayFromLocal(birthDate: "1976-10-11", birthTime: birthTime, timezoneName: "Europe/Madrid")
        var chart = try AstroEngine.computeNatalChart(jd: jd.jd, lat: 40.4168, lon: -3.7038)
        chart.name = name
        chart.birthDate = "1976-10-11"
        chart.birthTime = birthTime
        chart.timezone = "Europe/Madrid"
        chart.placeName = "Madrid"
        return chart
    }

    static func assertPDF(_ data: Data, contains expected: [String], file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertGreaterThan(data.count, 1_000, "PDF vacío o demasiado pequeño", file: file, line: line)
        XCTAssertEqual(String(decoding: data.prefix(5), as: UTF8.self), "%PDF-", file: file, line: line)
        let raw = String(decoding: data, as: UTF8.self)
        let extracted = PDFDocument(data: data)?.string ?? ""
        let haystack = raw + "\n" + extracted
        for string in expected {
            XCTAssertTrue(
                haystack.contains(string) || dataContainsUTF16BE(data, string) || dataContainsUTF16LE(data, string),
                "PDF no contiene \(string). Texto extraído: \(extracted.prefix(500))",
                file: file,
                line: line
            )
        }
    }

    static func assertHTML(_ html: String, contains expected: [String], file: StaticString = #filePath, line: UInt = #line) {
        for string in expected {
            XCTAssertTrue(html.contains(string), "HTML no contiene \(string)", file: file, line: line)
        }
    }

    private static func dataContainsUTF16BE(_ data: Data, _ string: String) -> Bool {
        let bytes = string.utf16.flatMap { [UInt8($0 >> 8), UInt8($0 & 0xff)] }
        return dataContains(data, bytes)
    }

    private static func dataContainsUTF16LE(_ data: Data, _ string: String) -> Bool {
        let bytes = string.utf16.flatMap { [UInt8($0 & 0xff), UInt8($0 >> 8)] }
        return dataContains(data, bytes)
    }

    private static func dataContains(_ data: Data, _ needle: [UInt8]) -> Bool {
        guard !needle.isEmpty, needle.count <= data.count else { return false }
        return data.withUnsafeBytes { raw in
            guard let base = raw.bindMemory(to: UInt8.self).baseAddress else { return false }
            let count = data.count - needle.count
            for offset in 0...count {
                var match = true
                for index in 0..<needle.count where base[offset + index] != needle[index] {
                    match = false
                    break
                }
                if match { return true }
            }
            return false
        }
    }
}
