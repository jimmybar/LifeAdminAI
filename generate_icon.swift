import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

func generateAppIcon() {
    let size = CGSize(width: 1024, height: 1024)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: nil,
        width: Int(size.width),
        height: Int(size.height),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        print("Failed to create CGContext")
        return
    }

    // 1. Background Fill (Green #1EB168)
    context.setFillColor(CGColor(red: 30/255.0, green: 177/255.0, blue: 104/255.0, alpha: 1.0))
    context.fill(CGRect(origin: .zero, size: size))

    // 2. White Document Sheet
    // Document bounds
    let docRect = CGRect(x: 232, y: 160, width: 560, height: 704)
    let foldSize: CGFloat = 110.0
    let cornerRadius: CGFloat = 40.0

    let path = CGMutablePath()
    // Start top left
    path.move(to: CGPoint(x: docRect.minX + cornerRadius, y: docRect.maxY))
    // Top line to fold start
    path.addLine(to: CGPoint(x: docRect.maxX - foldSize, y: docRect.maxY))
    // Diagonal fold line
    path.addLine(to: CGPoint(x: docRect.maxX, y: docRect.maxY - foldSize))
    // Right edge
    path.addLine(to: CGPoint(x: docRect.maxX, y: docRect.minY + cornerRadius))
    // Bottom right corner
    path.addArc(tangent1End: CGPoint(x: docRect.maxX, y: docRect.minY), tangent2End: CGPoint(x: docRect.maxX - cornerRadius, y: docRect.minY), radius: cornerRadius)
    // Bottom edge
    path.addLine(to: CGPoint(x: docRect.minX + cornerRadius, y: docRect.minY))
    // Bottom left corner
    path.addArc(tangent1End: CGPoint(x: docRect.minX, y: docRect.minY), tangent2End: CGPoint(x: docRect.minX, y: docRect.minY + cornerRadius), radius: cornerRadius)
    // Left edge
    path.addLine(to: CGPoint(x: docRect.minX, y: docRect.maxY - cornerRadius))
    // Top left corner
    path.addArc(tangent1End: CGPoint(x: docRect.minX, y: docRect.maxY), tangent2End: CGPoint(x: docRect.minX + cornerRadius, y: docRect.maxY), radius: cornerRadius)
    path.closeSubpath()

    // Shadow for document
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -10), blur: 20, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.15))
    context.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0))
    context.addPath(path)
    context.fillPath()
    context.restoreGState()

    // Fold flap (Light Blue #BFDBFE)
    let foldPath = CGMutablePath()
    foldPath.move(to: CGPoint(x: docRect.maxX - foldSize, y: docRect.maxY))
    foldPath.addLine(to: CGPoint(x: docRect.maxX - foldSize, y: docRect.maxY - foldSize))
    foldPath.addLine(to: CGPoint(x: docRect.maxX, y: docRect.maxY - foldSize))
    foldPath.closeSubpath()

    context.setFillColor(CGColor(red: 191/255.0, green: 219/255.0, blue: 254/255.0, alpha: 1.0))
    context.addPath(foldPath)
    context.fillPath()

    // 3. Document content lines (Rounded Blue-Gray #64748B)
    context.setFillColor(CGColor(red: 100/255.0, green: 116/255.0, blue: 139/255.0, alpha: 0.9))
    
    let line1 = CGRect(x: 320, y: 680, width: 320, height: 44)
    let line2 = CGRect(x: 320, y: 590, width: 380, height: 44)
    let line3 = CGRect(x: 480, y: 500, width: 220, height: 44)

    for line in [line1, line2, line3] {
        let linePath = CGPath(roundedRect: line, cornerWidth: 22, cornerHeight: 22, transform: nil)
        context.addPath(linePath)
        context.fillPath()
    }

    // 4. Overlapping Green Leaf at bottom-left corner
    let leafPath = CGMutablePath()
    let leafStart = CGPoint(x: 180, y: 160)
    leafPath.move(to: leafStart)
    // Curve to top of leaf
    leafPath.addCurve(
        to: CGPoint(x: 300, y: 560),
        control1: CGPoint(x: 170, y: 380),
        control2: CGPoint(x: 210, y: 520)
    )
    // Curve down right to bottom tip
    leafPath.addCurve(
        to: CGPoint(x: 640, y: 160),
        control1: CGPoint(x: 440, y: 520),
        control2: CGPoint(x: 580, y: 280)
    )
    // Curve back to start
    leafPath.addCurve(
        to: leafStart,
        control1: CGPoint(x: 480, y: 160),
        control2: CGPoint(x: 300, y: 160)
    )
    leafPath.closeSubpath()

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: 8), blur: 15, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.2))
    context.setFillColor(CGColor(red: 34/255.0, green: 197/255.0, blue: 94/255.0, alpha: 1.0))
    context.addPath(leafPath)
    context.fillPath()
    context.restoreGState()

    guard let cgImage = context.makeImage() else { return }
    let destURL = URL(fileURLWithPath: "AppIcon1024.png") as CFURL
    guard let destination = CGImageDestinationCreateWithURL(destURL, UTType.png.identifier as CFString, 1, nil) else { return }
    CGImageDestinationAddImage(destination, cgImage, nil)
    CGImageDestinationFinalize(destination)
    print("Successfully generated AppIcon1024.png!")
}

generateAppIcon()
