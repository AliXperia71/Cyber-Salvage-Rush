import SalvageCore
import UIKit

/// A workshop palette. Cosmetic themes are palette swaps; textures are re-baked per theme.
struct Theme {
    let id: String
    let background: UIColor
    let belt: UIColor
    let beltStripe: UIColor
    let panel: UIColor
    let panelStroke: UIColor
    let standard: UIColor
    let valuable: UIColor
    let hazardous: UIColor
    let danger: UIColor
    let text: UIColor

    func color(for kind: ItemKind) -> UIColor {
        switch kind {
        case .standard: standard
        case .valuable: valuable
        case .hazardous: hazardous
        }
    }

    @MainActor static let foundry = Theme(
        id: "theme.foundry",
        background: UIColor(red: 0.035, green: 0.043, blue: 0.086, alpha: 1),
        belt: UIColor(red: 0.09, green: 0.11, blue: 0.18, alpha: 1),
        beltStripe: UIColor(red: 0.20, green: 0.26, blue: 0.40, alpha: 1),
        panel: UIColor(red: 0.06, green: 0.08, blue: 0.14, alpha: 1),
        panelStroke: UIColor(red: 0.22, green: 0.30, blue: 0.48, alpha: 1),
        standard: UIColor(red: 0.00, green: 0.90, blue: 1.00, alpha: 1),
        valuable: UIColor(red: 1.00, green: 0.80, blue: 0.20, alpha: 1),
        hazardous: UIColor(red: 1.00, green: 0.25, blue: 0.55, alpha: 1),
        danger: UIColor(red: 1.00, green: 0.18, blue: 0.22, alpha: 1),
        text: UIColor(white: 0.92, alpha: 1)
    )
}

extension ItemKind {
    /// Shape + symbol make kinds distinguishable without color.
    var symbolName: String {
        switch self {
        case .standard: "gearshape.fill"
        case .valuable: "star.fill"
        case .hazardous: "exclamationmark"
        }
    }

    var displayName: String {
        switch self {
        case .standard: "Scrap"
        case .valuable: "Valuable"
        case .hazardous: "Hazard"
        }
    }
}

extension BinID {
    var label: String {
        switch self {
        case .recycler: "RECYCLE"
        case .vault: "VAULT"
        case .containment: "HAZMAT"
        }
    }
}
