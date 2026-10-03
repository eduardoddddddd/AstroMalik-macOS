import XCTest
import SwiftUI
#if canImport(AstroMalikCore)
@testable import AstroMalikCore
#else
@testable import AstroMalik
#endif

final class AstroMapStyleTrackerTests: XCTestCase {
    private let sun = AstroLineID(body: .sun, angle: .mc)
    private let moon = AstroLineID(body: .moon, angle: .asc)
    private let mars = AstroLineID(body: .mars, angle: .ic)

    func testUnchangedRefreshesRestyleNothingSoTabSwitchesDoNotRedrawTheMap() {
        var tracker = AstroMapStyleTracker()
        var desired: [AstroLineID: AstroOverlayStyleKey] = [:]
        for id in [sun, moon, mars] { desired[id] = AstroOverlayStyleKey(selected: false, emphasized: nil) }
        XCTAssertEqual(tracker.stale(desired: desired).count, 3, "first pass styles everything")
        for (id, key) in desired { tracker.record(id, key) }
        // SwiftUI refreshes the representable many times (tab switch, typing, state): nothing may be restyled.
        for _ in 0..<50 { XCTAssertTrue(tracker.stale(desired: desired).isEmpty) }
    }

    func testOnlyLinesWhoseSelectionOrEmphasisChangedAreRestyled() {
        var tracker = AstroMapStyleTracker()
        var desired: [AstroLineID: AstroOverlayStyleKey] = [sun: .init(selected: false, emphasized: nil), moon: .init(selected: false, emphasized: nil),
                                                          mars: .init(selected: false, emphasized: nil)]
        for (id, key) in desired { tracker.record(id, key) }
        desired[sun] = .init(selected: true, emphasized: nil)
        XCTAssertEqual(tracker.stale(desired: desired), [sun])
        tracker.record(sun, desired[sun]!)
        desired = [sun: .init(selected: true, emphasized: true), moon: .init(selected: false, emphasized: false), mars: .init(selected: false, emphasized: false)]
        XCTAssertEqual(Set(tracker.stale(desired: desired)), [sun, moon, mars], "entering emphasis mode changes all three")
        for (id, key) in desired { tracker.record(id, key) }
        XCTAssertTrue(tracker.stale(desired: desired).isEmpty)
        // Leaving emphasis mode restyles again, back to normal.
        desired = desired.mapValues { AstroOverlayStyleKey(selected: $0.selected, emphasized: nil) }
        XCTAssertEqual(tracker.stale(desired: desired).count, 3)
    }

    func testRemovedLinesAreForgottenAndStyledAgainWhenTheyReturnOrAfterReset() {
        var tracker = AstroMapStyleTracker()
        let normal = AstroOverlayStyleKey(selected: false, emphasized: nil)
        tracker.record(sun, normal); tracker.record(moon, normal)
        XCTAssertTrue(tracker.stale(desired: [sun: normal]).isEmpty) // moon filtered out
        XCTAssertEqual(tracker.stale(desired: [sun: normal, moon: normal]), [moon], "moon returns as a new overlay: must be styled")
        tracker.record(moon, normal)
        tracker.reset()
        XCTAssertEqual(tracker.stale(desired: [sun: normal, moon: normal]).count, 2, "new revision: everything is new")
    }

    func testMapContainerIgnoresBindingsAndCallbacksButNotRealInputs() throws {
        let line = AstroVisualLine(id: sun, segments: [])
        func container(lines: [AstroVisualLine] = [AstroVisualLine(id: AstroLineID(body: .sun, angle: .mc), segments: [])], revision: String = "r1",
                       selected: AstroLineID? = nil, place: GeoCoordinate? = nil, emphasis: Set<AstroLineID>? = nil,
                       camera: UUID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, focus: Bool = false,
                       callback: @escaping (String?) -> Void = { _ in }) -> AstroMapContainer {
            AstroMapContainer(lines: lines, revision: revision, selectedLine: .constant(selected), selectedPlace: .constant(place),
                              emphasizedLines: emphasis, cameraCommand: camera, focusPlace: focus, onMapError: callback)
        }
        _ = line
        let base = container()
        XCTAssertEqual(base, container(callback: { _ in print("different closure") }), "a tab switch re-creates closures and bindings: must not count")
        XCTAssertNotEqual(base, container(revision: "r2"))
        XCTAssertNotEqual(base, container(lines: []))
        XCTAssertNotEqual(base, container(selected: sun))
        XCTAssertNotEqual(base, container(place: try GeoCoordinate(latitude: 1, longitude: 2)))
        XCTAssertNotEqual(base, container(emphasis: [sun]))
        XCTAssertNotEqual(base, container(camera: UUID()))
        XCTAssertNotEqual(base, container(focus: true))
    }
}
