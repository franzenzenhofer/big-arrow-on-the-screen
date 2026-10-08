import CoreGraphics

/// The one colour space every bitmap in this project is drawn in.
public enum ColorSpaces {
    public static var sRGB: CGColorSpace {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else {
            preconditionFailure("the sRGB colour space is missing from CoreGraphics")
        }
        return space
    }
}
