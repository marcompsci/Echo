import Foundation
import Observation

// MARK: - Observable pet state — persists to UserDefaults

@Observable
@MainActor
final class PetState {

    // MARK: - Appearance (persisted)

    var name: String        { didSet { save(name,          for: .name) } }
    var bodyColor: PetBodyColor { didSet { save(bodyColor.rawValue, for: .color) } }
    var accessory: PetAccessory { didSet { save(accessory.rawValue, for: .accessory) } }

    // MARK: - Stats (persisted)

    var mood: PetMood       { didSet { save(mood.rawValue,  for: .mood) } }
    var happiness: Double   { didSet { save(happiness,      for: .happiness) } }
    var energy: Double      { didSet { save(energy,         for: .energy) } }
    var lastInteraction: Date { didSet { save(lastInteraction, for: .lastInteraction) } }

    // MARK: - Transient animation state

    var isExcited = false

    // MARK: - Init

    init() {
        let d = UserDefaults.standard
        name             = d.string(forKey: Key.name.rawValue) ?? "Echo"
        bodyColor        = PetBodyColor(rawValue: d.string(forKey: Key.color.rawValue) ?? "") ?? .lavender
        accessory        = PetAccessory(rawValue: d.string(forKey: Key.accessory.rawValue) ?? "") ?? .antenna
        mood             = PetMood(rawValue: d.string(forKey: Key.mood.rawValue) ?? "") ?? .happy
        happiness        = (d.object(forKey: Key.happiness.rawValue) as? Double)?.clamped(0...100) ?? 80
        energy           = (d.object(forKey: Key.energy.rawValue)    as? Double)?.clamped(0...100) ?? 90
        lastInteraction  = (d.object(forKey: Key.lastInteraction.rawValue) as? Date) ?? .now
    }

    // MARK: - Interactions

    func pet() {
        happiness = min(100, happiness + 5)
        energy    = min(100, energy + 1)
        lastInteraction = .now
        isExcited = true
        mood = .excited
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            isExcited = false
            refreshMood()
        }
    }

    func feed() {
        energy    = min(100, energy + 15)
        happiness = min(100, happiness + 3)
        lastInteraction = .now
        mood = .happy
        Task {
            try? await Task.sleep(for: .seconds(3))
            refreshMood()
        }
    }

    func refreshMood() {
        let elapsed = Date.now.timeIntervalSince(lastInteraction)
        if elapsed > 3_600 { energy    = max(0, energy    - 8) }
        if elapsed > 7_200 { happiness = max(0, happiness - 8) }

        guard !isExcited else { return }
        if energy    < 20 { mood = .sleepy;  return }
        if happiness < 30 { mood = .hungry;  return }
        if happiness > 75 && energy > 65 { mood = .happy; return }
        mood = .idle
    }

    // MARK: - Persistence

    private func save(_ value: String, for key: Key) {
        UserDefaults.standard.set(value, forKey: key.rawValue)
    }
    private func save(_ value: Double, for key: Key) {
        UserDefaults.standard.set(value, forKey: key.rawValue)
    }
    private func save(_ value: Date, for key: Key) {
        UserDefaults.standard.set(value, forKey: key.rawValue)
    }

    private enum Key: String {
        case name            = "pet.name"
        case color           = "pet.color"
        case accessory       = "pet.accessory"
        case mood            = "pet.mood"
        case happiness       = "pet.happiness"
        case energy          = "pet.energy"
        case lastInteraction = "pet.lastInteraction"
    }
}

private extension Double {
    func clamped(_ range: ClosedRange<Double>) -> Double {
        Swift.max(range.lowerBound, Swift.min(range.upperBound, self))
    }
}
