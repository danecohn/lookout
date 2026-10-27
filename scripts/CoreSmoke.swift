import Foundation
@main enum CoreSmoke {
static func main()throws{
 var checks=0
 func check(_ ok:Bool,_ name:String){guard ok else{fatalError(name)};checks+=1}
 check(try AddressResolver.resolve("example.com")?.scheme=="https","HTTPS default")
 check(try AddressResolver.resolve("localhost:4397")?.scheme=="http","loopback")
 for unsafe in ["javascript:alert(1)","data:text/html,x","file:///etc/passwd"]{do{_=try AddressResolver.resolve(unsafe);fatalError("unsafe URL accepted")}catch{checks+=1}}
 check(AddressResolver.persisted(URL(string:"https://a.test/?token=secret"))==nil,"token persistence")
 check(SearchProvider.artemisearch.search("a & b").host=="www.amerika.social","Cohnsoft Search default route")
 check(try JSONDecoder().decode(SearchProvider.self,from:Data("\"artemisearch\"".utf8)) == .artemisearch,"legacy engine preference decoding")
 check(SearchProvider.artemisearch.label=="Cohnsoft Search","current search display name")
 check(SearchProvider.kagi.search("test").host=="kagi.com","Kagi choice")
 var archive=Archive(windows:[.fresh()]);archive.addVisit(URL(string:"https://a.test")!,title:"Secret",privateMode:true);check(archive.history.isEmpty,"private history")
 let space=archive.windows[0].activeSpaceID;let root=TabRecord(spaceID:space,address:"https://a.test");let child=TabRecord(spaceID:space,parentID:root.id);check(TrailGraph.branch(selected:child.id,tabs:[root,child]).count==2,"connected trail")
 let trail=TrailRecord(name:"Test",purpose:"Compare",tabs:[root]);check(trail.markdown.contains("Compare") && trail.pages.count==1,"Markdown trail")
 let fileURL=FileManager.default.temporaryDirectory.appendingPathComponent("lookout-test-"+UUID().uuidString);defer{try? FileManager.default.removeItem(at:fileURL)};let file=SessionFile(url:fileURL);try file.save(archive);check(try file.load().windows.count==1,"restore")
 let broken=Data("broken".utf8);try broken.write(to:fileURL);do{_=try file.load();fatalError("corrupt session accepted")}catch{check(try Data(contentsOf:fileURL)==broken,"corrupt preserved")}
 print("LOOKOUT_CORE_SMOKE_PASS: \(checks) checks")
}
}
