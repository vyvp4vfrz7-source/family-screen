import SwiftUI
#if APPLE_SERVICES
import CloudKit
#endif

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var store = FamilyStore.shared
    @State private var queryA = ""
    @State private var queryB = ""
    @State private var cityMessage = ""
    @State private var newFeed = ""
    @State private var cloudStatus = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(settings.t(.thisHome))) {
                    TextField(settings.t(.homeName), text: $settings.homeName)
                }

                Section(header: Text(settings.t(.language))) {
                    Picker(settings.t(.language), selection: $settings.language) {
                        ForEach(AppLanguage.allCases) { Text($0.nativeName).tag($0) }
                    }
                    Toggle(settings.t(.hourlyChime), isOn: $settings.hourlyChime)
                    Toggle(settings.t(.readMessages), isOn: $settings.readMessages)
                }

                Section(header: Text(settings.t(.cities)), footer: Text(cityMessage)) {
                    cityRow(settings.t(.cityA), current: settings.cityA.name, query: $queryA) { settings.cityA = $0 }
                    cityRow(settings.t(.cityB), current: settings.cityB.name, query: $queryB) { settings.cityB = $0 }
                }

                Section(header: Text(settings.t(.faceTime))) {
                    TextField(settings.t(.contactName), text: $settings.contactName)
                    TextField(settings.t(.contactAddress), text: $settings.contactAddress)
                        .keyboardType(.emailAddress).textInputAutocapitalization(.never).disableAutocorrection(true)
                    Toggle(settings.t(.audioOnly), isOn: $settings.audioOnly)
                }

                Section(header: Text(settings.t(.nightHours))) {
                    Picker(settings.t(.nightFrom), selection: $settings.nightFrom) {
                        ForEach(0..<24, id: \.self) { Text(String(format: "%02d:00", $0)).tag($0) }
                    }
                    Picker(settings.t(.nightTo), selection: $settings.nightTo) {
                        ForEach(0..<24, id: \.self) { Text(String(format: "%02d:00", $0)).tag($0) }
                    }
                }

                Section(header: Text(settings.t(.slideshow))) {
                    Stepper("\(settings.slideSeconds) \(settings.t(.seconds))",
                            value: $settings.slideSeconds, in: 5...120, step: 5)
                }

                Section(header: Text(settings.t(.feeds))) {
                    ForEach(settings.feeds) { Text($0.url).lineLimit(1) }
                        .onDelete { settings.feeds.remove(atOffsets: $0) }
                    HStack {
                        TextField(settings.t(.feedURL), text: $newFeed)
                            .keyboardType(.URL).textInputAutocapitalization(.never).disableAutocorrection(true)
                        Button(settings.t(.addFeed)) {
                            let url = newFeed.trimmingCharacters(in: .whitespaces)
                            guard url.hasPrefix("http") else { return }
                            settings.feeds.append(NewsFeed(url: url))
                            newFeed = ""
                        }
                    }
                }

                Section(header: Text(settings.t(.familySync)), footer: Text(store.syncStatus)) {
                    #if APPLE_SERVICES
                    Text(cloudStatus).foregroundColor(.secondary)
                    Button(settings.t(.inviteHome)) { Task { await ShareInviter.present() } }
                    #else
                    Text(settings.t(.syncOff)).foregroundColor(.secondary)
                    #endif
                }
            }
            .navigationTitle(settings.t(.settings))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button(settings.t(.done)) { dismiss() } }
            }
            .task {
                #if APPLE_SERVICES
                cloudStatus = await store.cloud.accountStatusText()
                #endif
            }
        }
        .navigationViewStyle(.stack)
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
                        cityMessage = "\(city.name) · \(city.timeZoneID)"
                    } else {
                        cityMessage = settings.t(.notFound)
                    }
                }
            }
        }
    }
}

#if APPLE_SERVICES
/// Shows Apple's share sheet so the other home gets an invite link.
enum ShareInviter {
    @MainActor
    static func present() async {
        let store = FamilyStore.shared
        do {
            let share = try await store.cloud.familyShare()
            let controller = UICloudSharingController(share: share, container: store.cloud.container)
            controller.availablePermissions = [.allowReadWrite, .allowPrivate]
            guard let top = TopController.find() else { return }
            controller.popoverPresentationController?.sourceView = top.view
            controller.popoverPresentationController?.sourceRect =
                CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY, width: 1, height: 1)
            top.present(controller, animated: true)
        } catch {
            store.syncStatus = error.localizedDescription
        }
    }
}
#endif
