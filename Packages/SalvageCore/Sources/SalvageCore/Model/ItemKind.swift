public enum ItemKind: Int, CaseIterable, Sendable, Codable {
    case standard
    case valuable
    case hazardous
}

public enum BinID: Int, CaseIterable, Sendable, Codable {
    case recycler
    case vault
    case containment

    public var accepts: ItemKind {
        switch self {
        case .recycler: .standard
        case .vault: .valuable
        case .containment: .hazardous
        }
    }

    public static func matching(_ kind: ItemKind) -> BinID {
        switch kind {
        case .standard: .recycler
        case .valuable: .vault
        case .hazardous: .containment
        }
    }
}
