import AppKit
import BigArrowCore

/// Adds `--rainbow`, `--drip`, `--flames` and `--shake` to a finished layer tree. Called on every
/// show, so a moved arrow (`--follow`) keeps them. The rainbow is a still picture; the rest move
/// only with full animation: Reduce Motion and `--no-animation` get still drips, no flames, no shake.
@MainActor
enum Effects {
    /// The layer to put on screen: the arrow itself, or a stage with the flames behind the arrow.
    /// When it shakes, arrow and flames vibrate together, but the box or ring around the target
    /// stays still, so it keeps framing the target exactly.
    static func stage(_ layers: OverlayLayers, layout: OverlayLayout, look: SignAppearance, mode: AnimationMode) -> CALayer {
        let effects = look.effects
        if effects.rainbow { Rainbow.paint(layers, layout: layout) }
        if effects.drip { Drips.add(to: layers, layout: layout, look: look, mode: mode) }
        guard mode == .full, effects.flames || effects.shake != nil else { return layers.root }
        let stage = CALayer()
        stage.frame = layers.root.frame
        let flames = effects.flames ? [Flames.layer(layers, layout: layout)] : []
        guard let level = effects.shake else {
            stage.sublayers = flames + [layers.root]
            return stage
        }
        layers.markGroup.removeFromSuperlayer()
        if look.border.hasShadow { OverlayLayers.shadow(layers.markGroup) }
        stage.sublayers = flames + [layers.markGroup, layers.root]
        Shaker.shake(flames + [layers.root], layers: layers, level: level)
        return stage
    }
}
