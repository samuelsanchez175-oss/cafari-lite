import Foundation
import Observation

@Observable
@MainActor
final class IdleLookStore {
    static let shared = IdleLookStore()

    private static let idleLookKey = "cafari.car.idleLook"

    private(set) var selectedLook: CarIdleLook

    private init() {
        let raw = UserDefaults.standard.string(forKey: Self.idleLookKey) ?? ""
        selectedLook = CarIdleLook.parse(raw)
    }

    func selectLook(_ look: CarIdleLook) {
        selectedLook = look
        UserDefaults.standard.set(look.persistenceRaw, forKey: Self.idleLookKey)
        Log.write("idle look \(look.persistenceRaw)")
        NotificationCenter.default.post(name: .cafariLiteIdleLookChanged, object: nil)
    }
}
