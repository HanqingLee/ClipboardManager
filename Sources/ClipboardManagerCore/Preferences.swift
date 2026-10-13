import Foundation

public final class Preferences {
    public static let shared = Preferences()

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            "capacity": 100,
            "autoPaste": true,
        ])
    }

    public var capacity: Int {
        get { defaults.integer(forKey: "capacity") }
        set { defaults.set(newValue, forKey: "capacity") }
    }

    public var autoPaste: Bool {
        get { defaults.bool(forKey: "autoPaste") }
        set { defaults.set(newValue, forKey: "autoPaste") }
    }
}
