import SwiftUI
import UniformTypeIdentifiers
import PhotosUI
import ImageIO

struct Game: Identifiable, Codable {
    var id = UUID()
    var name: String
    var launchURL: String
    var favorite = false
    var artwork: Data?
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
    @State private var artworkGame: Game?
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
                                GameArtwork(data: game.artwork)
                                    .frame(height: 150)
                                    .frame(maxWidth: .infinity)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                Text(game.name).font(.headline).lineLimit(2)
                                Button("Play", systemImage: "play.fill") { launch(game.launchURL) }
                                    .buttonStyle(.borderedProminent).tint(.mint).foregroundStyle(.black)
                            }
                            .padding().frame(maxWidth: .infinity, alignment: .leading)
                            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 24))
                            .contextMenu {
                                Button("Change artwork", systemImage: "photo") { artworkGame = game }
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
        .sheet(item: $artworkGame) { game in
            ArtworkEditor(game: game) { data in
                guard let index = library.games.firstIndex(where: { $0.id == game.id }) else { return }
                let previous = library.games[index].artwork
                library.games[index].artwork = data
                do { try library.save() }
                catch { library.games[index].artwork = previous; self.error = error.localizedDescription }
            }
        }
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


struct GameArtwork: View {
    let data: Data?
    var body: some View {
        GeometryReader { geometry in
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height).clipped()
            } else {
                Image(systemName: "gamecontroller.fill").font(.system(size: 42)).foregroundStyle(.mint)
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
    }
}

struct ArtworkEditor: View {
    @Environment(\.dismiss) private var dismiss
    let game: Game
    let save: (Data?) -> Void
    @State private var selection: PhotosPickerItem?
    @State private var artwork: Data?
    @State private var loading = false
    @State private var message: String?
    init(game: Game, save: @escaping (Data?) -> Void) {
        self.game = game
        self.save = save
        _artwork = State(initialValue: game.artwork)
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    GameArtwork(data: artwork).frame(height: 260).clipped()
                    PhotosPicker(selection: $selection, matching: .images) {
                        Label("Choose from Photos", systemImage: "photo.on.rectangle")
                    }
                    if loading { ProgressView("Loading artwork…") }
                    if let message { Text(message).foregroundStyle(.red) }
                    if artwork != nil {
                        Button("Remove artwork", role: .destructive) { artwork = nil; selection = nil; message = nil }
                            .disabled(loading)
                    }
                } header: { Text(game.name) }
                  footer: { Text("Choose a cover or screenshot saved in Photos. Artwork stays in your library.") }
            }
            .navigationTitle("Game artwork")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save(artwork); dismiss() }.disabled(loading)
                }
            }
            .task(id: selection) {
                guard let selection else { return }
                loading = true
                message = nil
                defer { loading = false }
                do {
                    guard let data = try await selection.loadTransferable(type: Data.self) else {
                        message = "This photo could not be loaded."; return
                    }
                    try Task.checkCancellation()
                    let thumbnail = await Task.detached(priority: .userInitiated) {
                        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                                kCGImageSourceCreateThumbnailFromImageAlways: true,
                                kCGImageSourceThumbnailMaxPixelSize: 1000,
                                kCGImageSourceCreateThumbnailWithTransform: true
                              ] as CFDictionary)
                        else { return Optional<Data>.none }
                        return UIImage(cgImage: image).jpegData(compressionQuality: 0.85)
                    }.value
                    try Task.checkCancellation()
                    if let thumbnail { artwork = thumbnail }
                    else { message = "Choose a supported image." }
                } catch is CancellationError { }
                  catch { message = error.localizedDescription }
            }
        }
    }
}
