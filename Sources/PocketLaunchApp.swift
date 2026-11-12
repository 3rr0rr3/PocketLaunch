import SwiftUI
import UniformTypeIdentifiers

struct Game: Identifiable, Codable {
    var id = UUID()
    var name: String
    var launchURL: String
    var favorite = false
}

@MainActor final class Library: ObservableObject {
    @Published var games: [Game] = []
    @Published var files: [URL] = []
    let root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    var archive: URL { root.appendingPathComponent("IPAs", isDirectory: true) }
    var index: URL { root.appendingPathComponent("games.json") }
    init() {
        games = (try? JSONDecoder().decode([Game].self, from: Data(contentsOf: index))) ?? []
        refresh()
    }
    func save() throws { try JSONEncoder().encode(games).write(to: index, options: .atomic) }
    func refresh() {
        files = ((try? FileManager.default.contentsOfDirectory(at: archive, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension.lowercased() == "ipa" }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }
    func importFiles(_ urls: [URL]) async throws {
        let destination = archive
        try await Task.detached(priority: .userInitiated) {
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
            for url in urls {
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                guard url.pathExtension.lowercased() == "ipa" else { continue }
                let target = destination.appendingPathComponent(UUID().uuidString + "-" + url.lastPathComponent)
                var coordinationError: NSError?
                var copyError: Error?
                NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { readable in
                    do { try FileManager.default.copyItem(at: readable, to: target) }
                    catch { copyError = error }
                }
                if let error = coordinationError { throw error }
                if let error = copyError { throw error }
            }
        }.value
        refresh()
    }
}

@main struct PocketLaunchApp: App {
    @StateObject private var library = Library()
    var body: some Scene { WindowGroup { LauncherView().environmentObject(library).preferredColorScheme(.dark) } }
}

struct LauncherView: View {
    @EnvironmentObject var library: Library
    @Environment(\.openURL) var openURL
    @State private var query = ""
    @State private var addGame = false
    @State private var importing = false
    @State private var busy = false
    @State private var error: String?
    @State private var downloadURL = ""
    var filtered: [Game] {
        library.games.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
            .sorted { $0.favorite != $1.favorite ? $0.favorite : $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    var body: some View {
        TabView {
            NavigationStack {
                ScrollView {
                    if filtered.isEmpty {
                        ContentUnavailableView("Your games, together", systemImage: "gamecontroller.fill", description: Text("Add an installed game and its launch link to get started."))
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 16) {
                        ForEach(filtered) { game in
                            VStack(alignment: .leading, spacing: 14) {
                                Image(systemName: "gamecontroller.fill").font(.system(size: 42)).foregroundStyle(.mint).frame(maxWidth: .infinity).frame(height: 90)
                                Text(game.name).font(.headline).lineLimit(2)
                                Button("Play", systemImage: "play.fill") { launch(game.launchURL) }
                                    .buttonStyle(.borderedProminent).tint(.mint).foregroundStyle(.black)
                            }
                            .padding().frame(maxWidth: .infinity, alignment: .leading)
                            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 24))
                            .contextMenu {
                                Button(game.favorite ? "Unfavorite" : "Favorite", systemImage: "star") {
                                    if let i = library.games.firstIndex(where: { $0.id == game.id }) { library.games[i].favorite.toggle(); persist() }
                                }
                                Button("Remove", role: .destructive) { library.games.removeAll { $0.id == game.id }; persist() }
                            }
                        }
                    }.padding()
                }
                .navigationTitle("PocketLaunch").searchable(text: $query)
                .toolbar { Button("Add game", systemImage: "plus") { addGame = true } }
            }.tabItem { Label("Games", systemImage: "gamecontroller") }
            NavigationStack {
                List {
                    Section {
                        Button("Import IPA", systemImage: "square.and.arrow.down") { importing = true }.disabled(busy)
                        if busy { ProgressView("Copying IPA files…") }
                    } footer: { Text("Files are copied into this app. Share an IPA to your installation tool, then return to Games to add its launch link.") }
                    Section("Your IPA files") {
                        ForEach(library.files, id: \.self) { file in
                            ShareLink(item: file) { Label(String(file.lastPathComponent.dropFirst(37)), systemImage: "shippingbox") }
                        }
                        .onDelete { offsets in
                            for i in offsets { do { try FileManager.default.removeItem(at: library.files[i]) } catch { self.error = error.localizedDescription } }
                            library.refresh()
                        }
                    }
                    Section("Install a hosted IPA") {
                        TextField("https://…/game.ipa", text: $downloadURL).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                        Button("Install with SideStore", systemImage: "arrow.up.forward.app") { installRemote() }
                    }
                }.navigationTitle("IPA Library")
            }.tabItem { Label("IPAs", systemImage: "shippingbox") }
        }.tint(.mint)
        .sheet(isPresented: $addGame) { AddGameView { game in library.games.append(game); persist() } }
        .fileImporter(isPresented: $importing, allowedContentTypes: [UTType(filenameExtension: "ipa") ?? .data], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls):
                busy = true
                Task {
                    do { try await library.importFiles(urls) } catch { self.error = error.localizedDescription }
                    library.refresh(); busy = false
                }
            case .failure(let failure): error = failure.localizedDescription
            }
        }
        .alert("PocketLaunch", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) { Button("OK") { error = nil } } message: { Text(error ?? "") }
    }
    func persist() { do { try library.save() } catch { self.error = error.localizedDescription } }
    func launch(_ value: String) {
        guard let url = URL(string: value), url.scheme != nil else { error = "Enter a valid game launch link."; return }
        openURL(url) { accepted in if !accepted { error = "This link could not be opened. Check that the game is installed and registers this launch scheme." } }
    }
    func installRemote() {
        guard let url = URL(string: downloadURL.trimmingCharacters(in: .whitespacesAndNewlines)), url.scheme?.lowercased() == "https", url.host != nil else { error = "Enter an HTTPS download link for the IPA."; return }
        var components = URLComponents()
        components.scheme = "sidestore"; components.host = "install"
        components.queryItems = [URLQueryItem(name: "url", value: url.absoluteString)]
        if let link = components.url { launch(link.absoluteString) }
    }
}

struct AddGameView: View {
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var link = ""
    let add: (Game) -> Void
    var valid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && URL(string: link)?.scheme != nil
    }
    var body: some View {
        NavigationStack {
            Form {
                TextField("Game name", text: $name)
                TextField("Launch link, such as mygame://", text: $link).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                Text("The game must register this link. An IPA filename or bundle identifier alone cannot open a game.").font(.footnote).foregroundStyle(.secondary)
            }.navigationTitle("Add game")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Add") { add(Game(name: name.trimmingCharacters(in: .whitespacesAndNewlines), launchURL: link)); dismiss() }.disabled(!valid) }
                }
        }
    }
}
