// Append only to PrimaryDirectionsGoldenTests.swift in the isolated checkout.
// Reuses its exact private fixtures and natal constructor. No production changes.
import Foundation
import CSwissEph

extension PrimaryDirectionsGoldenTests {
    func testExportF1MacReferences() throws {
        guard let path = ProcessInfo.processInfo.environment["F1_REFERENCE_DIR"] else {
            throw XCTSkip("Explicit export destination required")
        }
        let directory = URL(fileURLWithPath: path, isDirectory: true)
        AstroEngine.configure(ephePath: nil) // Identical to the original golden tests.
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)!
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0)!
        func utcDate(_ year: Int) -> Date {
            utcCalendar.date(from: DateComponents(year: year, month: 1, day: 1))!
        }
        func wallInput(_ date: Date, _ zone: TimeZone) -> (String, String) {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = zone
            let c = calendar.dateComponents([.year,.month,.day,.hour,.minute,.second], from: date)
            return (String(format:"%04d-%02d-%02d",c.year!,c.month!,c.day!),
                    String(format:"%02d:%02d:%02d",c.hour!,c.minute!,c.second!))
        }
        var rows: [[String: Any]] = []
        func probe(_ id: String, _ kind: String, _ date: String, _ time: String,
                   _ zone: String, extra: [String: Any] = [:]) {
            var row: [String: Any] = ["id":id,"kind":kind,"input":["birthDate":date,"birthTime":time,"timezoneName":zone]]
            for (key,value) in extra { row[key] = value }
            do {
                let result = try julianDayFromLocal(birthDate:date,birthTime:time,timezoneName:zone)
                let instant = try localDateFromBirthData(birthDate:date,birthTime:time,timezoneName:zone)
                row["status"] = "ok"
                row["utc"] = result.utcISO
                row["localISO"] = result.localISO
                row["julianDay"] = result.jd
                row["utFractionalHours"] = result.utFractionalHours
                row["offsetSeconds"] = TimeZone(identifier:zone)!.secondsFromGMT(for:instant)
            } catch {
                row["status"] = "error"
                row["error"] = String(describing:error)
            }
            rows.append(row)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys,.withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        for fixture in pdFixtures {
            probe(fixture.key,"existing-golden-fixture",fixture.birthDate,fixture.birthTime,fixture.timezone)
            let jd = try julianDayFromLocal(birthDate:fixture.birthDate,birthTime:fixture.birthTime,timezoneName:fixture.timezone).jd
            let natal = try makeNatalChart(fixture:fixture,jd:jd)
            var natalData = try encoder.encode(natal)
            natalData.append(0x0A)
            try natalData.write(to:directory.appendingPathComponent("natal-\(fixture.key).json"))
        }
        // Seasonal controls cover each requested Spanish year, including no-transition years.
        for year in Array(1940...1945) + Array(1974...1978) {
            for month in [1,7] {
                probe("madrid-\(year)-\(month)","synthetic-seasonal-probe",String(format:"%04d-%02d-15",year,month),"12:00:00","Europe/Madrid")
            }
        }
        let ranges: [(String,Int,Int)] = [
            ("Europe/Madrid",1940,1946),("Europe/Madrid",1974,1979),
            ("America/Argentina/Buenos_Aires",1988,1994),
            ("America/Argentina/Buenos_Aires",2007,2010),
            ("America/New_York",1974,1976),("America/New_York",2006,2008),
            ("America/New_York",2024,2025),("America/Los_Angeles",2024,2025)
        ]
        var transitions: [[String: Any]] = []
        for (zoneName,startYear,endYear) in ranges {
            let zone = TimeZone(identifier:zoneName)!
            var cursor = utcDate(startYear)
            let end = utcDate(endYear)
            while cursor < end {
                let next = min(cursor.addingTimeInterval(6*3600),end)
                let before = zone.secondsFromGMT(for:cursor)
                let after = zone.secondsFromGMT(for:next)
                if before != after {
                    var lo = Int64(cursor.timeIntervalSince1970)
                    var hi = Int64(next.timeIntervalSince1970)
                    while hi-lo > 1 {
                        let mid = lo+(hi-lo)/2
                        if zone.secondsFromGMT(for:Date(timeIntervalSince1970:Double(mid))) == before { lo=mid } else { hi=mid }
                    }
                    let instant = Date(timeIntervalSince1970:Double(hi))
                    let id = "\(zoneName):\(formatter.string(from:instant))"
                    transitions.append(["id":id,"timezone":zoneName,"utc":formatter.string(from:instant),"offsetBefore":before,"offsetAfter":after])
                    for (label,delta) in [("before",-1.0),("after",0.0)] {
                        let source = instant.addingTimeInterval(delta)
                        let (date,time) = wallInput(source,zone)
                        probe(id+":"+label,"synthetic-transition-probe",date,time,zoneName,
                              extra:["transitionID":id,"position":label,"inputDerivedFromUTC":formatter.string(from:source)])
                    }
                    // Wall-clock midpoint in a skipped or repeated interval. No invented birth.
                    let wall = instant.addingTimeInterval(Double(before+after)/2)
                    let (date,time) = wallInput(wall,TimeZone(secondsFromGMT:0)!)
                    probe(id+":middle",after>before ? "synthetic-gap-probe":"synthetic-fold-probe",date,time,zoneName,
                          extra:["transitionID":id,"position":"middle"])
                }
                cursor=next
            }
        }
        var values = [Double](repeating:0,count:6)
        var errorBuffer = [CChar](repeating:0,count:256)
        var versionBuffer = [CChar](repeating:0,count:256)
        _ = SwissEphemerisAccess.swe_version(&versionBuffer)
        let eduJD = try julianDayFromLocal(birthDate:"1976-10-11",birthTime:"20:33",timezoneName:"Europe/Madrid").jd
        let flags = SwissEphemerisAccess.swe_calc_ut(eduJD,SE_SUN,SEFLG_SPEED,&values,&errorBuffer)
        let metadata: [String:Any] = [
            "swissEphemerisVersion":String(cString:versionBuffer),
            "sunCalculationReturnedFlags":Int(flags),
            "sunEphemerisBackend":(flags & SEFLG_MOSEPH) != 0 ? "Moshier" : ((flags & SEFLG_SWIEPH) != 0 ? "Swiss files" : "other"),
            "sunCalculationDiagnostic":String(cString:errorBuffer),
            "commit":"edd8912847723707aaf52f538b5f5b5a669c4f82",
            "method":"julianDayFromLocal → localDateFromBirthData (Foundation Gregorian/IANA) → SwissEphemerisAccess.swe_julday(SE_GREG_CAL)",
            "tzdataVersion":TimeZone.timeZoneDataVersion,
            "operatingSystem":ProcessInfo.processInfo.operatingSystemVersionString,
            "swiftVersion":ProcessInfo.processInfo.environment["F1_SWIFT_VERSION"] ?? "unspecified",
            "transitionDiscovery":"Mac Foundation offsets sampled every 6h, bisected to 1s; UTC source metadata is not a forced fold policy",
            "natalMethod":"Exact makeNatalChart and pdFixtures from PrimaryDirectionsGoldenTests; configure(ephePath:nil); Placidus; fixed UUIDs and createdAt epoch",
            "meaning":"Platform baseline for parity, not independent validation of historical civil-time law; synthetic probes are not birth charts"
        ]
        var data = try JSONSerialization.data(withJSONObject:["metadata":metadata,"transitions":transitions,"cases":rows],options:[.sortedKeys,.withoutEscapingSlashes])
        data.append(0x0A)
        try data.write(to:directory.appendingPathComponent("time-reference.compact.json"))
        XCTAssertGreaterThan(rows.count,100)
        print("F1_EXPORT cases=\(rows.count) transitions=\(transitions.count) tzdata=\(TimeZone.timeZoneDataVersion)")
    }
}
