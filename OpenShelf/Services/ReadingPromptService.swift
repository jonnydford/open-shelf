import Foundation
import WeatherKit
import CoreLocation
import SwiftUI

// MARK: - Reading Prompt

struct ReadingPrompt: Equatable {
    let message: String
    let systemImage: String
    let tintColor: Color
}

// MARK: - Reading Prompt Service

@MainActor
@Observable
final class ReadingPromptService {
    private(set) var currentPrompt: ReadingPrompt?

    private let locationManager = CLLocationManager()
    private var cachedCategory: (category: WeatherCategory, date: Date)?
    private var promptData: ReadingPromptData?
    private static let cacheExpiry: TimeInterval = 30 * 60

    init() {
        loadPromptData()
        selectPrompt(weatherCategory: nil)
    }

    func refresh() async {
        if let cached = cachedCategory,
           Date.now.timeIntervalSince(cached.date) < Self.cacheExpiry {
            selectPrompt(weatherCategory: cached.category)
            return
        }

        let category = await fetchWeatherCategory()
        if let category {
            cachedCategory = (category, .now)
        }
        selectPrompt(weatherCategory: category)
    }

    // MARK: - Weather Fetching

    private func fetchWeatherCategory() async -> WeatherCategory? {
        let status = locationManager.authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
            if status == .notDetermined {
                locationManager.requestWhenInUseAuthorization()
            }
            return nil
        }

        do {
            for try await update in CLLocationUpdate.liveUpdates(.default) {
                guard let location = update.location else { continue }
                let weather = try await WeatherService.shared.weather(for: location)
                let hour = Calendar.current.component(.hour, from: .now)
                return WeatherCategory(from: weather.currentWeather, hour: hour)
            }
        } catch {}
        return nil
    }

    // MARK: - Prompt Selection

    private func selectPrompt(weatherCategory: WeatherCategory?) {
        guard let data = promptData else { return }

        let hour = Calendar.current.component(.hour, from: .now)
        let timeSlot = TimeSlot(hour: hour)

        var candidates: [String]

        if timeSlot == .veryLate {
            candidates = data.time[timeSlot.rawValue] ?? data.fallback
        } else {
            candidates = []
            if let category = weatherCategory,
               let messages = data.weather[category.rawValue] {
                candidates.append(contentsOf: messages)
            }
            if let messages = data.time[timeSlot.rawValue] {
                candidates.append(contentsOf: messages)
            }
            candidates.append(contentsOf: data.fallback)
        }

        guard let message = candidates.randomElement() else { return }

        let icon: String
        let tint: Color

        if timeSlot == .veryLate {
            icon = "moon.zzz"
            tint = .purple
        } else if let category = weatherCategory {
            icon = category.systemImage
            tint = category.tintColor
        } else {
            icon = timeSlot.systemImage
            tint = timeSlot.tintColor
        }

        currentPrompt = ReadingPrompt(message: message, systemImage: icon, tintColor: tint)
    }

    // MARK: - Data Loading

    private func loadPromptData() {
        guard let url = Bundle.main.url(forResource: "ReadingPrompts", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(ReadingPromptData.self, from: data) else {
            return
        }
        promptData = decoded
    }
}

// MARK: - Data Model

private struct ReadingPromptData: Codable {
    let weather: [String: [String]]
    let time: [String: [String]]
    let fallback: [String]
}

// MARK: - Weather Category

private enum WeatherCategory: String {
    case rain
    case snowOrCold
    case sunny
    case overcast
    case windy
    case clearEvening

    init?(from weather: CurrentWeather, hour: Int) {
        let tempCelsius = weather.temperature.converted(to: .celsius).value

        switch weather.condition {
        case .rain, .heavyRain, .drizzle, .thunderstorms, .strongStorms,
             .isolatedThunderstorms, .scatteredThunderstorms, .sunShowers,
             .tropicalStorm, .hurricane:
            self = .rain
        case .snow, .heavySnow, .flurries, .sleet, .freezingRain,
             .freezingDrizzle, .blizzard, .blowingSnow, .wintryMix,
             .hail, .frigid, .sunFlurries:
            self = .snowOrCold
        case .windy, .breezy:
            self = .windy
        case .cloudy, .mostlyCloudy, .foggy, .haze, .smoky, .blowingDust:
            self = .overcast
        case .clear, .mostlyClear, .partlyCloudy:
            if hour >= 17 && hour < 21 {
                self = .clearEvening
            } else if tempCelsius < 5 {
                self = .snowOrCold
            } else {
                self = .sunny
            }
        case .hot:
            self = .sunny
        @unknown default:
            if tempCelsius < 5 {
                self = .snowOrCold
            } else {
                return nil
            }
        }
    }

    var systemImage: String {
        switch self {
        case .rain: "cloud.rain.fill"
        case .snowOrCold: "snowflake"
        case .sunny: "sun.max.fill"
        case .overcast: "cloud.fill"
        case .windy: "wind"
        case .clearEvening: "moon.stars.fill"
        }
    }

    var tintColor: Color {
        switch self {
        case .rain: .blue
        case .snowOrCold: .cyan
        case .sunny: .orange
        case .overcast: .gray
        case .windy: .teal
        case .clearEvening: .indigo
        }
    }
}

// MARK: - Time Slot

private enum TimeSlot: String {
    case morning
    case afternoon
    case evening
    case lateNight
    case veryLate

    init(hour: Int) {
        switch hour {
        case 6..<12: self = .morning
        case 12..<17: self = .afternoon
        case 17..<21: self = .evening
        case 21..<23: self = .lateNight
        default: self = .veryLate
        }
    }

    var systemImage: String {
        switch self {
        case .morning: "sunrise.fill"
        case .afternoon: "sun.max.fill"
        case .evening: "sunset.fill"
        case .lateNight: "moon.fill"
        case .veryLate: "moon.zzz"
        }
    }

    var tintColor: Color {
        switch self {
        case .morning: .orange
        case .afternoon: .yellow
        case .evening: .orange
        case .lateNight: .indigo
        case .veryLate: .purple
        }
    }
}
