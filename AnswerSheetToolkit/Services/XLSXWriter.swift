import Foundation

/// Generates `.xlsx` workbooks from answer sheets using the Office Open XML
/// (SpreadsheetML) format packaged via ``ZipArchive``. No third-party dependencies.
enum XLSXWriter {
    /// One worksheet's worth of data.
    struct Worksheet {
        let name: String
        /// Rows of cells already in export form: `[num, answer, num, answer, ...]`.
        let rows: [[String]]
    }

    /// Builds worksheets (with sanitized, unique names) for the given sheets.
    static func worksheets(for sheets: [AnswerSheet]) -> [Worksheet] {
        let names = ExportService.uniqueWorksheetNames(for: sheets.map(\.title))
        return zip(sheets, names).map { sheet, name in
            Worksheet(name: name, rows: ExportService.tableRows(for: sheet))
        }
    }

    /// Produces the full `.xlsx` file bytes for one or more worksheets.
    static func build(worksheets: [Worksheet]) -> Data {
        let sheets = worksheets.isEmpty
            ? [Worksheet(name: "Sheet", rows: [])]
            : worksheets

        var zip = ZipArchive()
        zip.addFile(path: "[Content_Types].xml", string: contentTypes(count: sheets.count))
        zip.addFile(path: "_rels/.rels", string: rootRels())
        zip.addFile(path: "xl/workbook.xml", string: workbookXML(sheets: sheets))
        zip.addFile(path: "xl/_rels/workbook.xml.rels", string: workbookRels(count: sheets.count))
        zip.addFile(path: "xl/styles.xml", string: stylesXML())
        for (index, sheet) in sheets.enumerated() {
            zip.addFile(path: "xl/worksheets/sheet\(index + 1).xml", string: worksheetXML(sheet))
        }
        return zip.build()
    }

    /// Convenience: build directly from answer sheets.
    static func build(sheets: [AnswerSheet]) -> Data {
        build(worksheets: worksheets(for: sheets))
    }

    // MARK: - XML parts

    private static func contentTypes(count: Int) -> String {
        var overrides = ""
        for i in 1...max(1, count) {
            overrides += "<Override PartName=\"/xl/worksheets/sheet\(i).xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/>"
        }
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">\
        <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>\
        <Default Extension="xml" ContentType="application/xml"/>\
        <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>\
        <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>\
        \(overrides)</Types>
        """
    }

    private static func rootRels() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>\
        </Relationships>
        """
    }

    private static func workbookXML(sheets: [Worksheet]) -> String {
        var sheetTags = ""
        for (index, sheet) in sheets.enumerated() {
            sheetTags += "<sheet name=\"\(escape(sheet.name))\" sheetId=\"\(index + 1)\" r:id=\"rId\(index + 1)\"/>"
        }
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">\
        <sheets>\(sheetTags)</sheets></workbook>
        """
    }

    private static func workbookRels(count: Int) -> String {
        var rels = ""
        for i in 1...max(1, count) {
            rels += "<Relationship Id=\"rId\(i)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet\(i).xml\"/>"
        }
        let stylesId = count + 1
        rels += "<Relationship Id=\"rId\(stylesId)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles\" Target=\"styles.xml\"/>"
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\(rels)</Relationships>
        """
    }

    /// Two cell formats: index 0 = default, index 1 = bold (used for question numbers).
    private static func stylesXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">\
        <fonts count="2"><font><sz val="11"/><name val="Calibri"/></font>\
        <font><b/><sz val="11"/><name val="Calibri"/></font></fonts>\
        <fills count="1"><fill><patternFill patternType="none"/></fill></fills>\
        <borders count="2"><border><left/><right/><top/><bottom/><diagonal/></border>\
        <border><left style="thin"/><right style="thin"/><top style="thin"/><bottom style="thin"/><diagonal/></border></borders>\
        <cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>\
        <cellXfs count="2">\
        <xf numFmtId="0" fontId="0" fillId="0" borderId="1" xfId="0" applyBorder="1"/>\
        <xf numFmtId="0" fontId="1" fillId="0" borderId="1" xfId="0" applyFont="1" applyBorder="1"/>\
        </cellXfs></styleSheet>
        """
    }

    private static func worksheetXML(_ sheet: Worksheet) -> String {
        var rowsXML = ""
        for (rowIndex, row) in sheet.rows.enumerated() {
            let rowNumber = rowIndex + 1
            var cellsXML = ""
            for (colIndex, value) in row.enumerated() {
                let ref = "\(columnLetter(colIndex))\(rowNumber)"
                // Even columns (0,2,4,...) are question numbers -> bold, numeric.
                let isQuestionNumber = colIndex % 2 == 0
                if isQuestionNumber, let intValue = Int(value) {
                    cellsXML += "<c r=\"\(ref)\" s=\"1\"><v>\(intValue)</v></c>"
                } else {
                    cellsXML += "<c r=\"\(ref)\" s=\"0\" t=\"inlineStr\"><is><t xml:space=\"preserve\">\(escape(value))</t></is></c>"
                }
            }
            rowsXML += "<row r=\"\(rowNumber)\">\(cellsXML)</row>"
        }
        let dimension = sheetDimension(sheet)
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">\
        <dimension ref="\(dimension)"/><sheetData>\(rowsXML)</sheetData></worksheet>
        """
    }

    private static func sheetDimension(_ sheet: Worksheet) -> String {
        let maxCols = sheet.rows.map(\.count).max() ?? 1
        let rows = max(1, sheet.rows.count)
        let lastCol = columnLetter(max(0, maxCols - 1))
        return "A1:\(lastCol)\(rows)"
    }

    /// 0-based column index to Excel column letters (A, B, ..., Z, AA, AB, ...).
    static func columnLetter(_ index: Int) -> String {
        var result = ""
        var n = index
        repeat {
            let remainder = n % 26
            result = String(UnicodeScalar(UInt8(65 + remainder))) + result
            n = n / 26 - 1
        } while n >= 0
        return result
    }

    private static func escape(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
