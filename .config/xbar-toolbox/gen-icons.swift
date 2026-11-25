import AppKit

let dir = NSString(string: "~/.config/xbar-toolbox").expandingTildeInPath
let args = CommandLine.arguments

// MARK: - Copilot donut-chart icon
// Usage: swift gen-icons.swift copilot <percentage>
// Prints a base64-encoded PNG to stdout.

func copilotIcon(percentage: Double) -> String {
    let isDark = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
    let normalColor: NSColor = isDark
        ? .white
        : NSColor(srgbRed: 30/255, green: 30/255, blue: 30/255, alpha: 1)

    let clamped = max(0.0, min(100.0, percentage))
    let revealedColor: NSColor = {
        guard clamped > 75 else {
            return NSColor(srgbRed: 144/255, green: 152/255, blue: 158/255, alpha: 1)
        }
        let t = CGFloat((clamped - 75) / 25)
        return NSColor(srgbRed: (144 + (197-144)*t)/255,
                       green:   (152 + (17-152)*t)/255,
                       blue:    (158 + (30-158)*t)/255, alpha: 1)
    }()

    let ptSize: CGFloat = 18
    let px = Int(ptSize * 2)  // 36px @2x
    let bmp = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    bmp.size = NSSize(width: ptSize, height: ptSize)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bmp)

    let center = NSPoint(x: ptSize/2, y: ptSize/2)
    let outerR: CGFloat = ptSize/2 - 1  // 8pt, 1pt border
    let innerR: CGFloat = outerR / 2    // 4pt donut hole

    func donutPath() -> NSBezierPath {
        let p = NSBezierPath()
        p.windingRule = .evenOdd
        p.appendArc(withCenter: center, radius: outerR, startAngle: 0, endAngle: 360)
        p.appendArc(withCenter: center, radius: innerR, startAngle: 0, endAngle: 360)
        return p
    }

    // Full ring in normal color (the "remaining" foreground)
    normalColor.setFill()
    donutPath().fill()

    // Revealed sector (clockwise from 12 o'clock), clipped to the donut shape
    if clamped > 0 {
        donutPath().setClip()
        revealedColor.setFill()
        let endAngle = 90 - CGFloat(clamped / 100.0 * 360.0)
        let wedge = NSBezierPath()
        wedge.move(to: center)
        wedge.appendArc(withCenter: center, radius: outerR + 1,
                        startAngle: 90, endAngle: endAngle, clockwise: true)
        wedge.close()
        wedge.fill()
    }

    NSGraphicsContext.restoreGraphicsState()
    return bmp.representation(using: .png, properties: [:])!.base64EncodedString()
}

if args.count >= 3, args[1] == "copilot", let pct = Double(args[2]) {
    print(copilotIcon(percentage: pct))
    exit(0)
}

// MARK: - Gear + battery static icons (run with no arguments)

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
    let scale = NSAffineTransform(); scale.scale(by: 0.5); scale.concat()
    gear.draw(in: NSRect(x: 0, y: (h - gear.pixelsHigh) / 2, width: gear.pixelsWide, height: gear.pixelsHigh))
    NSColor.black.setStroke(); NSColor.black.setFill()
    let bx = Double(gear.pixelsWide + gap), by = Double(h - batH) / 2
    let outline = NSBezierPath(roundedRect: NSRect(x: bx+1, y: by+1, width: 44, height: 22), xRadius: 6, yRadius: 6)
    outline.lineWidth = 2; outline.stroke()
    NSBezierPath(roundedRect: NSRect(x: bx+47, y: by+8, width: 4, height: 8), xRadius: 2, yRadius: 2).fill()
    let fillW = 36.0 * Double(level) / 100
    if fillW > 0 {
        NSBezierPath(roundedRect: NSRect(x: bx+5, y: by+5, width: max(fillW, 3), height: 14), xRadius: 2, yRadius: 2).fill()
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for name in ["gear", "gear-on"] {
    let gear = loadGear(name)
    for level in stride(from: 0, through: 100, by: 10) {
        let png = render(gear: gear, level: level)
        try! png.base64EncodedString().write(toFile: "\(dir)/\(name)-bat-\(level).b64", atomically: true, encoding: .utf8)
    }
}
