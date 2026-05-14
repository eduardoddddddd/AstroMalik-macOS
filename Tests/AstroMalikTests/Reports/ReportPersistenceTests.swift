import XCTest
@testable import AstroMalik

final class ReportPersistenceTests: XCTestCase {
    private var tempFolder: URL!

    override func setUpWithError() throws {
        tempFolder = FileManager.default.temporaryDirectory
            .appendingPathComponent("AstroMalik-ReportPersistenceTests-")
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempFolder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempFolder {
            try? FileManager.default.removeItem(at: tempFolder)
        }
        tempFolder = nil
    }

    func testSavingDummyPDFInDestinationFolderWorks() throws {
        let dummyPDF = Data("%PDF-1.4\n% AstroMalik dummy\n%%EOF".utf8)
        let url = try PDFReportPersistence.save(pdfData: dummyPDF, fileName: "dummy.pdf", in: tempFolder)

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(try Data(contentsOf: url), dummyPDF)
        XCTAssertEqual(url.deletingLastPathComponent(), tempFolder)
    }

    func testSuggestedFileNameFollowsDocumentedPattern() throws {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = 2026
        components.month = 5
        components.day = 14
        let date = try XCTUnwrap(components.date)

        let fileName = PDFReportPersistence.suggestedFileName(
            chartName: "Carta/Prueba",
            reportType: "Informe natal",
            date: date
        )

        XCTAssertEqual(fileName, "Carta-Prueba - Informe natal - 2026-05-14.pdf")
        XCTAssertTrue(fileName.range(of: #"^[^-]+.+ - .+ - \d{4}-\d{2}-\d{2}\.pdf$"#, options: .regularExpression) != nil)
    }

    func testHistoryListsPDFsSortedByModificationDateDescending() throws {
        let older = tempFolder.appendingPathComponent("older.pdf")
        let newer = tempFolder.appendingPathComponent("newer.pdf")
        let text = tempFolder.appendingPathComponent("not-a-pdf.txt")
        try Data("%PDF older".utf8).write(to: older)
        try Data("%PDF newer".utf8).write(to: newer)
        try Data("ignore".utf8).write(to: text)

        let oldDate = Date(timeIntervalSince1970: 1_700_000_000)
        let newDate = Date(timeIntervalSince1970: 1_800_000_000)
        try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: older.path)
        try FileManager.default.setAttributes([.modificationDate: newDate], ofItemAtPath: newer.path)

        let reports = try PDFReportPersistence.listPDFs(in: tempFolder)

        XCTAssertEqual(reports.map(\.name), ["newer.pdf", "older.pdf"])
        XCTAssertEqual(
            reports.map { $0.url.resolvingSymlinksInPath().path },
            [newer.resolvingSymlinksInPath().path, older.resolvingSymlinksInPath().path]
        )
    }
}
