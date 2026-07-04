import AppKit
import CoreGraphics

let S: CGFloat = 1024
let cs = CGColorSpace(name: CGColorSpace.sRGB)!

func c(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: cs, components: [r/255, g/255, b/255, a])!
}

let ctx = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8,
                    bytesPerRow: 0, space: cs,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

// ---- helpers ----------------------------------------------------------------

func superellipse(center: CGPoint, radius a: CGFloat, n: CGFloat = 5, steps: Int = 360) -> CGPath {
    let p = CGMutablePath()
    for i in 0...steps {
        let t = 2 * CGFloat.pi * CGFloat(i) / CGFloat(steps)
        let ct = cos(t), st = sin(t)
        let x = center.x + a * copysign(pow(abs(ct), 2/n), ct)
        let y = center.y + a * copysign(pow(abs(st), 2/n), st)
        if i == 0 { p.move(to: CGPoint(x: x, y: y)) } else { p.addLine(to: CGPoint(x: x, y: y)) }
    }
    p.closeSubpath()
    return p
}

func sparkle(center: CGPoint, outer: CGFloat) -> CGPath {
    // 4-point twinkle with a pinched waist
    let inner = outer * 0.34
    let mid = outer * 0.13
    let p = CGMutablePath()
    let n = 4
    for i in 0..<(n * 2) {
        let r = (i % 2 == 0) ? outer : mid
        let ang = CGFloat.pi / 2 - CGFloat(i) * (CGFloat.pi / CGFloat(n))
        let pt = CGPoint(x: center.x + r * cos(ang), y: center.y + r * sin(ang))
        if i == 0 { p.move(to: pt) } else {
            // pull toward center for concave arms
            let prevAng = CGFloat.pi / 2 - CGFloat(i - 1) * (CGFloat.pi / CGFloat(n))
            let cAng = (ang + prevAng) / 2
            let cp = CGPoint(x: center.x + inner * cos(cAng) * 0.0, y: center.y + inner * sin(cAng) * 0.0)
            _ = cp
            p.addLine(to: pt)
        }
    }
    p.closeSubpath()
    return p
}

func fillGradient(_ path: CGPath, from top: CGColor, to bottom: CGColor, y0: CGFloat, y1: CGFloat) {
    ctx.saveGState()
    ctx.addPath(path); ctx.clip()
    let g = CGGradient(colorsSpace: cs, colors: [top, bottom] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(g, start: CGPoint(x: S/2, y: y0), end: CGPoint(x: S/2, y: y1), options: [])
    ctx.restoreGState()
}

// ---- body (squircle) --------------------------------------------------------

let bodyPath = superellipse(center: CGPoint(x: S/2, y: S/2), radius: 412, n: 5)

// drop shadow behind the body
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -22), blur: 46, color: c(20, 20, 60, 0.34))
ctx.addPath(bodyPath); ctx.setFillColor(c(120, 120, 255)); ctx.fillPath()
ctx.restoreGState()

// body gradient: sky blue -> violet (top-down light)
fillGradient(bodyPath, from: c(122, 190, 255), to: c(150, 120, 246), y0: 924, y1: 100)

// soft top sheen (glassy highlight)
ctx.saveGState()
ctx.addPath(bodyPath); ctx.clip()
let sheen = CGGradient(colorsSpace: cs, colors: [c(255, 255, 255, 0.30), c(255, 255, 255, 0)] as CFArray, locations: [0, 1])!
ctx.drawRadialGradient(sheen, startCenter: CGPoint(x: S/2, y: 830), startRadius: 0,
                       endCenter: CGPoint(x: S/2, y: 830), endRadius: 430, options: [])
// bottom vignette for depth
let vig = CGGradient(colorsSpace: cs, colors: [c(40, 20, 90, 0), c(40, 20, 90, 0.22)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(vig, start: CGPoint(x: S/2, y: 320), end: CGPoint(x: S/2, y: 110), options: [])
ctx.restoreGState()

// subtle inner top rim-light
ctx.saveGState()
ctx.addPath(bodyPath); ctx.clip()
ctx.setStrokeColor(c(255, 255, 255, 0.5))
ctx.setLineWidth(3)
ctx.addPath(superellipse(center: CGPoint(x: S/2, y: S/2 + 2), radius: 410, n: 5))
ctx.strokePath()
ctx.restoreGState()

// ---- cloud ------------------------------------------------------------------

func cloudPath(cx: CGFloat, cy: CGFloat, scale s: CGFloat) -> CGPath {
    let p = CGMutablePath()
    func circle(_ dx: CGFloat, _ dy: CGFloat, _ r: CGFloat) {
        p.addEllipse(in: CGRect(x: cx + dx*s - r*s, y: cy + dy*s - r*s, width: r*2*s, height: r*2*s))
    }
    // plump cotton puff — overlapping circles rounded on all sides (reads as a poof, not a weather cloud)
    circle(0, 8, 116)       // big core
    circle(-118, -6, 74)    // left
    circle(128, -10, 66)    // right
    circle(-58, 78, 78)     // top-left bump
    circle(30, 92, 86)      // top bump
    circle(104, 66, 62)     // top-right bump
    circle(-70, -52, 70)    // bottom-left
    circle(18, -66, 80)     // bottom
    circle(92, -50, 64)     // bottom-right
    return p
}

let cloud = cloudPath(cx: S/2 - 4, cy: 498, scale: 1.02)

// cloud drop shadow on the body
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 26, color: c(30, 20, 80, 0.30))
ctx.addPath(cloud); ctx.setFillColor(c(255, 255, 255)); ctx.fillPath()
ctx.restoreGState()

// cloud volume gradient (white top -> cool bottom)
fillGradient(cloud, from: c(255, 255, 255), to: c(210, 221, 255), y0: 676, y1: 348)

// cloud top highlight
ctx.saveGState()
ctx.addPath(cloud); ctx.clip()
let hl = CGGradient(colorsSpace: cs, colors: [c(255, 255, 255, 0.9), c(255, 255, 255, 0)] as CFArray, locations: [0, 1])!
ctx.drawRadialGradient(hl, startCenter: CGPoint(x: S/2 - 34, y: 590), startRadius: 0,
                       endCenter: CGPoint(x: S/2 - 34, y: 590), endRadius: 176, options: [])
ctx.restoreGState()

// ---- sparkles ---------------------------------------------------------------

func drawSparkle(_ center: CGPoint, _ outer: CGFloat, _ col: CGColor) {
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 18, color: c(255, 245, 200, 0.9))
    ctx.addPath(sparkle(center: center, outer: outer))
    ctx.setFillColor(col)
    ctx.fillPath()
    ctx.restoreGState()
}

drawSparkle(CGPoint(x: 752, y: 672), 60, c(255, 244, 180))
drawSparkle(CGPoint(x: 806, y: 560), 32, c(255, 255, 255))
drawSparkle(CGPoint(x: 292, y: 648), 40, c(255, 250, 210))

// ---- write PNG --------------------------------------------------------------

let img = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: img)
let data = rep.representation(using: .png, properties: [:])!
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"
try! data.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
