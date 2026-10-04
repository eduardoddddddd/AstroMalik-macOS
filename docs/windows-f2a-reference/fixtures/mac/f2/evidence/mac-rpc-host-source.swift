// Reference-only stdio adapter. All calculations delegate to the unmodified F3 facade.
import Foundation
import AstroMalik
private struct Request: Decodable { let id: EngineJSON?; let method: String; let params: EngineJSON? }
@main private struct MacReferenceRPC {
    static func emit(_ value: EngineJSON) throws {
        let encoder=JSONEncoder();encoder.outputFormatting=[.sortedKeys,.withoutEscapingSlashes]
        var data=try encoder.encode(value);data.append(0x0A);FileHandle.standardOutput.write(data)
    }
    static func main() async {
        do {
            var args=Array(CommandLine.arguments.dropFirst());var directory:String?;var commit:String?="a0e2369a224b6dcf98c6349cc5bc601d8e0a40a8";var moshier=false
            while !args.isEmpty {
                let key=args.removeFirst()
                switch key {
                case "--data-dir": guard !args.isEmpty else { throw EngineRPCError("USAGE","Missing data directory") };directory=args.removeFirst()
                case "--mac-commit": guard !args.isEmpty else { throw EngineRPCError("USAGE","Missing commit") };commit=args.removeFirst()
                case "--moshier":moshier=true
                default:throw EngineRPCError("USAGE","Unknown argument")
                }
            }
            guard let directory, directory.hasPrefix("/"), let commit else { throw EngineRPCError("USAGE","Explicit absolute --data-dir and --mac-commit are required") }
            let service=try EngineRPCService(dataDirectory:directory,macCommit:commit,moshier:moshier)
            while let line=readLine() {
                if line.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty { continue }
                var id:EngineJSON = .null
                do {
                    let request=try JSONDecoder().decode(Request.self,from:Data(line.utf8));id=request.id ?? .null
                    let requestID=id
                    let result=try await service.invoke(method:request.method,params:request.params ?? .object([:]),progress:{ value,message in
                        try? emit(.object(["id":requestID,"progress":.object(["fraction":.number(value),"message":.string(message)])]))
                    })
                    try emit(.object(["id":id,"result":result]))
                } catch {
                    let rpc=error as? EngineRPCError
                    try emit(.object(["id":id,"error":.object(["code":.string(rpc?.code ?? "INVALID_REQUEST"),"message":.string(error.localizedDescription)])]))
                }
            }
        } catch {
            FileHandle.standardError.write(Data(("MacReferenceRPC: "+error.localizedDescription+"\n").utf8));exit(1)
        }
    }
}
