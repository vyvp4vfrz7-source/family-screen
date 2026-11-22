import SwiftUI

/// A screen's settings as the family sees them. A grandparents' iPad shares
/// this through the family's iCloud share; an adult child can change it from
/// their own iPad, and the grandparents' iPad applies it if they allow that.
struct ScreenConfig: Codable, Equatable, Identifiable {
    var screenID: String
    var name: String
    var grandparentMode: Bool
    var allowRemote: Bool
    var language: AppLanguage
    var cityA: City
    var cityB: City
    var contactName: String
    var contactAddress: String
    var audioOnly: Bool
    var nightFrom: Int
    var nightTo: Int
    var hourlyChime: Bool
    var readMessages: Bool
    var pages: [ScreenPage]
    var rotatePages: Bool
    var pageSeconds: Int
    var slideSeconds: Int
    /// When and by which iPad (screenID) it was last changed.
    var changedAt: Date
    var changedBy: String

    var id: String { screenID }
    var recordName: String { "screen-\(screenID)" }
}

/// Settings opens only after holding the button for 3 seconds, so a tap by
/// mistake never changes anything on the grandparents' screen.
struct HoldForSettingsButton: View {
    var open: () -> Void
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Image(systemName: "gearshape.fill").font(.title3)
            .foregroundColor(.white.opacity(0.35))
            .frame(width: 60, height: 60)
            .contentShape(Rectangle())
            .onLongPressGesture(minimumDuration: 3, perform: open)
            .accessibilityLabel(settings.t(.holdForSettings))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { open() }
    }
}

/// Settings for this iPad's grandparents' mode.
struct GrandparentSection: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Section(header: Text(settings.t(.grandparentMode)), footer: Text(settings.t(.grandparentHint))) {
            Toggle(settings.t(.grandparentMode), isOn: Binding(get: { settings.grandparentMode }, set: { on in
                settings.grandparentMode = on
                if on && settings.language == .english { settings.language = .cantonese }
            }))
            if settings.grandparentMode {
                Toggle(settings.t(.allowRemote), isOn: $settings.allowRemote)
            }
        }
    }
}

#if APPLE_SERVICES
/// In an adult child's settings: the grandparents' screens in this family.
struct RemoteScreensSection: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var store = FamilyStore.shared

    private var others: [ScreenConfig] {
        store.screens.filter { $0.screenID != settings.screenID && $0.grandparentMode }
    }

    var body: some View {
        if !settings.grandparentMode {
            Section(header: Text(settings.t(.grandScreens)), footer: Text(settings.t(.grandScreensHint))) {
                if others.isEmpty {
                    Text(settings.t(.noGrandScreens)).foregroundColor(.secondary)
                }
                ForEach(others) { screen in
                    NavigationLink(destination: RemoteScreenEditor(config: screen)) {
                        HStack {
                            Text(screen.name)
                            Spacer()
                            if !screen.allowRemote { Image(systemName: "lock.fill").foregroundColor(.secondary) }
                        }
                    }
                }
            }
        }
    }
}

/// Changes a grandparents' screen from this iPad.
struct RemoteScreenEditor: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var store = FamilyStore.shared
    @Environment(\.dismiss) private var dismiss
    @State var config: ScreenConfig
    @State private var queryA = ""
    @State private var queryB = ""
    @State private var message = ""

    var body: some View {
        Form {
            if !config.allowRemote {
                Section { Text(settings.t(.remoteLocked)).foregroundColor(.secondary) }
            }
            Group {
                Section(header: Text(settings.t(.language))) {
                    Picker(settings.t(.language), selection: $config.language) {
                        ForEach(AppLanguage.allCases) { Text($0.nativeName).tag($0) }
                    }
                    Toggle(settings.t(.hourlyChime), isOn: $config.hourlyChime)
                    Toggle(settings.t(.readMessages), isOn: $config.readMessages)
                }
                Section(header: Text(settings.t(.cities)), footer: Text(message)) {
                    cityRow(settings.t(.cityA), current: config.cityA.name, query: $queryA) { config.cityA = $0 }
                    cityRow(settings.t(.cityB), current: config.cityB.name, query: $queryB) { config.cityB = $0 }
                }
                Section(header: Text(settings.t(.faceTime))) {
                    TextField(settings.t(.contactName), text: $config.contactName)
                    TextField(settings.t(.contactAddress), text: $config.contactAddress)
                        .keyboardType(.emailAddress).textInputAutocapitalization(.never).disableAutocorrection(true)
                    Toggle(settings.t(.audioOnly), isOn: $config.audioOnly)
                }
                Section(header: Text(settings.t(.nightHours))) {
                    Picker(settings.t(.nightFrom), selection: $config.nightFrom) {
                        ForEach(0..<24, id: \.self) { Text(String(format: "%02d:00", $0)).tag($0) }
                    }
                    Picker(settings.t(.nightTo), selection: $config.nightTo) {
                        ForEach(0..<24, id: \.self) { Text(String(format: "%02d:00", $0)).tag($0) }
                    }
                }
                Section(header: Text(settings.t(.pages))) {
                    ForEach(ScreenPage.allCases) { page in
                        Toggle(settings.t(page.title), isOn: Binding(
                            get: { config.pages.contains(page) },
                            set: { on in
                                if on {
                                    config.pages = ScreenPage.allCases.filter { config.pages.contains($0) || $0 == page }
                                } else if config.pages.count > 1 {
                                    config.pages.removeAll { $0 == page }
                                }
                            }))
                    }
                    Toggle(settings.t(.rotatePages), isOn: $config.rotatePages)
                    Stepper("\(settings.t(.everyPage)) \(config.pageSeconds) \(settings.t(.seconds))",
                            value: $config.pageSeconds, in: 10...600, step: 10)
                    Stepper("\(settings.t(.slideshow)): \(config.slideSeconds) \(settings.t(.seconds))",
                            value: $config.slideSeconds, in: 5...120, step: 5)
                }
            }
            .disabled(!config.allowRemote)
        }
        .navigationTitle(config.name)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(settings.t(.saveToScreen)) {
                    store.sendScreen(config)
                    dismiss()
                }
                .disabled(!config.allowRemote)
            }
        }
    }

    private func cityRow(_ label: String, current: String, query: Binding<String>,
                         set: @escaping (City) -> Void) -> some View {
        HStack {
            Text(label).foregroundColor(.secondary)
            TextField(current, text: query)
            Button(settings.t(.find)) {
                let q = query.wrappedValue
                Task {
                    if let city = await City.find(q) {
                        set(city)
                        query.wrappedValue = ""
                        message = "\(city.name) · \(city.timeZoneID)"
                    } else {
                        message = settings.t(.notFound)
                    }
                }
            }
        }
    }
}
#endif
