import UIKit

@MainActor
final class HapticsService {
    var isEnabled = true

    private let light = UIImpactFeedbackGenerator(style: .light)
    private let medium = UIImpactFeedbackGenerator(style: .medium)
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notification = UINotificationFeedbackGenerator()

    func prepare() {
        guard isEnabled else { return }
        light.prepare()
        medium.prepare()
        notification.prepare()
    }

    func grab() { if isEnabled { light.impactOccurred(intensity: 0.6) } }
    func sorted() { if isEnabled { medium.impactOccurred(intensity: 0.7) } }
    func comboTierUp() { if isEnabled { notification.notificationOccurred(.success) } }
    func mistake() { if isEnabled { notification.notificationOccurred(.error) } }
    func explosion() { if isEnabled { heavy.impactOccurred() } }
}
