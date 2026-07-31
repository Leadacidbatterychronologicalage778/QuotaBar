#!/usr/bin/env swift

import AppKit
import CoreGraphics
import Foundation

let projectRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconSetURL = projectRoot
    .appendingPathComponent("Sources/QuotaBar/Resources/Assets.xcassets/AppIcon.appiconset")

try FileManager.default.createDirectory(
    at: iconSetURL,
    withIntermediateDirectories: true
)

let outputs: [(pixels: Int, filename: String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png")
]

func renderIcon(pixels: Int) throws -> Data {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: nil,
        width: pixels,
        height: pixels,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw NSError(domain: "QuotaBarIcon", code: 1)
    }

    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)

    let size = CGFloat(pixels)
    context.clear(CGRect(x: 0, y: 0, width: size, height: size))

    let outerRect = CGRect(
        x: size * 0.055,
        y: size * 0.055,
        width: size * 0.89,
        height: size * 0.89
    )
    let outerPath = CGPath(
        roundedRect: outerRect,
        cornerWidth: size * 0.22,
        cornerHeight: size * 0.22,
        transform: nil
    )

    context.saveGState()
    context.addPath(outerPath)
    context.clip()

    let backgroundColors = [
        CGColor(red: 0.075, green: 0.105, blue: 0.16, alpha: 1),
        CGColor(red: 0.015, green: 0.024, blue: 0.045, alpha: 1)
    ] as CFArray
    let gradient = CGGradient(
        colorsSpace: colorSpace,
        colors: backgroundColors,
        locations: [0, 1]
    )!
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: size * 0.18, y: size * 0.9),
        end: CGPoint(x: size * 0.82, y: size * 0.1),
        options: []
    )

    context.restoreGState()

    context.addPath(outerPath)
    context.setStrokeColor(CGColor(gray: 1, alpha: 0.10))
    context.setLineWidth(size * 0.012)
    context.strokePath()

    let center = CGPoint(x: size * 0.5, y: size * 0.5)
    let radius = size * 0.265
    let lineWidth = size * 0.102

    context.setLineCap(.round)
    context.setLineWidth(lineWidth)
    context.setStrokeColor(CGColor(gray: 1, alpha: 0.16))
    context.addArc(
        center: center,
        radius: radius,
        startAngle: 0,
        endAngle: .pi * 2,
        clockwise: false
    )
    context.strokePath()

    context.setStrokeColor(
        CGColor(red: 0.20, green: 0.94, blue: 0.56, alpha: 1)
    )
    context.addArc(
        center: center,
        radius: radius,
        startAngle: -.pi / 2,
        endAngle: -.pi / 2 + (.pi * 2 * 0.72),
        clockwise: false
    )
    context.strokePath()

    context.setFillColor(CGColor(gray: 1, alpha: 0.96))
    context.fillEllipse(
        in: CGRect(
            x: center.x - size * 0.052,
            y: center.y - size * 0.052,
            width: size * 0.104,
            height: size * 0.104
        )
    )

    guard
        let image = context.makeImage(),
        let representation = NSBitmapImageRep(cgImage: image)
            .representation(using: .png, properties: [:])
    else {
        throw NSError(domain: "QuotaBarIcon", code: 2)
    }

    return representation
}

for output in outputs {
    let data = try renderIcon(pixels: output.pixels)
    try data.write(to: iconSetURL.appendingPathComponent(output.filename))
}

print("Generated \(outputs.count) icon files at \(iconSetURL.path)")
