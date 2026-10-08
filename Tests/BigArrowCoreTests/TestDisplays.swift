import BigArrowCore
import CoreGraphics

/// The real display geometry of the Mac this project was planned on (2026-10-08):
/// built-in 1512x982@2x, two 1920x1080@1x to the right, 98 pt higher.
enum TestDisplays {
    static let appKit = [
        AppKitScreen(id: 1, frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
                     visibleFrame: CGRect(x: 0, y: 0, width: 1512, height: 949), scale: 2),
        AppKitScreen(id: 2, frame: CGRect(x: 1512, y: 0, width: 1920, height: 1080),
                     visibleFrame: CGRect(x: 1512, y: 0, width: 1920, height: 1055), scale: 1),
        AppKitScreen(id: 3, frame: CGRect(x: 3432, y: 0, width: 1920, height: 1080),
                     visibleFrame: CGRect(x: 3432, y: 0, width: 1920, height: 1055), scale: 1)
    ]

    static let threeDisplays = ScreenSpace.fromAppKit(appKit)
    static let singleDisplay = ScreenSpace.fromAppKit([appKit[0]])
    static var builtIn: Display { threeDisplays.displays[0] }
}
