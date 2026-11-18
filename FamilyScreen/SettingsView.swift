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

                Section(header: Text(settings.t(.pages))) {
                    ForEach(ScreenPage.allCases) { page in
                        Toggle(settings.t(page.title), isOn: Binding(
                            get: { settings.pages.contains(page) },
                            set: { settings.togglePage(page, on: $0) }))
                    }
                    Toggle(settings.t(.rotatePages), isOn: $settings.rotatePages)
                    if settings.rotatePages {
                        Stepper("\(settings.t(.everyPage)) \(settings.pageSeconds) \(settings.t(.seconds))",
                                value: $settings.pageSeconds, in: 10...600, step: 10)
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

                #if APPLE_SERVICES
                FamilySection()
                #else
                Section(header: Text(settings.t(.familySync))) {
                    Text(settings.t(.syncOff)).foregroundColor(.secondary)
                }
                #endif

                if !settings.hiddenHomes.isEmpty {
                    Section(header: Text(settings.t(.hiddenHomes))) {
                        ForEach(settings.hiddenHomes, id: \.self) { home in
                            HStack {
                                Text(home)
                                Spacer()
                                Button(settings.t(.show)) { settings.hiddenHomes.removeAll { $0 == home } }
                            }
                        }
                    }
                }

                Section {
                    if let url = URL(string: Bundle.main.object(forInfoDictionaryKey: "PrivacyPolicyURL") as? String ?? ""),
                       url.scheme == "https" {
                        Link(settings.t(.privacy), destination: url)
                    }
                }
            }
            .navigationTitle(settings.t(.settings))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button(settings.t(.done)) { dismiss() } }
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
/// Linking the two homes: one invite link, member list, leave or delete.
struct FamilySection: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var store = FamilyStore.shared
    @State private var status = ""
    @State private var members: [CloudSync.Member] = []
    @State private var linkOn = true
    @State private var confirming = false

    private var cloud: CloudSync { store.cloud }

    var body: some View {
        Section(header: Text(settings.t(.familySync)), footer: Text(store.syncStatus)) {
            Text(status).foregroundColor(.secondary)
            if cloud.isOwner {
                Button(settings.t(.sendLink)) { Task { await sendLink() } }
                Toggle(settings.t(.linkOn), isOn: Binding(get: { linkOn }, set: { on in
                    linkOn = on
                    Task { await run { try await cloud.setLinkActive(on) } }
                }))
            }
        }
        if !members.isEmpty {
            Section(header: Text(settings.t(.members))) {
                ForEach(members) { m in
                    HStack {
                        Text(m.name)
                        Spacer()
                        if cloud.isOwner && !m.isOwner {
                            Button(settings.t(.remove), role: .destructive) {
                                Task { await run { try await cloud.remove(m) }; await reload() }
                            }
                        }
                    }
                }
            }
        }
        Section {
            Button(cloud.isOwner ? settings.t(.deleteFamily) : settings.t(.leaveFamily), role: .destructive) {
                confirming = true
            }
            .alert(cloud.isOwner ? settings.t(.deleteFamily) : settings.t(.leaveFamily), isPresented: $confirming) {
                Button(settings.t(.cancel), role: .cancel) {}
                Button(settings.t(.delete), role: .destructive) {
                    Task {
                        await run { try await cloud.leaveOrDelete() }
                        store.resetLocal()
                        await reload()
                    }
                }
            } message: {
                Text(settings.t(.confirmDelete))
            }
        }
        .task { await reload() }
    }

    private func reload() async {
        status = await cloud.accountStatusText()
        members = await cloud.members()
        linkOn = await cloud.linkIsActive() || members.isEmpty
    }

    private func run(_ work: () async throws -> Void) async {
        do { try await work() } catch { store.syncStatus = error.localizedDescription }
    }

    /// One tap for the other home: the link opens the app and joins the family.
    private func sendLink() async {
        do {
            let url = try await cloud.inviteLink()
            linkOn = true
            let text = "\(settings.t(.joinMessage)) \(url.absoluteString)"
            let sheet = UIActivityViewController(activityItems: [text], applicationActivities: nil)
            guard let top = TopController.find() else { return }
            sheet.popoverPresentationController?.sourceView = top.view
            sheet.popoverPresentationController?.sourceRect =
                CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY, width: 1, height: 1)
            top.present(sheet, animated: true)
        } catch {
            store.syncStatus = error.localizedDescription
        }
    }
}
#endif
