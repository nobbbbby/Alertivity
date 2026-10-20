import Foundation

enum L10n {
    static func string(_ key: String) -> String {
        String(localized: String.LocalizationValue(key))
    }

    static func format(_ key: String, _ args: CVarArg...) -> String {
        String(format: String(localized: String.LocalizationValue(key)), locale: Locale.current, arguments: args)
    }

    static func list(_ items: [String]) -> String {
        ListFormatter.localizedString(byJoining: items)
    }
}
