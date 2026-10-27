import AppKit
import WebKit
import SwiftUI
import LookoutCore

@MainActor final class BrowserTab: NSObject, Identifiable, WKNavigationDelegate, WKUIDelegate, WKDownloadDelegate {
    var record: TabRecord
    nonisolated let id: UUID
    weak var owner: BrowserStore?
    var webView: WKWebView?
    var observations: [NSKeyValueObservation] = []
    var failure: String?
    var dirty = false
    var loading = false
    var progress = 0.0
    init(_ record: TabRecord, owner: BrowserStore) { self.record=record; self.id=record.id; self.owner=owner }
    func prepare(configuration supplied: WKWebViewConfiguration? = nil) -> WKWebView {
        if let webView { return webView }
        let config=supplied ?? WKWebViewConfiguration()
        config.websiteDataStore=owner!.dataStore
        config.preferences.javaScriptCanOpenWindowsAutomatically=false
        config.userContentController=WKUserContentController()
        let tracker=DirtyTracker(tab:self)
        config.userContentController.add(tracker,name:"lookoutDirty")
        config.userContentController.addUserScript(WKUserScript(source:"addEventListener('input',()=>webkit.messageHandlers.lookoutDirty.postMessage(true),true);addEventListener('submit',()=>webkit.messageHandlers.lookoutDirty.postMessage(false),true);",injectionTime:.atDocumentStart,forMainFrameOnly:true))
        let view=WKWebView(frame:.zero,configuration:config)
        view.navigationDelegate=self; view.uiDelegate=self; view.allowsBackForwardNavigationGestures=true
        webView=view
        observations=[
            view.observe(\.title,options:[.new]) { [weak self] _,_ in Task { @MainActor in self?.updated() } },
            view.observe(\.url,options:[.new]) { [weak self] _,_ in Task { @MainActor in self?.updated() } },
            view.observe(\.estimatedProgress,options:[.new]) { [weak self] view,_ in Task { @MainActor in self?.progress=view.estimatedProgress;self?.owner?.objectWillChange.send() } },
            view.observe(\.isLoading,options:[.new]) { [weak self] view,_ in Task { @MainActor in self?.loading=view.isLoading;self?.owner?.objectWillChange.send() } }
        ]
        if supplied == nil, let url=record.safeURL { view.load(URLRequest(url:url)) }
        return view
    }
    func updated() {
        if let title=webView?.title, !title.isEmpty { record.title=String(title.prefix(200)) }
        if let url=webView?.url, AddressResolver.isWebURL(url) { record.address=url.absoluteString }
        owner?.pageChanged(self)
    }
    func open(_ url: URL?) {
        failure=nil;dirty=false
        guard let url else { webView?.stopLoading();webView=nil;observations=[];record.address=nil;record.title="New tab";owner?.pageChanged(self);return }
        record.address=url.absoluteString
        let existed=webView != nil
        let view=prepare()
        if existed { view.load(URLRequest(url:url)) }
        owner?.pageChanged(self)
    }
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) { failure=nil;dirty=false;owner?.objectWillChange.send() }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { updated();owner?.visited(self) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { fail(error) }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { fail(error) }
    func fail(_ error: Error) { if (error as NSError).code != NSURLErrorCancelled { failure=error.localizedDescription;owner?.objectWillChange.send() } }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { failure="This page stopped responding. Reload to continue.";owner?.objectWillChange.send() }
    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) { completionHandler(.performDefaultHandling,nil) }
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy)->Void) {
        guard let url=action.request.url else { decisionHandler(.cancel);return }
        if ["about","blob"].contains(url.scheme ?? "") || AddressResolver.isWebURL(url) { decisionHandler(action.shouldPerformDownload ? .download : .allow);return }
        if ["mailto","tel"].contains(url.scheme ?? ""), action.navigationType == .linkActivated {
            let alert=NSAlert();alert.messageText="Open another app?";alert.informativeText=url.absoluteString;alert.addButton(withTitle:"Open");alert.addButton(withTitle:"Cancel")
            if alert.runModal() == .alertFirstButtonReturn { NSWorkspace.shared.open(url) }
        }
        decisionHandler(.cancel)
    }
    func webView(_ webView: WKWebView, decidePolicyFor response: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy)->Void) { decisionHandler(response.canShowMIMEType ? .allow : .download) }
    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) { download.delegate=self }
    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) { download.delegate=self }
    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?)->Void) {
        let panel=NSSavePanel();panel.nameFieldStringValue=(suggestedFilename as NSString).lastPathComponent;panel.title="Save download"
        if panel.runModal() == .OK, let url=panel.url {
            do { if FileManager.default.fileExists(atPath:url.path) { try FileManager.default.removeItem(at:url) };owner?.downloads.insert(url,at:0);completionHandler(url) }
            catch { owner?.show(error.localizedDescription);completionHandler(nil) }
        } else { completionHandler(nil) }
    }
    func downloadDidFinish(_ download: WKDownload) { owner?.objectWillChange.send() }
    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) { owner?.show("Download failed: \(error.localizedDescription)") }
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard let owner, let url=action.request.url, AddressResolver.isWebURL(url) else { return nil }
        let tab=owner.newTab(url:nil,parent:id);tab.record.address=url.absoluteString
        return tab.prepare(configuration:configuration)
    }
    func webViewDidClose(_ webView: WKWebView) { owner?.close(id) }
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ()->Void) { let a=pageAlert(message,frame);a.runModal();completionHandler() }
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool)->Void) { let a=pageAlert(message,frame);a.addButton(withTitle:"Cancel");completionHandler(a.runModal() == .alertFirstButtonReturn) }
    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?)->Void) { let a=pageAlert(prompt,frame);let field=NSTextField(string:defaultText ?? "");field.frame=NSRect(x:0,y:0,width:300,height:24);a.accessoryView=field;a.addButton(withTitle:"Cancel");completionHandler(a.runModal() == .alertFirstButtonReturn ? field.stringValue:nil) }
    func pageAlert(_ message: String,_ frame: WKFrameInfo)->NSAlert { let a=NSAlert();a.messageText=frame.request.url?.host ?? "Website";a.informativeText=String(message.prefix(5000));a.addButton(withTitle:"OK");return a }
    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?)->Void) { let panel=NSOpenPanel();panel.canChooseDirectories=parameters.allowsDirectories;panel.allowsMultipleSelection=parameters.allowsMultipleSelection;completionHandler(panel.runModal() == .OK ? panel.urls:nil) }
}
@MainActor final class DirtyTracker: NSObject, WKScriptMessageHandler {
    weak var tab: BrowserTab?
    init(tab: BrowserTab) { self.tab=tab }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) { tab?.dirty=(message.body as? Bool)==true }
}

@MainActor final class BrowserStore: ObservableObject {
    var record: WindowRecord
    let privateMode: Bool
    let dataStore: WKWebsiteDataStore
    var tabs: [BrowserTab]=[]
    @Published var referenceID: UUID?
    @Published var focusTrail=false
    @Published var address=""
    @Published var editingAddress=false
    @Published var addressFocus=false
    @Published var panel: String?
    @Published var downloads: [URL]=[]
    var closed: [TabRecord]=[]
    weak var app: AppController?
    var current: BrowserTab { tabs.first{$0.id==record.selectedID} ?? tabs[0] }
    var reference: BrowserTab? { tabs.first{$0.id==referenceID} }
    var spaceTabs: [BrowserTab] { tabs.filter{$0.record.spaceID==record.activeSpaceID} }
    var trailIDs: Set<UUID> { TrailGraph.branch(selected:current.id,tabs:tabs.map(\.record)) }
    var visibleTabs: [BrowserTab] { spaceTabs.filter{!focusTrail || trailIDs.contains($0.id)}.sorted{ $0.record.pinned && !$1.record.pinned } }
    init(record: WindowRecord, privateMode: Bool, app: AppController) {
        self.record=record;self.privateMode=privateMode;self.app=app
        dataStore=privateMode ? .nonPersistent():.default()
        self.record.validate();tabs=self.record.tabs.map{BrowserTab($0,owner:self)};address=current.record.address ?? ""
    }
    func changed() { objectWillChange.send();app?.save() }
    func pageChanged(_ tab: BrowserTab) { if current.id==tab.id && !editingAddress { address=tab.record.address ?? "" };changed() }
    func visited(_ tab: BrowserTab) { if let url=tab.webView?.url { app?.archive.addVisit(url,title:tab.record.title,privateMode:privateMode) };changed() }
    func snapshot()->WindowRecord { var result=record;result.tabs=tabs.map(\.record);return result }
    @discardableResult func newTab(url: URL? = nil,parent: UUID? = nil)->BrowserTab {
        let tab=BrowserTab(TabRecord(spaceID:record.activeSpaceID,address:url?.absoluteString,parentID:parent),owner:self)
        tabs.append(tab);select(tab.id);return tab
    }
    func select(_ id: UUID) {
        guard let tab=tabs.first(where:{$0.id==id}) else { return }
        if referenceID==id { referenceID=record.selectedID }
        if tab.record.spaceID != record.activeSpaceID { referenceID=nil;record.activeSpaceID=tab.record.spaceID }
        record.selectedID=id;address=tab.record.address ?? "";editingAddress=false;changed()
    }
    func navigate() { do { current.open(try AddressResolver.resolve(address,provider:app?.archive.settings.searchProvider ?? .artemisearch));editingAddress=false;addressFocus=false } catch { show(error.localizedDescription) } }
    func open(_ text: String) { address=text;navigate() }
    func switchSpace(_ id: UUID) { record.activeSpaceID=id;referenceID=nil;focusTrail=false;if let first=spaceTabs.first { select(first.id) } }
    func close(_ id: UUID) {
        guard let index=tabs.firstIndex(where:{$0.id==id}), approveClosing([tabs[index]]) else {return}
        let old=tabs.remove(at:index);old.webView?.stopLoading();closed.append(old.record);closed=Array(closed.suffix(30))
        if referenceID==id { referenceID=nil }
        if spaceTabs.isEmpty { _=newTab() } else if current.id==id || !tabs.contains(where:{$0.id==record.selectedID}) { select(spaceTabs[0].id) }
        changed()
    }
    func approveClosing(_ list:[BrowserTab])->Bool {
        guard list.contains(where:{$0.dirty}) else{return true}
        let alert=NSAlert();alert.messageText="Leave pages with unsaved changes?";alert.informativeText="A page contains an edited form. Your changes may be lost.";alert.addButton(withTitle:"Keep browsing");alert.addButton(withTitle:"Leave pages");return alert.runModal() == .alertSecondButtonReturn
    }
    func reopen() { guard var old=closed.popLast() else{return};old.spaceID=record.activeSpaceID;let tab=BrowserTab(old,owner:self);tabs.append(tab);select(tab.id) }
    func toggleReference() { if referenceID != nil {referenceID=nil} else {referenceID=current.id;_=newTab(parent:current.id)};changed() }
    func newSpace() { if let name=ask("Create a space",detail:"Give this part of your browsing a name.",value:"New space") { let space=SpaceRecord(name:name);record.spaces.append(space);record.activeSpaceID=space.id;referenceID=nil;focusTrail=false;_=newTab() } }
    func renameSpace() { guard let index=record.spaces.firstIndex(where:{$0.id==record.activeSpaceID}), let name=ask("Rename space",detail:"",value:record.spaces[index].name) else{return};record.spaces[index].name=String(name.prefix(50));changed() }
    func removeSpace() { guard record.spaces.count>1 else{return};var value=snapshot();value.removeSpace(record.activeSpaceID);record=value;for tab in tabs { if let saved=value.tabs.first(where:{$0.id==tab.id}) {tab.record=saved} };referenceID=nil;focusTrail=false;changed() }
    func saveTrail() {
        guard !privateMode else {show("Saved trails are disabled in private windows. Open a regular window to keep a trail.");return}
        let alert=NSAlert();alert.messageText="Keep this trail";alert.informativeText="Save related pages and a purpose. Page contents and passwords are not included.";alert.addButton(withTitle:"Save trail");alert.addButton(withTitle:"Cancel")
        let stack=NSStackView();stack.orientation = .vertical;stack.alignment = .leading;stack.spacing=10
        let name=NSTextField(string:current.record.title=="New tab" ? "New trail":current.record.title);name.placeholderString="Trail name"
        let purpose=NSTextField(string:"");purpose.placeholderString="What are you exploring?";stack.addArrangedSubview(name);stack.addArrangedSubview(purpose);stack.frame=NSRect(x:0,y:0,width:360,height:64);alert.accessoryView=stack
        if alert.runModal() == .alertFirstButtonReturn { let trail=TrailRecord(name:name.stringValue,purpose:purpose.stringValue,tabs:tabs.filter{trailIDs.contains($0.id)}.map(\.record));guard !trail.pages.isEmpty else{show("Open a web page before saving a trail.");return};app?.archive.trails.insert(trail,at:0);changed();panel="trails" }
    }
    func resume(_ trail: TrailRecord) { let space=SpaceRecord(name:trail.name);record.spaces.append(space);record.activeSpaceID=space.id;referenceID=nil;focusTrail=false;var parent:UUID?;for page in trail.pages { let t=newTab(url:URL(string:page.address),parent:parent);t.record.title=page.title;parent=t.id };if spaceTabs.isEmpty {_=newTab()};panel=nil;changed() }
    func export(_ trail: TrailRecord) { let panel=NSSavePanel();panel.nameFieldStringValue=trail.name.replacingOccurrences(of:"/",with:"-")+".md";if panel.runModal() == .OK,let url=panel.url {do{try trail.markdown.write(to:url,atomically:true,encoding:.utf8)}catch{show(error.localizedDescription)}} }
    func ask(_ title:String,detail:String,value:String)->String? {let a=NSAlert();a.messageText=title;a.informativeText=detail;a.addButton(withTitle:"Save");a.addButton(withTitle:"Cancel");let f=NSTextField(string:value);f.frame=NSRect(x:0,y:0,width:300,height:24);a.accessoryView=f;guard a.runModal() == .alertFirstButtonReturn else{return nil};let result=f.stringValue.trimmingCharacters(in:.whitespacesAndNewlines);return result.isEmpty ? nil:result}
    func show(_ message: String) { let a=NSAlert();a.messageText="Vigil Lookout";a.informativeText=message;a.runModal() }
    func find() {guard let view=current.webView,let query=ask("Find on this page",detail:"",value:"") else{return};let config=WKFindConfiguration();config.wraps=true;view.find(query,configuration:config){[weak self] result in if !result.matchFound {self?.show("No matches found.")} } }
}
