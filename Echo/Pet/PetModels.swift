import SwiftUI

// MARK: - Mood

enum PetMood: String, CaseIterable, Codable, Sendable {
    case happy, idle, sleepy, excited, hungry, thinking

    var smileAmount: Double {
        switch self {
        case .happy:    return 1.0
        case .excited:  return 1.0
        case .idle:     return 0.40
        case .thinking: return 0.20
        case .sleepy:   return -0.15
        case .hungry:   return -0.65
        }
    }

    var eyeSquint: Double {
        switch self {
        case .excited:  return 0.10
        case .happy:    return 0.05
        case .sleepy:   return 0.70
        case .thinking: return 0.30
        default:        return 0.0
        }
    }

    var blinkInterval: ClosedRange<Double> {
        switch self {
        case .sleepy:   return 1.5...3.0
        case .excited:  return 1.0...2.5
        default:        return 3.0...6.0
        }
    }

    var label: String { rawValue.capitalized }

    var systemIcon: String {
        switch self {
        case .happy:    return "face.smiling"
        case .idle:     return "circle"
        case .sleepy:   return "moon.zzz"
        case .excited:  return "star.fill"
        case .hungry:   return "fork.knife"
        case .thinking: return "ellipsis.bubble"
        }
    }
}

// MARK: - Body color

enum PetBodyColor: String, CaseIterable, Codable, Sendable {
    case lavender, mint, sky, rose, amber, ghost

    var color: Color {
        switch self {
        case .lavender: return Color(red: 0.545, green: 0.361, blue: 0.965)
        case .mint:     return Color(red: 0.204, green: 0.827, blue: 0.600)
        case .sky:      return Color(red: 0.376, green: 0.647, blue: 0.980)
        case .rose:     return Color(red: 0.957, green: 0.443, blue: 0.706)
        case .amber:    return Color(red: 0.984, green: 0.749, blue: 0.255)
        case .ghost:    return Color(red: 0.880, green: 0.880, blue: 0.920)
        }
    }

    var shadowColor: Color { color.opacity(0.45) }

    var label: String {
        switch self {
        case .lavender: return "Lavender"
        case .mint:     return "Mint"
        case .sky:      return "Sky"
        case .rose:     return "Rose"
        case .amber:    return "Amber"
        case .ghost:    return "Ghost"
        }
    }
}

// MARK: - Accessory

enum PetAccessory: String, CaseIterable, Codable, Sendable {
    case none, antenna, bow, halo, hat

    var label: String {
        switch self {
        case .none:    return "None"
        case .antenna: return "Antenna"
        case .bow:     return "Bow"
        case .halo:    return "Halo"
        case .hat:     return "Cap"
        }
    }

    var systemIcon: String {
        switch self {
        case .none:    return "xmark.circle"
        case .antenna: return "antenna.radiowaves.left.and.right"
        case .bow:     return "gift"
        case .halo:    return "circle.dashed"
        case .hat:     return "graduationcap"
        }
    }
}
