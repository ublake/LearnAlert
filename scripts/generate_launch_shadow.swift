import Foundation
import CoreGraphics

// A code-native soft shadow for the static launch storyboard, which cannot
// execute CALayer runtime attributes. The original logo image stays untouched.
let directory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("LearnAlert/Assets.xcassets/LaunchLogoShadow.imageset")
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
var bounds = CGRect(x: 0, y: 0, width: 144, height: 144)
let context = CGContext(directory.appendingPathComponent("shadow.pdf") as CFURL, mediaBox: &bounds, nil)!
context.beginPDFPage(nil)
context.translateBy(x: 72, y: 68)
context.scaleBy(x: 1, y: 0.78)
let colors = [CGColor(gray: 0, alpha: 0.18), CGColor(gray: 0, alpha: 0.07), CGColor(gray: 0, alpha: 0)]
let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceGray(), colors: colors as CFArray, locations: [0, 0.6, 1])!
context.drawRadialGradient(gradient, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: 66, options: [])
context.endPDFPage()
context.closePDF()
