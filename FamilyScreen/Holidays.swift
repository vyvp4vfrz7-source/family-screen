import Foundation

/// Public holidays for the countries of the two homes, so the calendar can
/// colour them. The country comes from each city's time zone. The lists are
/// built in (no network needed) and cover 2026–2027; add each new year here.
enum Holidays {
    struct Holiday: Hashable {
        var country: Country
        var name: String
        var chineseName: String
        func title(_ language: AppLanguage) -> String {
            (language == .cantonese || language == .mandarin) ? chineseName : name
        }
    }

    enum Country: String {
        case uk, hk
        var flag: String { self == .uk ? "🇬🇧" : "🇭🇰" }

        init?(city: City) {
            switch city.timeZoneID {
            case "Europe/London", "Europe/Belfast": self = .uk
            case "Asia/Hong_Kong": self = .hk
            default: return nil
            }
        }
    }

    /// The holidays on this day in either home's country.
    static func on(_ day: Date, cities: [City]) -> [Holiday] {
        let countries = Set(cities.compactMap(Country.init(city:)))
        let c = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: day)
        guard let y = c.year, let m = c.month, let d = c.day else { return [] }
        let key = String(format: "%04d-%02d-%02d", y, m, d)
        return (table[key] ?? []).filter { countries.contains($0.country) }
    }

    private static func uk(_ en: String, _ zh: String) -> Holiday { Holiday(country: .uk, name: en, chineseName: zh) }
    private static func hk(_ en: String, _ zh: String) -> Holiday { Holiday(country: .hk, name: en, chineseName: zh) }

    // England & Wales bank holidays (gov.uk) and Hong Kong general holidays (gov.hk).
    private static let table: [String: [Holiday]] = {
        let entries: [(String, Holiday)] = [
            // 2026 UK
            ("2026-01-01", uk("New Year's Day", "元旦")),
            ("2026-04-03", uk("Good Friday", "耶穌受難節")),
            ("2026-04-06", uk("Easter Monday", "復活節星期一")),
            ("2026-05-04", uk("Early May bank holiday", "五月初銀行假期")),
            ("2026-05-25", uk("Spring bank holiday", "春季銀行假期")),
            ("2026-08-31", uk("Summer bank holiday", "夏季銀行假期")),
            ("2026-12-25", uk("Christmas Day", "聖誕節")),
            ("2026-12-28", uk("Boxing Day (substitute)", "節禮日（補假）")),
            // 2026 HK
            ("2026-01-01", hk("New Year's Day", "元旦")),
            ("2026-02-17", hk("Lunar New Year", "農曆年初一")),
            ("2026-02-18", hk("Lunar New Year", "農曆年初二")),
            ("2026-02-19", hk("Lunar New Year", "農曆年初三")),
            ("2026-04-03", hk("Good Friday", "耶穌受難節")),
            ("2026-04-04", hk("Day after Good Friday", "耶穌受難節翌日")),
            ("2026-04-06", hk("Day after Ching Ming", "清明節翌日")),
            ("2026-04-07", hk("Day after Easter Monday", "復活節星期一翌日")),
            ("2026-05-01", hk("Labour Day", "勞動節")),
            ("2026-05-25", hk("Day after Buddha's Birthday", "佛誕翌日")),
            ("2026-06-19", hk("Tuen Ng Festival", "端午節")),
            ("2026-07-01", hk("HKSAR Establishment Day", "香港特別行政區成立紀念日")),
            ("2026-09-26", hk("Day after Mid-Autumn", "中秋節翌日")),
            ("2026-10-01", hk("National Day", "國慶日")),
            ("2026-10-19", hk("Day after Chung Yeung", "重陽節翌日")),
            ("2026-12-25", hk("Christmas Day", "聖誕節")),
            ("2026-12-26", hk("Boxing Day", "聖誕節後第一個周日")),
            // 2027 UK
            ("2027-01-01", uk("New Year's Day", "元旦")),
            ("2027-03-26", uk("Good Friday", "耶穌受難節")),
            ("2027-03-29", uk("Easter Monday", "復活節星期一")),
            ("2027-05-03", uk("Early May bank holiday", "五月初銀行假期")),
            ("2027-05-31", uk("Spring bank holiday", "春季銀行假期")),
            ("2027-08-30", uk("Summer bank holiday", "夏季銀行假期")),
            ("2027-12-27", uk("Christmas Day (substitute)", "聖誕節（補假）")),
            ("2027-12-28", uk("Boxing Day (substitute)", "節禮日（補假）")),
            // 2027 HK
            ("2027-01-01", hk("New Year's Day", "元旦")),
            ("2027-02-06", hk("Lunar New Year", "農曆年初一")),
            ("2027-02-08", hk("Lunar New Year", "農曆年初三")),
            ("2027-02-09", hk("Lunar New Year", "農曆年初四")),
            ("2027-03-26", hk("Good Friday", "耶穌受難節")),
            ("2027-03-27", hk("Day after Good Friday", "耶穌受難節翌日")),
            ("2027-03-29", hk("Easter Monday", "復活節星期一")),
            ("2027-04-05", hk("Ching Ming Festival", "清明節")),
            ("2027-05-01", hk("Labour Day", "勞動節")),
            ("2027-05-13", hk("Buddha's Birthday", "佛誕")),
            ("2027-06-09", hk("Tuen Ng Festival", "端午節")),
            ("2027-07-01", hk("HKSAR Establishment Day", "香港特別行政區成立紀念日")),
            ("2027-09-16", hk("Day after Mid-Autumn", "中秋節翌日")),
            ("2027-10-01", hk("National Day", "國慶日")),
            ("2027-10-08", hk("Chung Yeung Festival", "重陽節")),
            ("2027-12-25", hk("Christmas Day", "聖誕節")),
            ("2027-12-27", hk("First weekday after Christmas", "聖誕節後第一個周日")),
        ]
        return Dictionary(grouping: entries, by: \.0).mapValues { $0.map(\.1) }
    }()
}
