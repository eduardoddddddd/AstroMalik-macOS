import AppKit
import SwiftUI
import CryptoKit

@MainActor
enum F2ScreenCaptureCoordinator {
    private static let sourceCommit = "edd8912847723707aaf52f538b5f5b5a669c4f82"
    private static let inventoryURL = URL(fileURLWithPath: "/Users/eduardoariasbravo/.codex/worktrees/windows-f1-mac-reference/AstroMalik-macOS/docs/windows-f2a-transport/fixtures/inputs/f2/screens-inventory.json")
    private static let outputURL = URL(fileURLWithPath: "/Users/eduardoariasbravo/.codex/worktrees/windows-f1-mac-reference/AstroMalik-macOS/docs/windows-f2a-reference/fixtures/mac/screens", isDirectory: true)

    private static let routes: [(String, NavItem)] = [
        ("nueva-carta", .nuevaCarta), ("cartas", .cartas), ("lectura", .lectura),
        ("rectificacion", .rectificacion), ("transitos", .transitos), ("progresiones", .progresiones),
        ("direcciones-primarias", .direccionesPrimarias), ("profecciones", .profecciones),
        ("firdaria", .firdaria), ("zodiacal-releasing", .zodiacalReleasing),
        ("revolucion-solar", .revolucionSolar), ("revolucion-lunar", .revolucionLunar),
        ("panorama-predictivo", .crossPersonal), ("sinastria", .sinastria), ("horaria", .horaria),
        ("astrocartografia", .astrocartografia), ("efemerides", .efemerides),
        ("informes", .misInformes), ("ajustes", .ajustes),
    ]

    static func run(appState: AppState) async {
        guard F2CaptureSandbox.isEnabled,
              let window = NSApp.windows.first(where: { $0.contentView != nil && $0.windowNumber > 0 }) else { return }

        let deadline = Date().addingTimeInterval(15)
        while appState.userStore.savedCharts.isEmpty && Date() < deadline {
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
        let chart = appState.userStore.savedCharts.first(where: { $0.name == "Eduardo" })
            ?? appState.userStore.savedCharts.first
        appState.activeNatalChart = chart
        appState.appearanceMode = .light
        if let start = isoDate("2026-10-04T00:00:00Z"), let end = isoDate("2027-04-04T00:00:00Z") {
            appState.transitState.fromDate = start
            appState.transitState.toDate = end
        }
        if let screen = window.screen {
            window.setFrame(screen.visibleFrame, display: true)
        }

        guard let data = try? Data(contentsOf: inventoryURL),
              let manifest = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let screens = manifest["screens"] as? [[String: Any]] else { return }
        let byID = Dictionary(uniqueKeysWithValues: screens.compactMap { screen -> (String, [String: Any])? in
            guard let id = screen["id"] as? String else { return nil }
            return (id, screen)
        })
        try? FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

        for (id, nav) in routes {
            let pngURL = outputURL.appendingPathComponent("\(id).png")
            let jsonURL = outputURL.appendingPathComponent("\(id).json")
            guard !FileManager.default.fileExists(atPath: pngURL.path),
                  !FileManager.default.fileExists(atPath: jsonURL.path) else { continue }

            appState.selectedNav = nav
            appState.showDefaultDetail(for: nav)
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            if nav == .transitos {
                let transitDeadline = Date().addingTimeInterval(45)
                while appState.transitState.isCalculating && Date() < transitDeadline {
                    try? await Task.sleep(nanoseconds: 250_000_000)
                }
                try? await Task.sleep(nanoseconds: 750_000_000)
            }
            window.contentView?.layoutSubtreeIfNeeded()
            guard let view = window.contentView,
                  let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { continue }
            view.cacheDisplay(in: view.bounds, to: bitmap)
            guard let png = bitmap.representation(using: .png, properties: [:]) else { continue }
            do {
                try png.write(to: pngURL, options: .atomic)
                let entry = byID[id] ?? [:]
                let observed = observedState(id: id, chart: chart, appState: appState)
                let record: [String: Any] = [
                    "kind": "authentic-mac-view-capture",
                    "captureMethod": "NSView.bitmapImageRepForCachingDisplay/cacheDisplay on the live AstroMalik SwiftUI app window; no other desktop windows captured",
                    "screen": entry,
                    "macCommit": sourceCommit,
                    "capturedAt": ISO8601DateFormatter().string(from: Date()),
                    "operatingSystem": ProcessInfo.processInfo.operatingSystemVersionString,
                    "windowID": window.windowNumber,
                    "observedState": observed,
                    "theme": "light",
                    "width": bitmap.pixelsWide,
                    "height": bitmap.pixelsHigh,
                    "sha256": sha256(png),
                ]
                let json = try JSONSerialization.data(withJSONObject: record, options: [.prettyPrinted, .sortedKeys])
                try json.write(to: jsonURL, options: .atomic)
                NSLog("[F2Capture] %@ %dx%d sha256=%@", id, bitmap.pixelsWide, bitmap.pixelsHigh, sha256(png))
            } catch {
                NSLog("[F2Capture] %@ failed: %@", id, String(describing: error))
            }
        }
    }

    private static func observedState(id: String, chart: NatalChart?, appState: AppState) -> String {
        let chartName = chart?.name ?? "none"
        switch id {
        case "nueva-carta": return "Birth form, blank initial state; no calculation submitted."
        case "cartas": return "Saved charts screen; \(appState.userStore.savedCharts.count) isolated F1 test charts; selected chart \(chartName)."
        case "lectura": return "Natal reading screen for \(chartName); local corpus view, no LLM request."
        case "rectificacion": return "Rectification screen in its real default state; synthetic case not submitted."
        case "transitos": return "Transit screen for \(chartName); UTC range 2026-10-04 through 2027-04-04; events=\(appState.transitState.events.count), houseIngresses=\(appState.transitState.houseIngresses.count), calculating=\(appState.transitState.isCalculating)."
        case "sinastria": return "Synastry screen in its actual default state; no relationship asserted."
        case "horaria": return "Horary new-query screen; test question not submitted."
        case "informes": return "Reports screen in isolated account; only current visible state captured."
        case "ajustes": return "Settings screen in unique capture bundle preferences domain; credentials not loaded."
        default: return "Real \(NavItem.allCases.first(where: { $0.label == label(for: id) })?.label ?? id) screen for \(chartName) where supported; defaults visible, calculation status allowed to settle for 2.5 seconds."
        }
    }

    private static func label(for id: String) -> String {
        routes.first(where: { $0.0 == id })?.1.label ?? id
    }

    private static func isoDate(_ value: String) -> Date? {
        ISO8601DateFormatter().date(from: value)
    }

    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
