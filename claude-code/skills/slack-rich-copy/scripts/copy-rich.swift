import AppKit
import Foundation

// Usage:
//   swift copy-rich.swift <html_file> [plain_file]
// If plain_file omitted, derives plain text from HTML.

let args = CommandLine.arguments
guard args.count >= 2 else {
    FileHandle.standardError.write("usage: copy-rich.swift <html_file> [plain_file]\n".data(using: .utf8)!)
    exit(2)
}

let htmlPath = args[1]
let html: String
do {
    html = try String(contentsOfFile: htmlPath, encoding: .utf8)
} catch {
    FileHandle.standardError.write("failed to read HTML: \(error)\n".data(using: .utf8)!)
    exit(1)
}

guard let htmlData = html.data(using: .utf8) else {
    FileHandle.standardError.write("HTML utf8 conversion failed\n".data(using: .utf8)!)
    exit(1)
}

let attr: NSAttributedString
do {
    attr = try NSAttributedString(
        data: htmlData,
        options: [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue,
        ],
        documentAttributes: nil
    )
} catch {
    FileHandle.standardError.write("HTML parse failed: \(error)\n".data(using: .utf8)!)
    exit(1)
}

let rtf = try attr.data(
    from: NSRange(location: 0, length: attr.length),
    documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
)

let plain: String
if args.count >= 3 {
    plain = (try? String(contentsOfFile: args[2], encoding: .utf8)) ?? attr.string
} else {
    plain = attr.string
}

let pb = NSPasteboard.general
pb.clearContents()
pb.setData(htmlData, forType: .html)
pb.setData(rtf, forType: .rtf)
pb.setString(plain, forType: .string)
print("OK html=\(htmlData.count)B rtf=\(rtf.count)B plain=\(plain.count)chars")
