import Foundation

public enum LookoutError: Error, LocalizedError {
    case unsafeAddress, unsupportedSession, invalidSession
    public var errorDescription: String? {
        switch self {
        case .unsafeAddress: return "Enter a web address or a search. Script, data, and file addresses cannot be opened from the address bar."
        case .unsupportedSession: return "This session belongs to a newer version of Lookout. The original session file has been preserved."
        case .invalidSession: return "The saved browser session could not be read. The original file has been preserved."
        }
    }
}
public enum SearchProvider: String, Codable, CaseIterable {
    case artemisearch, altstack, kagi, duckduckgo, google
    public var label: String { switch self { case .artemisearch: return "Vigil Search"; case .altstack: return "Vigil Search (legacy preference)"; case .kagi: return "Kagi"; case .duckduckgo: return "DuckDuckGo"; case .google: return "Google" } }
    public func search(_ query: String) -> URL {
        var parts = URLComponents(string: (self == .artemisearch || self == .altstack) ? "https://www.amerika.social/search/" : self == .kagi ? "https://kagi.com/search" : self == .duckduckgo ? "https://duckduckgo.com/" : "https://www.google.com/search")!
        parts.queryItems = [URLQueryItem(name: "q", value: query)]
        return parts.url!
    }
}
public enum AddressResolver {
    public static func resolve(_ input: String, provider: SearchProvider = .artemisearch) throws -> URL? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty || text == "lookout:home" { return nil }
        if text.range(of: #"^[A-Za-z][A-Za-z0-9+.-]*:"#, options: .regularExpression) != nil {
            // localhost:port is an address, not an application scheme.
            if text.range(of: #"^(localhost|127\.0\.0\.1):[0-9]+"#, options: .regularExpression) == nil {
                guard let url = URL(string: text), isWebURL(url) else { throw LookoutError.unsafeAddress }
                return url
            }
        }
        let looksLikeHost = !text.contains(where: { $0.isWhitespace }) && (text.contains(".") || text.hasPrefix("localhost") || text.hasPrefix("[::1]"))
        if looksLikeHost {
            let loopback = text.hasPrefix("localhost") || text.hasPrefix("127.0.0.1") || text.hasPrefix("[::1]")
            if let url = URL(string: (loopback ? "http://" : "https://") + text), isWebURL(url) { return url }
        }
        return provider.search(text)
    }
    public static func isWebURL(_ url: URL) -> Bool {
        ["https", "http"].contains(url.scheme?.lowercased() ?? "") && url.host != nil && url.user == nil && url.password == nil
    }
    public static func persisted(_ url: URL?) -> String? {
        guard let url, isWebURL(url), var parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let secrets = Set(["access_token", "id_token", "refresh_token", "authorization_code", "code", "password", "token"])
        if (parts.queryItems ?? []).contains(where: { secrets.contains($0.name.lowercased()) }) { return nil }
        if let fragment = parts.fragment, fragment.contains("access_token=") || fragment.contains("id_token=") { return nil }
        parts.fragment = nil
        return parts.url?.absoluteString
    }
}
public struct SpaceRecord: Codable, Identifiable, Equatable {
    public var id: UUID; public var name: String; public var color: String
    public init(id: UUID = UUID(), name: String, color: String = "blue") { self.id=id; self.name=String(name.prefix(50)); self.color=color }
}
public struct TabRecord: Codable, Identifiable, Equatable {
    public var id: UUID; public var spaceID: UUID; public var title: String; public var address: String?; public var pinned: Bool; public var parentID: UUID?
    public init(id: UUID = UUID(), spaceID: UUID, title: String = "New tab", address: String? = nil, pinned: Bool = false, parentID: UUID? = nil) {
        self.id=id; self.spaceID=spaceID; self.title=String(title.prefix(200)); self.address=address; self.pinned=pinned; self.parentID=parentID
    }
    public var safeURL: URL? { guard let address, let url=URL(string:address), AddressResolver.isWebURL(url) else { return nil }; return url }
}
public struct WindowRecord: Codable, Identifiable, Equatable {
    public var id: UUID; public var spaces: [SpaceRecord]; public var tabs: [TabRecord]; public var activeSpaceID: UUID; public var selectedID: UUID
    public init(id: UUID = UUID(), spaces: [SpaceRecord], tabs: [TabRecord], activeSpaceID: UUID, selectedID: UUID) { self.id=id; self.spaces=spaces; self.tabs=tabs; self.activeSpaceID=activeSpaceID; self.selectedID=selectedID }
    public static func fresh(privateMode: Bool = false) -> WindowRecord {
        let personal=SpaceRecord(name:privateMode ? "Private" : "Personal",color:privateMode ? "purple" : "blue")
        let tab=TabRecord(spaceID:personal.id)
        return WindowRecord(spaces:[personal],tabs:[tab],activeSpaceID:personal.id,selectedID:tab.id)
    }
    public mutating func validate() {
        spaces=Array(spaces.prefix(30)); if spaces.isEmpty { self = .fresh(); return }
        let valid=Set(spaces.map(\.id)); var seen=Set<UUID>()
        tabs=Array(tabs.filter { valid.contains($0.spaceID) && seen.insert($0.id).inserted }.prefix(500)).map { tab in
            var safe=tab; safe.title=String(safe.title.prefix(200)); safe.address=AddressResolver.persisted(tab.safeURL); return safe
        }
        for space in spaces where !tabs.contains(where:{$0.spaceID==space.id}) { tabs.append(TabRecord(spaceID:space.id)) }
        if !valid.contains(activeSpaceID) { activeSpaceID=spaces[0].id }
        if !tabs.contains(where:{$0.id==selectedID && $0.spaceID==activeSpaceID}) { selectedID=tabs.first(where:{$0.spaceID==activeSpaceID})!.id }
    }
    public mutating func removeSpace(_ id: UUID) {
        guard spaces.count>1, let destination=spaces.first(where:{$0.id != id}) else { return }
        for index in tabs.indices where tabs[index].spaceID==id { tabs[index].spaceID=destination.id }
        spaces.removeAll{$0.id==id}; if activeSpaceID==id { activeSpaceID=destination.id }; validate()
    }
}
public struct Visit: Codable, Identifiable, Equatable {
    public var id: UUID; public var title: String; public var address: String; public var date: Date
    public init(title: String, address: String, date: Date = Date()) { id=UUID(); self.title=String(title.prefix(200)); self.address=address; self.date=date }
}
public struct Settings: Codable, Equatable {
    public var searchProvider: SearchProvider = .artemisearch
    public var restoreSession = true
    public var appearance = "system"
    public init() {}
}
public struct TrailPage: Codable, Equatable {
    public var title: String; public var address: String
    public init(title: String, address: String) { self.title=title; self.address=address }
}
public struct TrailRecord: Codable, Identifiable, Equatable {
    public var id=UUID(); public var name: String; public var purpose: String; public var pages: [TrailPage]; public var created=Date()
    public init(name: String, purpose: String, tabs: [TabRecord]) {
        self.name=String(name.prefix(100)); self.purpose=String(purpose.prefix(10000)); self.pages=tabs.compactMap { tab in guard let address=AddressResolver.persisted(tab.safeURL) else { return nil }; return TrailPage(title:tab.title,address:address) }
    }
    public var markdown: String {
        "# \(name)\n\n\(purpose)\n\n## Sources\n\n" + pages.enumerated().map { "\($0.offset+1). [\($0.element.title.replacingOccurrences(of:"]",with:"\\]"))](\($0.element.address))" }.joined(separator:"\n") + "\n\n---\nSaved with Vigil Lookout · VigilTech\n"
    }
}
public struct Archive: Codable {
    public var schemaVersion = 1
    public var windows: [WindowRecord]
    public var history: [Visit] = []
    public var settings = Settings()
    public var trails: [TrailRecord] = []
    public init(windows: [WindowRecord] = []) { self.windows=windows }
    public mutating func addVisit(_ url: URL, title: String, privateMode: Bool) {
        guard !privateMode, let address=AddressResolver.persisted(url) else { return }
        history.removeAll{$0.address==address}; history.insert(Visit(title:title,address:address),at:0); history=Array(history.prefix(1500))
    }
    public mutating func validate() throws {
        guard schemaVersion==1 else { throw LookoutError.unsupportedSession }
        windows=Array(windows.prefix(12)); for i in windows.indices { windows[i].validate() }
        history=Array(history.filter { URL(string:$0.address).map(AddressResolver.isWebURL) == true }.prefix(1500))
        trails=Array(trails.prefix(200)).map { trail in var safe=trail;safe.pages=Array(trail.pages.filter{URL(string:$0.address).map(AddressResolver.isWebURL)==true}.prefix(100));return safe }
    }
}
public final class SessionFile {
    public let url: URL
    public init(url: URL) { self.url=url }
    public func load() throws -> Archive {
        guard FileManager.default.fileExists(atPath:url.path) else { return Archive() }
        guard let data=try? Data(contentsOf:url), data.count <= 8*1024*1024 else { throw LookoutError.invalidSession }
        do { var archive=try JSONDecoder().decode(Archive.self,from:data); try archive.validate(); return archive } catch let error as LookoutError { throw error } catch { throw LookoutError.invalidSession }
    }
    public func save(_ archive: Archive) throws {
        var safe=archive; try safe.validate(); try FileManager.default.createDirectory(at:url.deletingLastPathComponent(),withIntermediateDirectories:true)
        let encoder=JSONEncoder(); encoder.outputFormatting=[.prettyPrinted,.sortedKeys]
        try encoder.encode(safe).write(to:url,options:.atomic)
        try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:url.path)
    }
}

public enum TrailGraph {
    /// A trail is the selected tab's connected opener tree, restricted to its space.
    /// Visited IDs bound traversal even when imported data contains cycles.
    public static func branch(selected: UUID, tabs: [TabRecord]) -> Set<UUID> {
        guard let current=tabs.first(where:{$0.id==selected}) else{return []}
        let local=tabs.filter{$0.spaceID==current.spaceID};let ids=Set(local.map(\.id))
        var root=selected;var visited=Set<UUID>()
        while visited.insert(root).inserted,let parent=local.first(where:{$0.id==root})?.parentID,ids.contains(parent) {root=parent}
        var result:Set<UUID>=[root,selected];var changed=true
        while changed {changed=false;for tab in local where !result.contains(tab.id) {if let parent=tab.parentID,result.contains(parent){result.insert(tab.id);changed=true}}}
        return result
    }
}
