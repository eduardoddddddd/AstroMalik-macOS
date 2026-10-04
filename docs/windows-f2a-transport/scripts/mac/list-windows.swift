// Read-only inventory of AstroMalik windows; run with swift on the Mac.
import Foundation
import CoreGraphics

let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
let matches = windows.filter { ($0[kCGWindowOwnerName as String] as? String ?? "").lowercased().contains("astromalik") }
let rows = matches.map { window in
    ["windowID": window[kCGWindowNumber as String] ?? 0,
     "owner": window[kCGWindowOwnerName as String] ?? "",
     "bounds": window[kCGWindowBounds as String] ?? [:],
     "layer": window[kCGWindowLayer as String] ?? 0]
}
let data = try JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted, .sortedKeys])
print(String(decoding: data, as: UTF8.self))
