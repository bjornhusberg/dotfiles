import AppKit

// Generates gear+battery composite template icons (base64 PNG, 144 DPI) for the toolbox plugin.
let dir = NSString(string: "~/.config/xbar-toolbox").expandingTildeInPath

func loadGear(_ name: String) -> NSBitmapImageRep {
    let b64 = try! String(contentsOfFile: "\(dir)/\(name).b64").trimmingCharacters(in: .whitespacesAndNewlines)
    return NSBitmapImageRep(data: Data(base64Encoded: b64)!)!
}

func render(gear: NSBitmapImageRep, level: Int) -> Data {
    let batW = 51, batH = 24, gap = 32
    let w = gear.pixelsWide + gap + batW, h = max(gear.pixelsHigh, batH)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: Double(w) / 2, height: Double(h) / 2)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    // The rep's user space is in points (2 px each); work in pixels below.
    let scale = NSAffineTransform(); scale.scale(by: 0.5); scale.concat()
    gear.draw(in: NSRect(x: 0, y: (h - gear.pixelsHigh) / 2, width: gear.pixelsWide, height: gear.pixelsHigh))
    NSColor.black.setStroke(); NSColor.black.setFill()
    let bx = Double(gear.pixelsWide + gap), by = Double(h - batH) / 2
    let body = NSRect(x: bx + 1, y: by + 1, width: 44, height: 22)
    let outline = NSBezierPath(roundedRect: body, xRadius: 6, yRadius: 6)
    outline.lineWidth = 2
    outline.stroke()
    NSBezierPath(roundedRect: NSRect(x: bx + 47, y: by + 8, width: 4, height: 8), xRadius: 2, yRadius: 2).fill()
    let fillW = 36.0 * Double(level) / 100
    if fillW > 0 {
        NSBezierPath(roundedRect: NSRect(x: bx + 5, y: by + 5, width: max(fillW, 3), height: 14), xRadius: 2, yRadius: 2).fill()
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for name in ["gear", "gear-on"] {
    let gear = loadGear(name)
    for level in stride(from: 0, through: 100, by: 10) {
        let png = render(gear: gear, level: level)
        try! png.base64EncodedString().write(toFile: "\(dir)/\(name)-bat-\(level).b64", atomically: true, encoding: .utf8)
        if level == 30 && name == "gear" { try! png.write(to: URL(fileURLWithPath: "/tmp/bat30.png")) }
    }
}
