import XCTest
import Foundation
import CSwissEph
@testable import AstroMalik
final class F2BackendProbeTests: XCTestCase {
    func testOriginalCLIBackend() async throws {
        let out=try XCTUnwrap(ProcessInfo.processInfo.environment["F2_BACKEND_PROBE_OUT"])
        let dbPath=URL(fileURLWithPath:out).deletingLastPathComponent().appendingPathComponent("runtime-cli-backend/user.db")
        try FileManager.default.createDirectory(at:dbPath.deletingLastPathComponent(),withIntermediateDirectories:true)
        let db=try SQLiteDB(path:dbPath.path)
        try SavedChartRecord.createTable(db:db)
        try SavedChartRecord.migrateMetadataColumns(db:db)
        let reference=ISO8601DateFormatter().date(from:"2026-10-04T00:00:00Z")!
        let cli=try await AstroMalikCLIRunner.run(request:AstroMalikCLIRequest(command:.chartsList,referenceDate:reference,userDBPath:dbPath.path))
        XCTAssertFalse(cli.networkUsed)
        let jd=try julianDayFromLocal(birthDate:"1976-10-11",birthTime:"20:33",timezoneName:"Europe/Madrid").jd
        var rows:[[String:Any]]=[]
        for planet in PLANET_LIST {
            var v=[Double](repeating:0,count:6);var e=[CChar](repeating:0,count:256)
            let flags=SwissEphemerisAccess.swe_calc_ut(jd,planet.id,SEFLG_SPEED,&v,&e)
            XCTAssertGreaterThanOrEqual(flags,0)
            rows.append(["planet":planet.key,"requestedFlags":Int(SEFLG_SPEED),"returnedFlags":Int(flags),"backend":(flags & SEFLG_SWIEPH) != 0 ? "swiss-files":((flags & SEFLG_MOSEPH) != 0 ? "moshier":"other"),"diagnostic":String(cString:e)])
        }
        let ephe=AppResources.bundle.url(forResource:"sepl_18",withExtension:"se1",subdirectory:"ephe")
        let r:[String:Any]=["engineCommit":"edd8912847723707aaf52f538b5f5b5a669c4f82","measurement":"original CLI.run charts.list on isolated DB invokes its private configureEphemeris; then original swe_calc_ut on existing Eduardo fixture","probeBuild":"debug XCTest; release resource hashes checked separately","fixture":"existing F1 Eduardo","julianDay":jd,"resourceBundle":AppResources.bundle.bundleURL.path,"sepl18":ephe?.path ?? NSNull(),"planets":rows]
        var d=try JSONSerialization.data(withJSONObject:r,options:[.sortedKeys]);d.append(0x0A);try d.write(to:URL(fileURLWithPath:out))
    }
}
