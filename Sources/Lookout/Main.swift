import AppKit
import CoreText
import SwiftUI
import LookoutCore

@MainActor final class BrowserWindow: NSWindowController, NSWindowDelegate {
    let store:BrowserStore
    init(store:BrowserStore) {
        self.store=store
        let window=NSWindow(contentRect:NSRect(x:0,y:0,width:1240,height:820),styleMask:[.titled,.closable,.miniaturizable,.resizable,.fullSizeContentView],backing:.buffered,defer:false)
        window.title=store.privateMode ? "Cohnsoft Lookout — Private":"Cohnsoft Lookout";window.titleVisibility = .hidden;window.titlebarAppearsTransparent=true;window.isReleasedWhenClosed=false;window.backgroundColor = .clear;window.minSize=NSSize(width:860,height:580)
        window.contentView=NSHostingView(rootView:BrowserRoot(store:store).font(.custom("Cohn Sans",size:13)).ignoresSafeArea());window.center()
        super.init(window:window);window.delegate=self
    }
    required init?(coder:NSCoder){fatalError("Not supported")}
    func windowShouldClose(_ sender:NSWindow)->Bool{store.approveClosing(store.tabs)}
    func windowWillClose(_ notification:Notification){store.app?.closed(self)}
}
@MainActor final class AppController:NSObject,NSApplicationDelegate {
    var archive=Archive()
    var windows:[BrowserWindow]=[]
    var persistenceEnabled=true
    let file:SessionFile
    var timer:Timer?
    override init(){let base=FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("Artemis Lookout",isDirectory:true);file=SessionFile(url:base.appendingPathComponent("session.json"));super.init()}
    var active:BrowserStore?{windows.first{$0.window===NSApp.keyWindow}?.store ?? windows.last?.store}
    func applicationDidFinishLaunching(_ notification:Notification){
        if CommandLine.arguments.contains("--self-test") {Task{await SelfTest.run()};return}
        do{archive=try file.load()}catch{persistenceEnabled=false;let alert=NSAlert();alert.messageText="Your previous session is preserved";alert.informativeText=error.localizedDescription+" Lookout will run without saving this session. Move the saved file aside before relaunching to start fresh.";alert.runModal()}
        makeMenu()
        if archive.settings.restoreSession && !archive.windows.isEmpty{let records=archive.windows;for record in records{newWindow(record:record)}}else{newWindow()}
        NSApp.activate(ignoringOtherApps:true)
    }
    func newWindow(privateMode:Bool=false,record:WindowRecord?=nil){let store=BrowserStore(record:record ?? .fresh(privateMode:privateMode),privateMode:privateMode,app:self);let controller=BrowserWindow(store:store);windows.append(controller);controller.showWindow(nil);save()}
    func save(){guard persistenceEnabled else{return};timer?.invalidate();timer=Timer.scheduledTimer(withTimeInterval:0.5,repeats:false){[weak self] _ in Task{@MainActor in self?.flush()}}}
    func flush(){guard persistenceEnabled else{return};let normal=windows.filter{!$0.store.privateMode}.map{$0.store.snapshot()};if !normal.isEmpty{archive.windows=normal};do{try file.save(archive)}catch{persistenceEnabled=false;active?.show("Your session could not be saved: \(error.localizedDescription)")}}
    func closed(_ controller:BrowserWindow){if !controller.store.privateMode{archive.windows=windows.filter{!$0.store.privateMode}.map{$0.store.snapshot()}};windows.removeAll{$0===controller};save()}
    func applicationShouldTerminate(_ sender:NSApplication)->NSApplication.TerminateReply{for window in windows{if !window.store.approveClosing(window.store.tabs){return .terminateCancel}};flush();return .terminateNow}
    func applicationShouldHandleReopen(_ sender:NSApplication,hasVisibleWindows flag:Bool)->Bool{if !flag{newWindow()};return true}
    func application(_ application:NSApplication,open urls:[URL]){if windows.isEmpty{newWindow()};for url in urls where AddressResolver.isWebURL(url){_=active?.newTab(url:url)}}
    func makeMenu(){
        let bar=NSMenu();NSApp.mainMenu=bar
        func menu(_ name:String)->NSMenu{let item=NSMenuItem();bar.addItem(item);let m=NSMenu(title:name);item.submenu=m;return m}
        func item(_ menu:NSMenu,_ title:String,_ action:Selector,_ key:String="",_ mods:NSEvent.ModifierFlags = [.command]){let i=NSMenuItem(title:title,action:action,keyEquivalent:key);i.target=self;i.keyEquivalentModifierMask=mods;menu.addItem(i)}
        let app=menu("Lookout");item(app,"About Cohnsoft Lookout",#selector(about));app.addItem(.separator());item(app,"Settings…",#selector(settings),",");app.addItem(.separator());let hide=NSMenuItem(title:"Hide Lookout",action:#selector(NSApplication.hide(_:)),keyEquivalent:"h");app.addItem(hide);app.addItem(.separator());app.addItem(NSMenuItem(title:"Quit Lookout",action:#selector(NSApplication.terminate(_:)),keyEquivalent:"q"))
        let file=menu("File");item(file,"New Tab",#selector(newTab),"t");item(file,"New Window",#selector(regular),"n");item(file,"New Private Window",#selector(privateWindow),"n",[.command,.shift]);item(file,"Reopen Closed Tab",#selector(reopen),"t",[.command,.shift]);file.addItem(.separator());item(file,"Close Tab",#selector(closeTab),"w");item(file,"Save Trail…",#selector(saveTrail),"s",[.command,.shift]);item(file,"Print…",#selector(printPage),"p")
        let edit=menu("Edit");for (title,selector,key) in [("Undo","undo:","z"),("Redo","redo:","Z"),("Cut","cut:","x"),("Copy","copy:","c"),("Paste","paste:","v"),("Select All","selectAll:","a")]{edit.addItem(NSMenuItem(title:title,action:NSSelectorFromString(selector),keyEquivalent:key))};edit.addItem(.separator());item(edit,"Find…",#selector(find),"f")
        let view=menu("View");item(view,"Open Address",#selector(address),"l");item(view,"Find Tab",#selector(palette),"k");item(view,"Reload",#selector(reload),"r");view.addItem(.separator());item(view,"Focus Trail",#selector(focus),"f",[.command,.shift]);item(view,"Keep Reference Pane",#selector(reference),"r",[.command,.shift]);view.addItem(.separator());item(view,"Zoom In",#selector(zoomIn),"+");item(view,"Zoom Out",#selector(zoomOut),"-");item(view,"Actual Size",#selector(zoomReset),"0")
        let history=menu("History");item(history,"Show History",#selector(historyPanel),"y");item(history,"Saved Trails",#selector(trails));item(history,"Back",#selector(back),"[");item(history,"Forward",#selector(forward),"]")
        let window=menu("Window");window.addItem(NSMenuItem(title:"Minimize",action:#selector(NSWindow.performMiniaturize(_:)),keyEquivalent:"m"));window.addItem(NSMenuItem(title:"Zoom",action:#selector(NSWindow.performZoom(_:)),keyEquivalent:""));NSApp.windowsMenu=window
        let help=menu("Help");item(help,"Lookout Source & Help",#selector(helpSource))
    }
    @objc func about(){NSApp.orderFrontStandardAboutPanel(options:[.applicationName:"Cohnsoft Lookout",.applicationVersion:"0.1.1",.credits:NSAttributedString(string:"Cohnsoft\nDemetria Althea Cohn\nNative WebKit browsing. Original app source under GPL-3.0-only.")])}
    @objc func settings(){active?.panel="settings"}
    @objc func newTab(){_=active?.newTab();active?.addressFocus=true}
    @objc func regular(){newWindow()}
    @objc func privateWindow(){newWindow(privateMode:true)}
    @objc func reopen(){active?.reopen()}
    @objc func closeTab(){if let active{active.close(active.current.id)}}
    @objc func saveTrail(){active?.saveTrail()}
    @objc func printPage(){guard let view=active?.current.webView else{return};view.printOperation(with:NSPrintInfo.shared).run()}
    @objc func find(){active?.find()}
    @objc func address(){active?.addressFocus=false;DispatchQueue.main.async{self.active?.addressFocus=true}}
    @objc func palette(){active?.panel="tabs"}
    @objc func reload(){active?.current.webView?.reload()}
    @objc func focus(){active?.focusTrail.toggle()}
    @objc func reference(){active?.toggleReference()}
    @objc func zoomIn(){if let view=active?.current.webView{view.pageZoom=min(3,view.pageZoom+0.1)}}
    @objc func zoomOut(){if let view=active?.current.webView{view.pageZoom=max(0.5,view.pageZoom-0.1)}}
    @objc func zoomReset(){active?.current.webView?.pageZoom=1}
    @objc func historyPanel(){active?.panel="history"}
    @objc func trails(){active?.panel="trails"}
    @objc func back(){active?.current.webView?.goBack()}
    @objc func forward(){active?.current.webView?.goForward()}
    @objc func helpSource(){NSWorkspace.shared.open(URL(string:"https://github.com/danecohn/lookout")!)}
}
@main enum LookoutMain {
    @MainActor static func main(){for name in ["CohnSans-Regular","CohnSans-Bold"] { if let url=Bundle.main.url(forResource:name,withExtension:"ttf") { CTFontManagerRegisterFontsForURL(url as CFURL,.process,nil) } };let app=NSApplication.shared;app.setActivationPolicy(.regular);let delegate=AppController();app.delegate=delegate;withExtendedLifetime(delegate){app.run()}}
}
