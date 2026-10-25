import AppKit
import WebKit
import LookoutCore

@MainActor enum SelfTest {
    static func run() async {
        // Owned loopback fixture only; no user's persisted website data is opened.
        setbuf(stdout,nil)
        NSApp.activate(ignoringOtherApps:true)
        let data=WKWebsiteDataStore.nonPersistent();let config=WKWebViewConfiguration();config.websiteDataStore=data
        let view=WKWebView(frame:NSRect(x:0,y:0,width:900,height:650),configuration:config)
        let window=NSWindow(contentRect:view.frame,styleMask:[.titled],backing:.buffered,defer:false);window.contentView=view;window.makeKeyAndOrderFront(nil)
        do {
            let args=CommandLine.arguments;guard let index=args.firstIndex(of:"--fixture-origin"),index+1<args.count,let origin=URL(string:args[index+1]),["localhost","127.0.0.1"].contains(origin.host ?? "") else{throw TestError.failed("Pass --fixture-origin loopback URL")}
            view.load(URLRequest(url:origin.appendingPathComponent("a")))
            print("SELFTEST stage A");try await until{view.title=="Lookout Fixture A" && !view.isLoading}
            _=try await view.evaluateJavaScript("document.cookie='lookout_fixture=one; path=/'; document.title")
            print("SELFTEST stage B");view.load(URLRequest(url:origin.appendingPathComponent("b")));try await until{view.title=="Lookout Fixture B" && !view.isLoading}
            guard view.canGoBack else{throw TestError.failed("Back history missing")};view.goBack();try await until{view.title=="Lookout Fixture A" && !view.isLoading}
            let cookie=try await view.evaluateJavaScript("document.cookie") as? String ?? "";guard cookie.contains("lookout_fixture=one") else{throw TestError.failed("Cookie missing")}
            print("SELFTEST private");let privateConfig=WKWebViewConfiguration();privateConfig.websiteDataStore = .nonPersistent();let other=WKWebView(frame:view.frame,configuration:privateConfig);window.contentView=other;other.load(URLRequest(url:origin.appendingPathComponent("a")));try await until{other.title=="Lookout Fixture A" && !other.isLoading};let isolated=try await other.evaluateJavaScript("document.cookie") as? String ?? "";guard isolated.isEmpty else{throw TestError.failed("Private cookie isolation failed")}
            window.contentView=view;print("SELFTEST find");let found=await withCheckedContinuation{continuation in view.find("Lighthouse",configuration:WKFindConfiguration()){continuation.resume(returning:$0.matchFound)}};guard found else{throw TestError.failed("Find failed")}
            print("LOOKOUT_SELF_TEST_PASS: WebKit navigation, back/forward, cookie persistence, private-store isolation, page find")
            window.close();NSApp.terminate(nil)
        }catch{fputs("LOOKOUT_SELF_TEST_FAIL: \(error)\n",stderr);exit(1)}
    }
    enum TestError:Error{case failed(String)}
    static func until(file:StaticString=#fileID,line:UInt=#line,_ condition:()->Bool)async throws{for _ in 0..<400{if condition(){return};try await Task.sleep(nanoseconds:100_000_000)};throw TestError.failed("WebKit timed out at \(file):\(line)")}
}
