import Foundation
import Testing

/// Checks compiled resources as shipped, including regional bundle selection.
@Suite struct LocalizationTests {
    private static let locales = """
        ar bn ca cs da de el en en-AU en-CA en-GB es
        es-MX fi fr fr-CA gu he hi hr hu id it ja
        kn ko ml mr ms nb nl or pa pl pt-BR pt-PT
        ro ru sk sl sv ta te th tr uk ur vi
        zh-Hans zh-Hant
        """.split(whereSeparator: \.isWhitespace).map(String.init)

    @Test(arguments: locales)
    func compiledCatalogsCoverEverySourceKey(locale: String) throws {
        let host = Bundle.main
        let path = try #require(host.path(forResource: locale, ofType: "lproj"))
        let localized = try #require(Bundle(path: path))
        let sourcePath = try #require(host.path(forResource: "en", ofType: "lproj"))
        let source = try #require(Bundle(path: sourcePath))
        for table in ["Localizable", "InfoPlist"] {
            let sourceURL = try #require(source.url(forResource: table, withExtension: "strings"))
            let sourceData = try Data(contentsOf: sourceURL)
            let entries = try #require(
                PropertyListSerialization.propertyList(from: sourceData, format: nil) as? [String: String]
            )
            for key in entries.keys {
                let sentinel = "AL85_MISSING_TRANSLATION"
                let value = localized.localizedString(forKey: key, value: sentinel, table: table)
                #expect(value != sentinel, "Missing \(locale) / \(table) / \(key)")
            }
        }
        #expect(localized.localizedString(forKey: "CFBundleName", value: nil, table: "InfoPlist") == "Alertivity")
        #expect(Bundle.preferredLocalizations(from: Self.locales, forPreferences: [locale]).first == locale)
    }

    @Test
    func unsupportedLanguageRetainsEnglishFallback() {
        #expect(Bundle.main.developmentLocalization == "en")
        let fallback = Bundle.preferredLocalizations(from: Bundle.main.localizations, forPreferences: ["zz", "en"])
        #expect(fallback == ["en"])
    }
}
