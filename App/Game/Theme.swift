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

    @MainActor static let neonTide = Theme(
        id: "theme.neonTide",
        background: UIColor(red: 0.01, green: 0.07, blue: 0.10, alpha: 1),
        belt: UIColor(red: 0.04, green: 0.14, blue: 0.19, alpha: 1),
        beltStripe: UIColor(red: 0.10, green: 0.36, blue: 0.44, alpha: 1),
        panel: UIColor(red: 0.02, green: 0.10, blue: 0.14, alpha: 1),
        panelStroke: UIColor(red: 0.12, green: 0.45, blue: 0.52, alpha: 1),
        standard: UIColor(red: 0.20, green: 1.00, blue: 0.70, alpha: 1),
        valuable: UIColor(red: 1.00, green: 0.90, blue: 0.35, alpha: 1),
        hazardous: UIColor(red: 1.00, green: 0.35, blue: 0.40, alpha: 1),
        danger: UIColor(red: 1.00, green: 0.22, blue: 0.25, alpha: 1),
        text: UIColor(white: 0.93, alpha: 1)
    )

    @MainActor static let rustBelt = Theme(
        id: "theme.rustBelt",
        background: UIColor(red: 0.08, green: 0.05, blue: 0.04, alpha: 1),
        belt: UIColor(red: 0.17, green: 0.11, blue: 0.08, alpha: 1),
        beltStripe: UIColor(red: 0.40, green: 0.25, blue: 0.16, alpha: 1),
        panel: UIColor(red: 0.12, green: 0.08, blue: 0.06, alpha: 1),
        panelStroke: UIColor(red: 0.50, green: 0.32, blue: 0.20, alpha: 1),
        standard: UIColor(red: 0.45, green: 0.85, blue: 1.00, alpha: 1),
        valuable: UIColor(red: 1.00, green: 0.70, blue: 0.15, alpha: 1),
        hazardous: UIColor(red: 1.00, green: 0.30, blue: 0.20, alpha: 1),
        danger: UIColor(red: 1.00, green: 0.15, blue: 0.15, alpha: 1),
        text: UIColor(red: 0.95, green: 0.90, blue: 0.84, alpha: 1)
    )

    @MainActor static let voidChrome = Theme(
        id: "theme.voidChrome",
        background: UIColor(red: 0.02, green: 0.02, blue: 0.04, alpha: 1),
        belt: UIColor(red: 0.10, green: 0.10, blue: 0.13, alpha: 1),
        beltStripe: UIColor(red: 0.32, green: 0.32, blue: 0.40, alpha: 1),
        panel: UIColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1),
        panelStroke: UIColor(red: 0.45, green: 0.45, blue: 0.58, alpha: 1),
        standard: UIColor(red: 0.75, green: 0.85, blue: 1.00, alpha: 1),
        valuable: UIColor(red: 0.85, green: 0.55, blue: 1.00, alpha: 1),
        hazardous: UIColor(red: 1.00, green: 0.40, blue: 0.60, alpha: 1),
        danger: UIColor(red: 1.00, green: 0.20, blue: 0.30, alpha: 1),
        text: UIColor(white: 0.96, alpha: 1)
    )

    @MainActor static let all: [Theme] = [.foundry, .neonTide, .rustBelt, .voidChrome]

    @MainActor static func with(id: String) -> Theme {
        all.first { $0.id == id } ?? .foundry
    }
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
