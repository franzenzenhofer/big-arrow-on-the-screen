// Crops a screenshot of a backdrop --cover scene to its content plus a margin.
// usage: autocrop <in.png> <out.png> [margin-px]
// Content = pixels that differ from the corner colour; the top 3 % (recording indicator) is ignored.
import AppKit

let args = CommandLine.arguments
guard args.count >= 3, let image = NSImage(contentsOfFile: args[1]), let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff) else {
    FileHandle.standardError.write(Data("usage: autocrop <in.png> <out.png> [margin-px]\n".utf8))
    exit(2)
}
let margin = args.count > 3 ? Int(args[3]) ?? 80 : 80
let (width, height) = (bitmap.pixelsWide, bitmap.pixelsHigh)
guard let background = bitmap.colorAt(x: 4, y: height - 4) else { exit(1) }
func differs(_ x: Int, _ y: Int) -> Bool {
    guard let color = bitmap.colorAt(x: x, y: y) else { return false }
    let delta = abs(color.redComponent - background.redComponent) + abs(color.greenComponent - background.greenComponent)
        + abs(color.blueComponent - background.blueComponent)
    return delta > 0.08
}
var (minX, minY, maxX, maxY) = (width, height, 0, 0)
for y in stride(from: height * 3 / 100, to: height, by: 2) {
    for x in stride(from: 0, to: width, by: 2) where differs(x, y) {
        minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
    }
}
let crop = NSRect(x: max(minX - margin, 0), y: max(minY - margin, 0),
                  width: min(maxX + margin, width) - max(minX - margin, 0),
                  height: min(maxY + margin, height) - max(minY - margin, 0))
guard let cgImage = bitmap.cgImage, let cropped = cgImage.cropping(to: crop) else { exit(1) }
let out = NSBitmapImageRep(cgImage: cropped)
try out.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: args[2]))
print("\(Int(crop.width))x\(Int(crop.height))")
