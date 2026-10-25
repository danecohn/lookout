import SwiftUI
import AppKit
import WebKit
import LookoutCore
// Disambiguate the stable property wrapper from the SDK 27 State macro.
typealias ViewState<Value> = SwiftUI.State<Value>

struct Glass: NSViewRepresentable {
    func makeNSView(context:Context)->NSVisualEffectView {let v=NSVisualEffectView();v.material = .sidebar;v.blendingMode = .behindWindow;v.state = .active;return v}
    func updateNSView(_ view:NSVisualEffectView,context:Context){}
}
struct PageSurface: NSViewRepresentable {
    let tab:BrowserTab
    func makeNSView(context:Context)->NSView {let container=NSView();attach(container);return container}
    func updateNSView(_ container:NSView,context:Context){attach(container)}
    func attach(_ container:NSView){let web=tab.prepare();guard web.superview !== container else{return};container.subviews.forEach{$0.removeFromSuperview()};web.removeFromSuperview();web.frame=container.bounds;web.autoresizingMask=[.width,.height];container.addSubview(web)}
}
struct AppIcon:View {
    var size:CGFloat=48
    var body:some View {Group{if let path=Bundle.main.path(forResource:"Lookout",ofType:"png"),let image=NSImage(contentsOfFile:path){Image(nsImage:image).resizable().interpolation(.high)}else{Image(systemName:"binoculars.fill").resizable().scaledToFit().padding(10).background(.blue.gradient)}}.frame(width:size,height:size)}
}
struct BrowserRoot:View {
    @ObservedObject var store:BrowserStore
    @FocusState private var addressFocused:Bool
    var body:some View {
        HStack(spacing:0){sidebar.frame(width:252)
            VStack(spacing:0){toolbar.padding(.horizontal,16).frame(height:64)
                HStack(spacing:10){page(store.current)
                    if let reference=store.reference {VStack(spacing:0){HStack{Image(systemName:"pin.fill").foregroundStyle(.blue);Text("Reference").font(.caption.weight(.semibold));Spacer();Button{store.select(reference.id)}label:{Image(systemName:"arrow.up.left.and.arrow.down.right")}.help("Swap with main page");Button{store.referenceID=nil}label:{Image(systemName:"xmark")}.help("Close reference pane")}.buttonStyle(.plain).padding(12);Text(reference.webView?.url?.host ?? reference.record.title).font(.caption).foregroundStyle(.secondary).lineLimit(1).padding(.bottom,8);Divider();page(reference)}.frame(minWidth:250,idealWidth:340,maxWidth:420).background(.regularMaterial).clipShape(RoundedRectangle(cornerRadius:14))}
                }.padding(.horizontal,12).padding(.bottom,12)
            }.background(Color(nsColor:.windowBackgroundColor).opacity(0.7))
        }.background(Glass()).accentColor(.blue).frame(minWidth:860,minHeight:580)
        .onChange(of:store.addressFocus){_,value in if value {addressFocused=true;DispatchQueue.main.async{NSApp.sendAction(#selector(NSText.selectAll(_:)),to:nil,from:nil)}}}
        .onChange(of:addressFocused){_,value in store.editingAddress=value;store.addressFocus=value}
        .sheet(isPresented:Binding(get:{store.panel != nil},set:{if !$0 {store.panel=nil}})){UtilityPanel(store:store)}
    }
    private var sidebar:some View {
        VStack(alignment:.leading,spacing:16){
            HStack{AppIcon(size:34);VStack(alignment:.leading,spacing:1){Text("Lookout").font(.system(size:17,weight:.semibold));Text(store.privateMode ? "PRIVATE WINDOW":"ARTEMIS SOFTWORKS").font(.system(size:8,weight:.semibold)).tracking(1.4).foregroundStyle(.secondary)};Spacer();if store.privateMode{Image(systemName:"hand.raised.fill").foregroundStyle(.purple)}}.padding(.top,49)
            HStack{Menu{ForEach(store.record.spaces){space in Button(space.name){store.switchSpace(space.id)}};Divider();Button("New space…"){store.newSpace()};Button("Rename space…"){store.renameSpace()};if store.record.spaces.count>1{Button("Remove space (keep tabs)"){store.removeSpace()}}}label:{HStack{Image(systemName:"square.stack.3d.up.fill").foregroundStyle(.blue);Text(store.record.spaces.first{$0.id==store.record.activeSpaceID}?.name ?? "Personal").fontWeight(.medium);Spacer();Image(systemName:"chevron.up.chevron.down").font(.caption2)}}.menuStyle(.borderlessButton)}.padding(11).background(.quaternary.opacity(0.5),in:RoundedRectangle(cornerRadius:11))
            Button{store.panel="tabs"}label:{HStack{Image(systemName:"magnifyingglass");Text("Find a tab or page");Spacer();Text("⌘K").font(.caption2)}}.buttonStyle(.plain).foregroundStyle(.secondary).font(.system(size:12)).padding(.horizontal,4)
            HStack{Text(store.focusTrail ? "FOCUS TRAIL":"YOUR TABS").font(.system(size:9,weight:.bold)).tracking(1.4).foregroundStyle(.secondary);Spacer();Button{store.focusTrail.toggle()}label:{Image(systemName:store.focusTrail ? "point.3.connected.trianglepath.dotted":"point.3.filled.connected.trianglepath.dotted")}.buttonStyle(.plain).foregroundStyle(store.focusTrail ? .blue:.secondary).help("Focus the current opener trail")}
            if store.focusTrail {Button("Show all tabs · \(store.spaceTabs.count)"){store.focusTrail=false}.buttonStyle(.plain).font(.caption).foregroundStyle(.blue)}
            ScrollView{LazyVStack(spacing:5){ForEach(store.visibleTabs){tab in tabRow(tab)}}}.scrollIndicators(.hidden)
            Button{_=store.newTab();store.addressFocus=true}label:{HStack{Image(systemName:"plus");Text("New tab");Spacer();Text("⌘T").font(.caption2)}}.buttonStyle(.plain).foregroundStyle(.secondary).padding(10)
            Divider()
            HStack(spacing:16){Button{store.panel="trails"}label:{Label("Trails",systemImage:"map")};Spacer();Button{store.panel="history"}label:{Image(systemName:"clock")}.help("History");Button{store.panel="settings"}label:{Image(systemName:"slider.horizontal.3")}.help("Settings")}.font(.system(size:12)).buttonStyle(.plain).foregroundStyle(.secondary)
        }.padding(.horizontal,16).padding(.bottom,18)
    }
    func tabRow(_ tab:BrowserTab)->some View {
        HStack(spacing:9){Image(systemName:tab.record.pinned ? "pin.fill":tab.record.address == nil ? "sparkle":"globe").font(.system(size:12)).foregroundStyle(tab.id==store.current.id ? .blue:.secondary).frame(width:18)
            Text(tab.record.title).font(.system(size:12,weight:tab.id==store.current.id ? .semibold:.regular)).lineLimit(1);Spacer(minLength:0)
            if tab.loading {ProgressView().controlSize(.mini).scaleEffect(0.7).frame(width:12)}
            Button{store.close(tab.id)}label:{Image(systemName:"xmark").font(.system(size:9,weight:.medium)).foregroundStyle(.secondary)}.buttonStyle(.plain).help("Close tab")
        }.padding(.horizontal,10).padding(.vertical,11).background(tab.id==store.current.id ? Color.accentColor.opacity(0.12):.clear,in:RoundedRectangle(cornerRadius:10)).contentShape(Rectangle()).onTapGesture{store.select(tab.id)}
        .contextMenu{Button(tab.record.pinned ? "Unpin tab":"Pin tab"){tab.record.pinned.toggle();store.changed()};Button("Duplicate"){_=store.newTab(url:tab.record.safeURL,parent:tab.id)};Button("Keep as reference"){if tab.id==store.current.id{store.toggleReference()}else{store.referenceID=tab.id}};Menu("Move to space"){ForEach(store.record.spaces){space in Button(space.name){tab.record.spaceID=space.id;store.switchSpace(space.id);store.select(tab.id);store.changed()}}};Button("Move up"){if let i=store.tabs.firstIndex(where:{$0.id==tab.id}),i>0{store.tabs.swapAt(i,i-1);store.changed()}};Button("Suspend page"){if store.approveClosing([tab]){tab.webView?.stopLoading();tab.webView=nil;tab.observations=[];tab.dirty=false;store.objectWillChange.send()}};Divider();Button("Close tab"){store.close(tab.id)}}
    }
    private var toolbar:some View {
        HStack(spacing:13){Button{store.current.webView?.goBack()}label:{Image(systemName:"chevron.left")}.disabled(store.current.webView?.canGoBack != true).help("Back");Button{store.current.webView?.goForward()}label:{Image(systemName:"chevron.right")}.disabled(store.current.webView?.canGoForward != true).help("Forward");Button{if store.current.loading{store.current.webView?.stopLoading()}else{store.current.webView?.reload()}}label:{Image(systemName:store.current.loading ? "xmark":"arrow.clockwise")}.help("Reload or stop")
            HStack(spacing:8){Image(systemName:store.current.webView?.hasOnlySecureContent == true && store.current.webView?.url?.scheme=="https" && store.current.failure==nil ? "lock":"globe").font(.system(size:11)).foregroundStyle(.secondary)
                TextField("Search or enter a web address",text:$store.address).textFieldStyle(.plain).font(.system(size:12)).focused($addressFocused).onSubmit{store.navigate()}
                if store.current.loading {ProgressView(value:store.current.progress).frame(width:36)}
            }.padding(.horizontal,12).frame(height:34).background(.background.opacity(0.75),in:RoundedRectangle(cornerRadius:10)).overlay(RoundedRectangle(cornerRadius:10).stroke(.primary.opacity(0.05)))
            Button{store.toggleReference()}label:{Image(systemName:"rectangle.split.2x1")}.help("Keep this page as a reference");Button{store.saveTrail()}label:{Image(systemName:"bookmark.badge.plus")}.help("Save this trail");Button{store.panel="downloads"}label:{Image(systemName:"arrow.down.circle")}.help("Downloads")
        }.buttonStyle(.plain).foregroundStyle(.secondary)
    }
    @ViewBuilder func page(_ tab:BrowserTab)->some View {
        ZStack{if let error=tab.failure {VStack(spacing:18){Image(systemName:"network.slash").font(.system(size:34)).foregroundStyle(.secondary);Text("This page couldn’t be opened").font(.title2.weight(.semibold));Text(error).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth:430);Text(tab.record.safeURL?.host ?? "").font(.caption);Button("Try again"){tab.open(tab.record.safeURL)}}.padding(32).frame(maxWidth:.infinity,maxHeight:.infinity).background(.background)}else if tab.record.address == nil {StartPage(store:store)}else{PageSurface(tab:tab).id(tab.id)}}.frame(maxWidth:.infinity,maxHeight:.infinity).background(.background).clipShape(RoundedRectangle(cornerRadius:14)).overlay(RoundedRectangle(cornerRadius:14).stroke(.primary.opacity(0.07))).shadow(color:.black.opacity(0.04),radius:12,y:3)
    }
}
struct StartPage:View {
    @ObservedObject var store:BrowserStore
    @ViewState var query=""
    let links:[(String,String,String)]=[("iCloud","icloud","https://www.icloud.com/"),("AltStack","square.stack.3d.up","https://www.amerika.social/"),("Artemis","moon.stars","https://www.amerika.social/artemis"),("Office","doc.text","https://office.altstack.org/"),("Mind","brain.head.profile","https://www.amerika.social/downloads/mind"),("Prompter","point.3.connected.trianglepath.dotted","https://www.amerika.social/downloads/prompter")]
    var body:some View {GeometryReader{geometry in ScrollView{VStack(spacing:25){AppIcon(size:94).shadow(color:.blue.opacity(0.15),radius:20,y:8);VStack(spacing:9){Text(store.privateMode ? "A little privacy.":"A little room to explore.").font(.system(size:31,weight:.semibold,design:.rounded));Text(store.privateMode ? "This window keeps no saved history, tabs, or trails.":"Find your direction. Keep what matters.").font(.system(size:14)).foregroundStyle(.secondary)}
        HStack{Image(systemName:"magnifyingglass").foregroundStyle(.blue);TextField("Where would you like to go?",text:$query).textFieldStyle(.plain).onSubmit{store.open(query)};Button{store.open(query)}label:{Image(systemName:"arrow.right.circle.fill").font(.title2).foregroundStyle(.blue)}.buttonStyle(.plain)}.padding(17).background(.regularMaterial,in:RoundedRectangle(cornerRadius:16)).overlay(RoundedRectangle(cornerRadius:16).stroke(.white.opacity(0.6))).shadow(color:.blue.opacity(0.06),radius:20,y:8)
        LazyVGrid(columns:[GridItem(.adaptive(minimum:125),spacing:14)],spacing:14){ForEach(links,id:\.0){link in Button{store.open(link.2)}label:{VStack(spacing:13){Image(systemName:link.1).font(.system(size:27,weight:.light)).foregroundStyle(.blue).frame(height:36);Text(link.0).font(.system(size:12,weight:.medium))}.frame(maxWidth:.infinity).padding(.vertical,20).background(.background.opacity(0.8),in:RoundedRectangle(cornerRadius:16)).overlay(RoundedRectangle(cornerRadius:16).stroke(.white.opacity(0.6)))}.buttonStyle(.plain)}}
        HStack(alignment:.top,spacing:12){Image(systemName:"point.3.connected.trianglepath.dotted").foregroundStyle(.blue).font(.title2);VStack(alignment:.leading,spacing:5){Text("Follow an idea, not a pile of tabs.").font(.system(size:13,weight:.semibold));Text("Open links in new tabs to build a trail. Focus the trail in the sidebar, keep a reference beside it, then save your sources with a purpose.").font(.system(size:12)).foregroundStyle(.secondary).lineSpacing(3)}}.padding(20).frame(maxWidth:.infinity,alignment:.leading).background(.regularMaterial,in:RoundedRectangle(cornerRadius:16))
        Text("ARTEMIS SOFTWORKS LLC").font(.system(size:9,weight:.medium)).tracking(2).foregroundStyle(.tertiary)
    }.frame(maxWidth:620).padding(.horizontal,38).padding(.vertical,max(35,(geometry.size.height-560)/2)).frame(maxWidth:.infinity)}}.background(LinearGradient(colors:[Color(red:0.68,green:0.84,blue:1).opacity(0.65),Color(nsColor:.windowBackgroundColor),Color(red:0.85,green:0.9,blue:1).opacity(0.3)],startPoint:.topLeading,endPoint:.bottomTrailing))}
}
struct UtilityPanel:View {
    @ObservedObject var store:BrowserStore
    @ViewState var query=""
    var body:some View {VStack(alignment:.leading,spacing:18){HStack{Text(title).font(.title2.weight(.semibold));Spacer();Button("Done"){store.panel=nil}.keyboardShortcut(.cancelAction)}
        if store.panel=="settings" {settings}else if store.panel=="trails" {trails}else if store.panel=="downloads" {ScrollView{VStack(alignment:.leading,spacing:12){Text("Downloads are saved only after you choose a destination.").foregroundStyle(.secondary);ForEach(store.downloads,id:\.self){url in HStack{Image(systemName:"doc");Text(url.lastPathComponent);Spacer();Button("Show in Finder"){NSWorkspace.shared.activateFileViewerSelecting([url])}}}}}}else{TextField(store.panel=="tabs" ? "Find across all spaces":"Search browsing history",text:$query).textFieldStyle(.roundedBorder);ScrollView{LazyVStack(alignment:.leading,spacing:10){if store.panel=="tabs" {ForEach(store.tabs.filter{query.isEmpty || $0.record.title.localizedCaseInsensitiveContains(query) || ($0.record.address ?? "").localizedCaseInsensitiveContains(query)}){tab in Button{store.select(tab.id);store.panel=nil}label:{row(tab.record.title,tab.record.address ?? "New tab")}.buttonStyle(.plain)}}else{if store.privateMode{Text("Private windows don’t record or display history.").foregroundStyle(.secondary)}else{ForEach((store.app?.archive.history ?? []).filter{query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) || $0.address.localizedCaseInsensitiveContains(query)}){visit in Button{store.open(visit.address);store.panel=nil}label:{row(visit.title,visit.address)}.buttonStyle(.plain)}}}}};if store.panel=="history" && !store.privateMode {Button("Clear browsing history"){store.app?.archive.history=[];store.changed()}}}
    }.padding(26).frame(width:620,height:490)}
    var title:String {switch store.panel{case "settings":return "Make yourself at home";case "trails":return "Saved trails";case "history":return "History";case "downloads":return "Downloads";default:return "Go somewhere"}}
    func row(_ title:String,_ subtitle:String)->some View {VStack(alignment:.leading,spacing:4){Text(title).fontWeight(.medium).lineLimit(1);Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)}.frame(maxWidth:.infinity,alignment:.leading).padding(10).background(.quaternary,in:RoundedRectangle(cornerRadius:9))}
    var trails:some View {ScrollView{VStack(alignment:.leading,spacing:16){Text("A purpose, a set of sources, a place to pick up again. Markdown exports include links and your note; they don’t include page contents.").foregroundStyle(.secondary);if store.privateMode{Text("Saved trails are unavailable in private windows.")}else{if store.app?.archive.trails.isEmpty != false {Text("Your first trail starts with an open page. Use the bookmark button to keep it.").padding(.top,30)};ForEach(store.app?.archive.trails ?? []){trail in VStack(alignment:.leading,spacing:10){Text(trail.name).font(.headline);Text(trail.purpose).foregroundStyle(.secondary);HStack{Text("\(trail.pages.count) sources").font(.caption).foregroundStyle(.secondary);Spacer();Button("Resume"){store.resume(trail)};Button("Export Markdown…"){store.export(trail)};Button{store.app?.archive.trails.removeAll{$0.id==trail.id};store.changed()}label:{Image(systemName:"trash")}.help("Delete saved trail")}}.padding(16).background(.quaternary,in:RoundedRectangle(cornerRadius:12))}}}}}
    var settings:some View {VStack(alignment:.leading,spacing:22){Picker("Search engine",selection:Binding(get:{store.app?.archive.settings.searchProvider ?? .artemisearch},set:{store.app?.archive.settings.searchProvider=$0;store.changed()})){ForEach(SearchProvider.allCases,id:\.self){Text($0.label).tag($0)}};Toggle("Restore regular windows at launch",isOn:Binding(get:{store.app?.archive.settings.restoreSession ?? true},set:{store.app?.archive.settings.restoreSession=$0;store.changed()}));Text("Regular windows save tabs, history, and trails on this Mac. Private windows use a separate temporary website store. No analytics or account is required.").font(.callout).foregroundStyle(.secondary);Divider();Text("Website data is separate from Safari.").font(.headline);Button("Clear Lookout website cookies and caches…"){let a=NSAlert();a.messageText="Sign out of websites in Lookout?";a.informativeText="This clears regular-window cookies and caches. Your tabs and trails remain.";a.addButton(withTitle:"Cancel");a.addButton(withTitle:"Clear website data");if a.runModal() == .alertSecondButtonReturn {WKWebsiteDataStore.default().removeData(ofTypes:WKWebsiteDataStore.allWebsiteDataTypes(),modifiedSince:.distantPast){}}};Spacer();Text("Artemis Lookout 0.1.0 · Artemis Softworks LLC\nCreated by Demetria Althea Cohn. Powered by the system WebKit framework.").font(.caption).foregroundStyle(.secondary)}}
}
