// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools contributors

// Generates every PowerTools brand rendition from one definition of the mark.
//
// Upstream kept two hand-made masters (a wordmark PNG and a hand-exported twin
// of the Icon Composer project) that could drift apart silently. The PowerTools
// mark is geometric, so the geometry lives here instead and every rendition is
// derived from it: change `modules` and re-run, and the app icon, the menu bar
// template's source, the in-app brandmark, the Icon Composer vector and the
// documentation logos all move together.
//
//   swift Tools/MakeBrandAssets.swift
//
// Writes (paths relative to the repository root):
//   Resources/Brand/logo.png                              mono master
//   Resources/Brand/AppIcon-Default.png                   1024 colour icon
//   Resources/Brand/AppIcon.icon/Assets/powertools-mark.svg
//   docs/assets/readme/logo.svg  logo-dark.svg  logo.png  logo-dark.png
//   docs/assets/readme/icon.png
//
// Tools/MakeIcon.swift then consumes logo.png and AppIcon-Default.png at build
// time, exactly as before; this tool is run by hand when the mark changes.
import AppKit

// MARK: - The mark
//
// "Bento": one tall module and two stacked ones, on an 84-unit square laid out
// in a 100-unit design space. Asymmetric on purpose — a symmetric 2x2 grid is
// the Windows four-square and the generic "all apps" glyph, and neither is
// ownable. Columns 33 + 9 + 42 = 84; the right column's rows are 37 + 10 + 37.
struct Module {
    var x, y, w, h: CGFloat      // design-space units, y measured downward
    var accent = false           // drawn in the secondary colour when in colour
}

let modules = [
    Module(x: 8,  y: 8,  w: 33, h: 84),
    Module(x: 50, y: 8,  w: 42, h: 37),
    Module(x: 50, y: 55, w: 42, h: 37, accent: true),
]

/// One radius for every module, so they read as cut from the same grid rather
/// than as three unrelated shapes. In design-space units.
let moduleRadius: CGFloat = 9

/// The mark's bounding box in design space, derived rather than assumed so the
/// renditions stay centred if `modules` changes.
let markBounds: CGRect = {
    let minX = modules.map(\.x).min()!, minY = modules.map(\.y).min()!
    let maxX = modules.map { $0.x + $0.w }.max()!
    let maxY = modules.map { $0.y + $0.h }.max()!
    return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
}()

// MARK: - Palette

func hex(_ s: String, alpha: CGFloat = 1) -> NSColor {
    var v: UInt64 = 0
    Scanner(string: s).scanHexInt64(&v)
    return NSColor(srgbRed: CGFloat((v >> 16) & 0xff) / 255,
                   green: CGFloat((v >> 8) & 0xff) / 255,
                   blue: CGFloat(v & 0xff) / 255, alpha: alpha)
}

enum Brand {
    static let lime = "A3E635"        // primary
    static let limeDeep = "65D420"    // primary, shaded / on light grounds
    static let mint = "00E5A0"        // the one module that differs
    static let ink = "0B0C0B"         // near-black ground
    static let surface = "151714"     // lifted ground
}

// MARK: - Raster helpers

func canvas(_ w: Int, _ h: Int) -> NSBitmapImageRep {
    NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h,
                     bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                     isPlanar: false, colorSpaceName: .deviceRGB,
                     bytesPerRow: 0, bitsPerPixel: 0)!
}

/// Runs `body` with a bitmap context focused, in PIXEL coordinates.
///
/// The context is built before `size` is relabelled, which is what keeps the
/// drawing space in pixels; Tools/MakeIcon.swift relies on the same ordering.
/// Getting this backwards silently scales every coordinate.
func render(_ w: Int, _ h: Int, _ body: () -> Void) -> NSBitmapImageRep {
    let rep = canvas(w, h)
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx
    body()
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func write(_ rep: NSBitmapImageRep, to path: String) {
    let url = URL(fileURLWithPath: path)
    try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                             withIntermediateDirectories: true)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        print("failed to encode \(path)"); exit(1)
    }
    do { try data.write(to: url) } catch { print("failed to write \(path): \(error)"); exit(1) }
    print("  \(path)")
}

/// Draws the mark so that `markBounds` maps exactly onto `box`.
/// Design space is y-down; AppKit is y-up, so each module is flipped.
func drawMark(in box: CGRect, color: (Module) -> NSColor) {
    let s = box.width / markBounds.width
    for m in modules {
        let r = CGRect(x: box.minX + (m.x - markBounds.minX) * s,
                       y: box.minY + (markBounds.maxY - m.y - m.h) * s,
                       width: m.w * s, height: m.h * s)
        let radius = moduleRadius * s
        color(m).setFill()
        NSBezierPath(roundedRect: r, xRadius: radius, yRadius: radius).fill()
    }
}

// MARK: - Renditions

/// The full-colour app icon. The squircle, the margins and the layering are
/// baked in, because Tools/MakeIcon.swift maps this file onto every icon size
/// 1:1 rather than re-composing it.
func appIcon(px: Int) -> NSBitmapImageRep {
    let rep = render(px, px) {
        let size = CGFloat(px)
        // macOS draws app icons inset from the canvas; 6% leaves room for the
        // shadow the system adds without the mark looking adrift.
        let body = CGRect(x: size * 0.06, y: size * 0.06,
                          width: size * 0.88, height: size * 0.88)
        let squircle = NSBezierPath(roundedRect: body,
                                    xRadius: body.width * 0.2237,
                                    yRadius: body.width * 0.2237)
        NSGradient(colors: [hex(Brand.surface), hex(Brand.ink)])!.draw(in: squircle, angle: -90)
        NSGraphicsContext.saveGraphicsState()
        squircle.addClip()
        let mark = CGRect(x: body.minX + body.width * 0.20,
                          y: body.minY + body.height * 0.20,
                          width: body.width * 0.60, height: body.height * 0.60)
        drawMark(in: mark) { m in
            m.accent ? hex(Brand.mint) : hex(Brand.lime)
        }
        NSGraphicsContext.restoreGraphicsState()
    }
    rep.size = NSSize(width: px, height: px)
    return rep
}

/// The mono master. Tools/MakeIcon.swift trims this to its visible pixels and
/// fits it into the menu bar canvas and the in-app brandmark, both of which are
/// template images — macOS keeps only the alpha, so this must be a flat
/// silhouette whose gaps are real transparency, never a lighter colour.
func monoMaster(px: Int) -> NSBitmapImageRep {
    let rep = render(px, px) {
        let inset = CGFloat(px) * 0.08
        let box = CGRect(x: inset, y: inset,
                         width: CGFloat(px) - inset * 2, height: CGFloat(px) - inset * 2)
        drawMark(in: box) { _ in .black }
    }
    rep.size = NSSize(width: px, height: px)
    return rep
}

// MARK: - Vector

func svgRects(scale: CGFloat, color: (Module) -> String) -> String {
    modules.map { m in
        let x = (m.x - markBounds.minX) * scale
        let y = (m.y - markBounds.minY) * scale
        return String(format:
            "  <rect x=\"%.3f\" y=\"%.3f\" width=\"%.3f\" height=\"%.3f\" rx=\"%.3f\" fill=\"%@\"/>",
            x, y, m.w * scale, m.h * scale, moduleRadius * scale, color(m))
    }.joined(separator: "\n")
}

/// The bare mark on transparent, for Icon Composer.
///
/// Carries its own brand colour rather than flat black: the catalog only
/// recolours it for the tinted appearance, where macOS wants a monochrome mark
/// it can tint itself. Upstream shipped a black vector and let the catalog fill
/// it, which works only while the mark is a single colour — this one is not.
func markSVG(side: CGFloat = 512) -> String {
    let scale = side / markBounds.width
    return """
    <?xml version="1.0" encoding="UTF-8"?>
    <svg xmlns="http://www.w3.org/2000/svg" width="\(Int(side))" height="\(Int(side))" \
    viewBox="0 0 \(Int(side)) \(Int(side))">
    \(svgRects(scale: scale) { m in "#" + (m.accent ? Brand.mint : Brand.lime) })
    </svg>

    """
}

/// The documentation logo: the mark on its squircle, so what the README shows
/// is what the Dock shows. `onDark` lifts the ground and adds a hairline so it
/// does not vanish against a dark page.
func logoSVG(side: CGFloat = 512, onDark: Bool) -> String {
    let body = side * 0.88, origin = side * 0.06
    let scale = (body * 0.60) / markBounds.width
    let markOrigin = origin + body * 0.20
    let ground = onDark ? Brand.surface : Brand.ink
    let hairline = onDark
        ? "\n  <rect x=\"\(origin)\" y=\"\(origin)\" width=\"\(body)\" height=\"\(body)\" "
          + "rx=\"\(body * 0.2237)\" fill=\"none\" stroke=\"#FFFFFF\" stroke-opacity=\"0.12\" stroke-width=\"\(side * 0.006)\"/>"
        : ""
    let rects = modules.map { m in
        let x = markOrigin + (m.x - markBounds.minX) * scale
        let y = markOrigin + (m.y - markBounds.minY) * scale
        return String(format:
            "  <rect x=\"%.3f\" y=\"%.3f\" width=\"%.3f\" height=\"%.3f\" rx=\"%.3f\" fill=\"#%@\"/>",
            x, y, m.w * scale, m.h * scale, moduleRadius * scale,
            m.accent ? Brand.mint : Brand.lime)
    }.joined(separator: "\n")
    return """
    <?xml version="1.0" encoding="UTF-8"?>
    <svg xmlns="http://www.w3.org/2000/svg" xmlns:dc="http://purl.org/dc/elements/1.1/" \
    width="\(Int(side))" height="\(Int(side))" viewBox="0 0 \(Int(side)) \(Int(side))">
      <metadata><dc:rights>Copyright \u{00A9} 2026 PowerTools contributors. \
    This artwork is PowerTools brand material. It is excluded from the \
    GPL-3.0-or-later license covering the source code and is reserved under \
    TRADEMARKS.md.</dc:rights></metadata>
      <rect x="\(origin)" y="\(origin)" width="\(body)" height="\(body)" \
    rx="\(body * 0.2237)" fill="#\(ground)"/>\(hairline)
    \(rects)
    </svg>

    """
}

// MARK: - Main

let root = URL(fileURLWithPath: CommandLine.arguments[0])
    .deletingLastPathComponent().deletingLastPathComponent().path
FileManager.default.changeCurrentDirectoryPath(root)
print("writing brand renditions:")

write(monoMaster(px: 1024), to: "Resources/Brand/logo.png")
write(appIcon(px: 1024), to: "Resources/Brand/AppIcon-Default.png")
write(appIcon(px: 512), to: "docs/assets/readme/icon.png")

func writeText(_ text: String, to path: String) {
    let url = URL(fileURLWithPath: path)
    try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                             withIntermediateDirectories: true)
    do { try text.write(to: url, atomically: true, encoding: .utf8) }
    catch { print("failed to write \(path): \(error)"); exit(1) }
    print("  \(path)")
}

writeText(markSVG(), to: "Resources/Brand/AppIcon.icon/Assets/powertools-mark.svg")
writeText(logoSVG(onDark: false), to: "docs/assets/readme/logo.svg")
writeText(logoSVG(onDark: true), to: "docs/assets/readme/logo-dark.svg")

/// PNG twins of the documentation logos, for surfaces that will not take SVG.
func logoPNG(px: Int, onDark: Bool) -> NSBitmapImageRep {
    let rep = render(px, px) {
        let size = CGFloat(px)
        let body = CGRect(x: size * 0.06, y: size * 0.06,
                          width: size * 0.88, height: size * 0.88)
        let squircle = NSBezierPath(roundedRect: body,
                                    xRadius: body.width * 0.2237, yRadius: body.width * 0.2237)
        hex(onDark ? Brand.surface : Brand.ink).setFill()
        squircle.fill()
        if onDark {
            hex("FFFFFF", alpha: 0.12).setStroke()
            squircle.lineWidth = size * 0.006
            squircle.stroke()
        }
        let mark = CGRect(x: body.minX + body.width * 0.20, y: body.minY + body.height * 0.20,
                          width: body.width * 0.60, height: body.height * 0.60)
        drawMark(in: mark) { m in m.accent ? hex(Brand.mint) : hex(Brand.lime) }
    }
    rep.size = NSSize(width: px, height: px)
    return rep
}

write(logoPNG(px: 512, onDark: false), to: "docs/assets/readme/logo.png")
write(logoPNG(px: 512, onDark: true), to: "docs/assets/readme/logo-dark.png")
print("done")
