import Foundation

extension String {
    var htmlStripped: String {
        guard let data = data(using: .utf8) else { return self }
        if let attr = try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.html, .characterEncoding: String.Encoding.utf8.rawValue],
            documentAttributes: nil
        ) {
            return attr.string
        }
        return self
    }
}

enum XLSXError: LocalizedError {
    case emptyData
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .emptyData: return "没有可导出的数据"
        case .writeFailed: return "文件写入失败"
        }
    }
}

final class XLSXWriter {
    func write(html: String, to url: URL) throws {
        let rows = parseHTMLTable(html)

        guard !rows.isEmpty, rows.contains(where: { !$0.isEmpty }) else {
            throw XLSXError.emptyData
        }

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("xlsx_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("_rels"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("xl/_rels"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: tempDir.appendingPathComponent("xl/worksheets"), withIntermediateDirectories: true)

        var sharedStrings: [String] = []
        var stringIndexMap: [String: Int] = [:]

        for row in rows {
            for cell in row {
                if stringIndexMap[cell] == nil {
                    stringIndexMap[cell] = sharedStrings.count
                    sharedStrings.append(cell)
                }
            }
        }

        try writeContentTypes(to: tempDir)
        try writeRels(to: tempDir)
        try writeWorkbook(to: tempDir)
        try writeWorkbookRels(to: tempDir)
        try writeStyles(to: tempDir)
        try writeSharedStrings(sharedStrings, to: tempDir)
        try writeSheet1(rows: rows, stringIndexMap: stringIndexMap, to: tempDir)

        try zipDirectory(tempDir, to: url)
    }

    private func parseHTMLTable(_ html: String) -> [[String]] {
        var rows: [[String]] = []
        let scanner = Scanner(string: html)
        scanner.charactersToBeSkipped = nil

        while !scanner.isAtEnd {
            guard scanner.scanUpToString("<tr") != nil else { break }
            if scanner.scanString("<tr") == nil { break }
            _ = scanner.scanUpToString(">")
            _ = scanner.scanString(">")

            var cells: [String] = []

            while !scanner.isAtEnd {
                if scanner.scanUpToString("<td") != nil {
                    if scanner.scanString("<td") != nil {
                        _ = scanner.scanUpToString(">")
                        _ = scanner.scanString(">")
                        if let val = scanner.scanUpToString("</td>") {
                            cells.append(val.htmlStripped.trimmingCharacters(in: .whitespacesAndNewlines))
                        }
                        _ = scanner.scanString("</td>")
                        continue
                    }
                }
                if scanner.scanUpToString("<th") != nil {
                    if scanner.scanString("<th") != nil {
                        _ = scanner.scanUpToString(">")
                        _ = scanner.scanString(">")
                        if let val = scanner.scanUpToString("</th>") {
                            cells.append(val.htmlStripped.trimmingCharacters(in: .whitespacesAndNewlines))
                        }
                        _ = scanner.scanString("</th>")
                        continue
                    }
                }
                break
            }

            if scanner.scanString("</tr>") == nil {
                _ = scanner.scanUpToString("</tr>")
                _ = scanner.scanString("</tr>")
            }

            if !cells.isEmpty {
                rows.append(cells)
            }
        }

        return rows
    }

    private func zipDirectory(_ dir: URL, to outputURL: URL) throws {
        let tempZip = dir.appendingPathComponent("output.zip")
        var dittoArgs = ["-c", "-k", "--keepParent"]
        let children = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        for child in children where child.lastPathComponent != "output.zip" {
            dittoArgs.append(child.lastPathComponent)
        }
        dittoArgs.append(tempZip.path)

        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        p.arguments = dittoArgs
        p.currentDirectoryURL = dir
        try p.run()
        p.waitUntilExit()
        guard p.terminationStatus == 0 else { throw XLSXError.writeFailed }
        try FileManager.default.copyItem(at: tempZip, to: outputURL)
    }

    private func writeContentTypes(to dir: URL) throws {
        let xml = #"""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
          <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
          <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
          <Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>
        </Types>
        """#
        try xml.write(to: dir.appendingPathComponent("[Content_Types].xml"), atomically: true, encoding: .utf8)
    }

    private func writeRels(to dir: URL) throws {
        let xml = #"""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
        </Relationships>
        """#
        try xml.write(to: dir.appendingPathComponent("_rels/.rels"), atomically: true, encoding: .utf8)
    }

    private func writeWorkbook(to dir: URL) throws {
        let xml = #"""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
          <sheets>
            <sheet name="Sheet1" sheetId="1" r:id="rId1"/>
          </sheets>
        </workbook>
        """#
        try xml.write(to: dir.appendingPathComponent("xl/workbook.xml"), atomically: true, encoding: .utf8)
    }

    private func writeWorkbookRels(to dir: URL) throws {
        let xml = #"""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
          <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
          <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings" Target="sharedStrings.xml"/>
        </Relationships>
        """#
        try xml.write(to: dir.appendingPathComponent("xl/_rels/workbook.xml.rels"), atomically: true, encoding: .utf8)
    }

    private func writeStyles(to dir: URL) throws {
        let xml = #"""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
          <fonts count="1"><font><sz val="11"/><name val="Calibri"/></font></fonts>
          <fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills>
          <borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>
          <cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
          <cellXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/></cellXfs>
        </styleSheet>
        """#
        try xml.write(to: dir.appendingPathComponent("xl/styles.xml"), atomically: true, encoding: .utf8)
    }

    private func writeSharedStrings(_ strings: [String], to dir: URL) throws {
        let items = strings.map { "<si><t>\(xmlEscape($0))</t></si>" }.joined()
        let xml = #"""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="\#(strings.count)" uniqueCount="\#(strings.count)">\#(items)</sst>
        """#
        try xml.write(to: dir.appendingPathComponent("xl/sharedStrings.xml"), atomically: true, encoding: .utf8)
    }

    private func writeSheet1(rows: [[String]], stringIndexMap: [String: Int], to dir: URL) throws {
        let maxCol = rows.map(\.count).max() ?? 0
        var colsXml = ""
        for i in 0..<maxCol {
            colsXml += "<col min=\"\(i+1)\" max=\"\(i+1)\" width=\"18\" customWidth=\"1\"/>"
        }

        var rowsXml = ""
        for (ri, row) in rows.enumerated() {
            var cellsXml = ""
            for (ci, cell) in row.enumerated() {
                let ref = "\(colIndexToLetter(ci))\(ri + 1)"
                let idx = stringIndexMap[cell] ?? 0
                cellsXml += "<c r=\"\(ref)\" t=\"s\"><v>\(idx)</v></c>"
            }
            rowsXml += "<row r=\"\(ri + 1)\">\(cellsXml)</row>"
        }

        let xml = #"""
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
          <cols>\#(colsXml)</cols>
          <sheetData>\#(rowsXml)</sheetData>
        </worksheet>
        """#
        try xml.write(to: dir.appendingPathComponent("xl/worksheets/sheet1.xml"), atomically: true, encoding: .utf8)
    }

    private func colIndexToLetter(_ index: Int) -> String {
        var n = index
        var result = ""
        repeat {
            let rem = n % 26
            result = String(UnicodeScalar(65 + rem)!) + result
            n = n / 26 - 1
        } while n >= 0
        return result
    }

    private func xmlEscape(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
