import Foundation
import AVFoundation

/// Speaks in the family's language with the iPad's built-in voices.
@MainActor
final class Speaker {
    static let shared = Speaker()
    private let synth = AVSpeechSynthesizer()

    func say(_ text: String, language: AppLanguage) {
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.duckOthers])
        let u = AVSpeechUtterance(string: text)
        u.voice = AVSpeechSynthesisVoice(language: language.voiceCode)
        u.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        synth.speak(u)
    }

    func timeText(_ date: Date, in city: City, language: AppLanguage) -> String {
        let f = DateFormatter()
        f.locale = language.locale
        f.timeZone = city.timeZone
        f.timeStyle = .short
        return f.string(from: date)
    }

    func announce(settings: AppSettings, weatherA: WeatherNow?, weatherB: WeatherNow?) {
        let lang = settings.language
        let now = Date()
        var parts = ["\(L.itIs.text(lang)) \(timeText(now, in: settings.cityA, language: lang))."]
        for (city, w) in [(settings.cityA, weatherA), (settings.cityB, weatherB)] {
            var line = "\(city.name): \(timeText(now, in: city, language: lang))"
            if let w = w { line += ", \(Int(w.temperature.rounded())) \(L.degrees.text(lang))" }
            parts.append(line + ".")
        }
        say(parts.joined(separator: " "), language: lang)
    }
}
