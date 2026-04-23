import SwiftUI
import UniformTypeIdentifiers
import CoreText
import Compression

struct FontEntry: Identifiable {
    let id = UUID()
    let ctFont: CTFont
    let name: String
    let details: [FontDetail]
    let url: URL
    let missingCodePoints: Set<UInt32>
    let wrongRotationCodePoints: Set<UInt32>
}

struct ContentView: View {
    @State private var sampleText: String = "「狐狸教授抱著《標點保命大全》衝進教室，大叫：『同學們注意！今天要考【黑括號】、〖白括號〗、（圓括號）、〔龜甲括號〕、「單引號」、『雙引號』，還有！？：；，。……——誰要是寫錯，就去給那隻懶貓朗讀〈排版反省錄〉！』懶貓趴在桌上動也不動，過了好一會兒才抬頭說：『老師……我不是不想學，我只是看到破折號——就想睡。』」"
    @State private var fontEntries: [FontEntry] = []
    @State private var selectedEntryID: UUID?
    @State private var isTargeted: Bool = false
    @State private var fontSize: CGFloat = 48
    @State private var isEditingSample: Bool = false
    @State private var readingText: String? = nil  // nil = comparison mode, non-nil = reading mode
    @State private var dropTargetEntryID: UUID? = nil  // which column is being hovered with a book
    @State private var pageInfo: String = ""

    private var selectedEntry: FontEntry? {
        fontEntries.first { $0.id == selectedEntryID }
    }

    var body: some View {
        if let text = readingText {
            // Reading mode: full window, single font, paginated
            VStack(spacing: 0) {
                HStack {
                    Button(action: { readingText = nil }) {
                        Label("Back", systemImage: "chevron.left")
                    }
                    .buttonStyle(.bordered)
                    Text(selectedEntry?.name ?? "System Default")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(pageInfo)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 6)

                VerticalTextView(text: text, font: selectedEntry?.ctFont, missingCodePoints: selectedEntry?.missingCodePoints ?? [], wrongRotationCodePoints: selectedEntry?.wrongRotationCodePoints ?? [], fontSize: $fontSize, isPaginated: true, onPageInfo: { current, total in
                    DispatchQueue.main.async {
                        pageInfo = "\(current) / \(total)"
                    }
                })
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color(nsColor: .controlBackgroundColor))
        } else {
        VStack(spacing: 0) {
            // Sample text editor
            if isEditingSample {
                HStack {
                    TextEditor(text: $sampleText)
                        .font(.system(size: 14))
                        .frame(height: 80)
                        .border(Color.accentColor, width: 1)
                    Button("Done") {
                        isEditingSample = false
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
            }

            // Top: Vertical text display (side by side)
            HStack(spacing: 0) {
                if fontEntries.isEmpty {
                    VerticalTextView(text: sampleText, font: nil, missingCodePoints: [], wrongRotationCodePoints: [], fontSize: $fontSize)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ForEach(fontEntries) { entry in
                        VStack(spacing: 0) {
                            Text(entry.name)
                                .font(.caption)
                                .foregroundColor(selectedEntryID == entry.id ? .accentColor : .secondary)
                                .lineLimit(1)
                                .padding(.top, 4)
                                .padding(.horizontal, 4)

                            VerticalTextView(text: sampleText, font: entry.ctFont, missingCodePoints: entry.missingCodePoints, wrongRotationCodePoints: entry.wrongRotationCodePoints, fontSize: $fontSize)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(
                                    dropTargetEntryID == entry.id ? Color.accentColor.opacity(0.15) :
                                    selectedEntryID == entry.id ? Color.accentColor.opacity(0.05) : Color.clear
                                )
                                .onTapGesture {
                                    selectedEntryID = entry.id
                                }
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 0)
                                .stroke(dropTargetEntryID == entry.id ? Color.accentColor : Color.clear, lineWidth: 3)
                        )
                        .onDrop(of: [.fileURL], isTargeted: Binding(
                            get: { dropTargetEntryID == entry.id },
                            set: { val in dropTargetEntryID = val ? entry.id : nil }
                        )) { providers in
                            handleColumnDrop(providers: providers, entryID: entry.id)
                        }
                        .contextMenu {
                            Button("Remove \(entry.name)") {
                                removeFont(entry.id)
                            }
                        }
                        if entry.id != fontEntries.last?.id {
                            Divider()
                        }
                    }
                }
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 0)
                    .stroke(isTargeted ? Color.accentColor : Color.clear, lineWidth: 3)
            )
            .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
                handleDrop(providers: providers)
            }

            Divider()

            // Bottom: Font details
            VStack(spacing: 0) {
                // Toolbar
                HStack {
                    Text("Font: \(selectedEntry?.name ?? "System Default")")
                        .font(.headline)
                    Spacer()

                    if let selected = selectedEntry {
                        Button(action: { removeFont(selected.id) }) {
                            Label("Remove", systemImage: "minus")
                        }
                        .buttonStyle(.bordered)
                    }

                    Button(action: { isEditingSample.toggle() }) {
                        Label("Edit Text", systemImage: "pencil")
                    }
                    .buttonStyle(.bordered)

                    Text("Drag font files here")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                if let entry = selectedEntry {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(entry.details) { detail in
                                HStack(alignment: .top) {
                                    Text(detail.key)
                                        .fontWeight(.medium)
                                        .frame(width: 140, alignment: .trailing)
                                        .foregroundColor(detail.isWarning ? .red : .secondary)
                                    Text(detail.value)
                                        .textSelection(.enabled)
                                        .foregroundColor(detail.isWarning ? .red : .primary)
                                }
                                .font(.system(.body, design: .monospaced))
                                Divider()
                            }
                        }
                        .padding(.horizontal)
                    }
                } else {
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "textformat")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            Text("Drop font files to compare")
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 380)
            .background(Color(nsColor: .windowBackgroundColor))
            .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
                handleDrop(providers: providers)
            }
        }
        } // end else (comparison mode)
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url = url else {
                    print("[DROP] URL is nil")
                    return
                }
                let ext = url.pathExtension.lowercased()
                print("[DROP] File: \(url.lastPathComponent), ext: \(ext)")
                if ["ttf", "otf", "ttc", "dfont"].contains(ext) {
                    DispatchQueue.main.async {
                        loadFont(from: url)
                    }
                } else if ext == "epub" {
                    DispatchQueue.global(qos: .userInitiated).async {
                        print("[EPUB] Starting extraction from: \(url.path)")
                        let text = extractTextFromEpub(url: url)
                        print("[EPUB] Extracted \(text.count) chars")
                        DispatchQueue.main.async {
                            if !text.isEmpty { readingText = text }
                        }
                    }
                } else if ext == "txt" {
                    DispatchQueue.global(qos: .userInitiated).async {
                        if let text = try? String(contentsOf: url, encoding: .utf8), !text.isEmpty {
                            DispatchQueue.main.async {
                                readingText = text
                            }
                        }
                    }
                }
            }
        }
        return true
    }

    private func handleColumnDrop(providers: [NSItemProvider], entryID: UUID) -> Bool {
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url = url else { return }
                let ext = url.pathExtension.lowercased()
                if ["ttf", "otf", "ttc", "dfont"].contains(ext) {
                    DispatchQueue.main.async {
                        loadFont(from: url)
                    }
                } else if ext == "epub" {
                    DispatchQueue.global(qos: .userInitiated).async {
                        let text = extractTextFromEpub(url: url)
                        DispatchQueue.main.async {
                            if !text.isEmpty {
                                selectedEntryID = entryID
                                readingText = text
                            }
                        }
                    }
                } else if ext == "txt" {
                    DispatchQueue.global(qos: .userInitiated).async {
                        if let text = try? String(contentsOf: url, encoding: .utf8), !text.isEmpty {
                            DispatchQueue.main.async {
                                selectedEntryID = entryID
                                readingText = text
                            }
                        }
                    }
                }
            }
        }
        return true
    }

    private func loadFont(from url: URL) {
        guard let fontDescriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor],
              let descriptor = fontDescriptors.first else {
            return
        }

        let ctFont = CTFontCreateWithFontDescriptor(descriptor, 48, nil)
        let name = CTFontCopyFullName(ctFont) as String
        let (details, missingCPs, wrongRotCPs) = extractFontDetails(from: ctFont, url: url)
        let entry = FontEntry(ctFont: ctFont, name: name, details: details, url: url, missingCodePoints: missingCPs, wrongRotationCodePoints: wrongRotCPs)
        fontEntries.append(entry)
        selectedEntryID = entry.id
    }

    private func removeFont(_ id: UUID) {
        fontEntries.removeAll { $0.id == id }
        if selectedEntryID == id {
            selectedEntryID = fontEntries.last?.id
        }
    }

    private func extractFontDetails(from font: CTFont, url: URL) -> ([FontDetail], Set<UInt32>, Set<UInt32>) {
        var details: [FontDetail] = []
        var missingCodePoints: Set<UInt32> = []
        var wrongRotationCodePoints: Set<UInt32> = []

        details.append(FontDetail(key: "Full Name", value: CTFontCopyFullName(font) as String))
        details.append(FontDetail(key: "Family", value: CTFontCopyFamilyName(font) as String))

        // Chinese localized names (parse font name table directly)
        let chineseNames = extractChineseNames(from: font)
        if let chFullName = chineseNames.fullName {
            details.append(FontDetail(key: "Chinese Name", value: chFullName))
        }
        if let chFamily = chineseNames.family {
            details.append(FontDetail(key: "Chinese Family", value: chFamily))
        }

        details.append(FontDetail(key: "PostScript Name", value: CTFontCopyPostScriptName(font) as String))

        if let displayName = CTFontCopyName(font, kCTFontStyleNameKey) {
            details.append(FontDetail(key: "Style", value: displayName as String))
        }

        let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        details.append(FontDetail(key: "File Size", value: ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)))
        details.append(FontDetail(key: "File Path", value: url.path))

        let glyphCount = CTFontGetGlyphCount(font)
        details.append(FontDetail(key: "Glyph Count", value: "\(glyphCount)"))

        let ascent = CTFontGetAscent(font)
        let descent = CTFontGetDescent(font)
        details.append(FontDetail(key: "Ascent / Descent", value: String(format: "%.1f / %.1f", ascent, descent)))

        // === Check vertical punctuation support ===

        // 1. Check regular CJK punctuation glyphs
        let regularPunctuation: [(String, UInt32)] = [
            ("，", 0xFF0C), ("。", 0x3002), ("、", 0x3001),
            ("：", 0xFF1A), ("；", 0xFF1B), ("？", 0xFF1F), ("！", 0xFF01),
            ("「", 0x300C), ("」", 0x300D), ("『", 0x300E), ("』", 0x300F),
            ("（", 0xFF08), ("）", 0xFF09), ("【", 0x3010), ("】", 0x3011),
            ("《", 0x300A), ("》", 0x300B), ("〈", 0x3008), ("〉", 0x3009),
            ("〔", 0x3014), ("〕", 0x3015), ("〖", 0x3016), ("〗", 0x3017),
            ("—", 0x2014), ("…", 0x2026),
        ]

        var regularPresent: [String] = []
        var regularMissing: [String] = []
        for (label, cp) in regularPunctuation {
            var glyph: CGGlyph = 0
            var unichar = UniChar(cp)
            let found = CTFontGetGlyphsForCharacters(font, &unichar, &glyph, 1)
            if found && glyph != 0 {
                regularPresent.append(label)
            } else {
                regularMissing.append(label)
                missingCodePoints.insert(cp)
            }
        }

        details.append(FontDetail(
            key: "CJK Punctuation",
            value: regularMissing.isEmpty
                ? "✓ All \(regularPunctuation.count) present"
                : "△ \(regularPresent.count)/\(regularPunctuation.count), missing: \(regularMissing.joined(separator: " "))",
            isWarning: !regularMissing.isEmpty
        ))

        // 2. Check vertical presentation form glyphs (U+FE10–FE19, U+FE30–FE44)
        let verticalForms: [(String, String, UInt32)] = [
            ("，", "︐", 0xFE10), ("。", "︒", 0xFE12), ("、", "︑", 0xFE11),
            ("：", "︓", 0xFE13), ("；", "︔", 0xFE14),
            ("？", "︖", 0xFE16), ("！", "︕", 0xFE15),
            ("「", "﹁", 0xFE41), ("」", "﹂", 0xFE42),
            ("『", "﹃", 0xFE43), ("』", "﹄", 0xFE44),
            ("（", "︵", 0xFE35), ("）", "︶", 0xFE36),
            ("【", "︻", 0xFE3B), ("】", "︼", 0xFE3C),
            ("《", "︽", 0xFE3D), ("》", "︾", 0xFE3E),
            ("〈", "︿", 0xFE3F), ("〉", "﹀", 0xFE40),
            ("—", "︱", 0xFE31), ("…", "︙", 0xFE19),
        ]

        var vfPresent = 0
        var vfMissing: [String] = []
        for (orig, _, cp) in verticalForms {
            var glyph: CGGlyph = 0
            var unichar = UniChar(cp)
            let found = CTFontGetGlyphsForCharacters(font, &unichar, &glyph, 1)
            if found && glyph != 0 {
                vfPresent += 1
            } else {
                vfMissing.append("\(orig)(U+\(String(format: "%04X", cp)))")
            }
        }

        // 3. Check rotation — compare glyphs between horizontal and vertical CTFrame.
        // Per CLREQ: brackets MUST rotate 90° CW in vertical; colons/semicolons must NOT rotate.
        // shouldRotate=true:  GSUB substitution = correct, no change = wrong
        // shouldRotate=false: GSUB substitution = WRONG (font wrongly rotates), no change = correct
        let rotationChecks: [(String, UInt32, UInt32, Bool)] = [
            // shouldRotate=false: these should NOT rotate in vertical mode
            ("：", 0xFF1A, 0xFE13, false), ("；", 0xFF1B, 0xFE14, false),
            // shouldRotate=true: these MUST rotate in vertical mode
            ("（", 0xFF08, 0xFE35, true), ("）", 0xFF09, 0xFE36, true),
            ("《", 0x300A, 0xFE3D, true), ("》", 0x300B, 0xFE3E, true),
            ("「", 0x300C, 0xFE41, true), ("」", 0x300D, 0xFE42, true),
            ("『", 0x300E, 0xFE43, true), ("』", 0x300F, 0xFE44, true),
            ("〈", 0x3008, 0xFE3F, true), ("〉", 0x3009, 0xFE40, true),
            ("【", 0x3010, 0xFE3B, true), ("】", 0x3011, 0xFE3C, true),
            ("〔", 0x3014, 0xFE39, true), ("〕", 0x3015, 0xFE3A, true),
            ("〖", 0x3016, 0xFE17, true), ("〗", 0x3017, 0xFE18, true),
            // Dashes and ellipsis: MUST rotate per CLREQ A.2
            ("—", 0x2014, 0xFE31, true),  // EM DASH → VERTICAL EM DASH
            ("…", 0x2026, 0xFE19, true),  // HORIZONTAL ELLIPSIS → VERTICAL ELLIPSIS
        ]

        let framePath = CGPath(rect: CGRect(x: 0, y: 0, width: 200, height: 200), transform: nil)
        let vertFrameAttrs: [CFString: Any] = [
            kCTFrameProgressionAttributeName: CTFrameProgression.rightToLeft.rawValue
        ]

        var wrongRotation: [String] = []
        for (label, baseCp, vertCp, shouldRotate) in rotationChecks {
            guard let scalar = Unicode.Scalar(baseCp) else { continue }
            let charStr = String(scalar)

            var baseUnichar = UniChar(baseCp)
            var cmapGlyph: CGGlyph = 0
            let found = CTFontGetGlyphsForCharacters(font, &baseUnichar, &cmapGlyph, 1)
            guard found && cmapGlyph != 0 else { continue }

            // Shape in horizontal CTFrame
            let horizAttrStr = NSAttributedString(string: charStr, attributes: [.font: font])
            let horizSetter = CTFramesetterCreateWithAttributedString(horizAttrStr)
            let horizFrame = CTFramesetterCreateFrame(horizSetter, CFRange(location: 0, length: 0), framePath, nil)
            let horizLines = CTFrameGetLines(horizFrame) as! [CTLine]
            guard let horizLine = horizLines.first else { continue }
            let horizRuns = CTLineGetGlyphRuns(horizLine) as! [CTRun]
            guard let horizRun = horizRuns.first, CTRunGetGlyphCount(horizRun) > 0 else { continue }
            var horizGlyph: CGGlyph = 0
            CTRunGetGlyphs(horizRun, CFRange(location: 0, length: 1), &horizGlyph)

            // Shape in vertical CTFrame
            let vertAttrStr = NSAttributedString(string: charStr, attributes: [
                .font: font,
                .verticalGlyphForm: true
            ])
            let vertSetter = CTFramesetterCreateWithAttributedString(vertAttrStr)
            let vertFrame = CTFramesetterCreateFrame(vertSetter, CFRange(location: 0, length: 0), framePath, vertFrameAttrs as CFDictionary)
            let vertLines = CTFrameGetLines(vertFrame) as! [CTLine]
            guard let vertLine = vertLines.first else { continue }
            let vertRuns = CTLineGetGlyphRuns(vertLine) as! [CTRun]
            guard let vertRun = vertRuns.first, CTRunGetGlyphCount(vertRun) > 0 else { continue }
            var vertGlyph: CGGlyph = 0
            CTRunGetGlyphs(vertRun, CFRange(location: 0, length: 1), &vertGlyph)

            let glyphChanged = horizGlyph != vertGlyph

            if shouldRotate {
                // Brackets: need rotation. GSUB change = correct, no change = check further.
                if glyphChanged { continue }

                // Glyphs are the same — check if base IS already the vertical form
                var vertUnichar = UniChar(vertCp)
                var vertFormGlyph: CGGlyph = 0
                let vertFormFound = CTFontGetGlyphsForCharacters(font, &vertUnichar, &vertFormGlyph, 1)
                if vertFormFound && vertFormGlyph != 0 && vertFormGlyph == horizGlyph {
                    continue // Base glyph is already the vertical form (e.g., I.MingCP)
                }

                // No vertical support — wrong
                wrongRotation.append(label)
                wrongRotationCodePoints.insert(baseCp)
            } else {
                // Colons/semicolons: must NOT rotate in vertical mode.
                // Check 1: CTFrame glyph changed → GSUB actively rotates → wrong
                if glyphChanged {
                    wrongRotation.append(label)
                    wrongRotationCodePoints.insert(baseCp)
                } else {
                    // Glyphs same — check SAME_GLYPH pattern: base IS the vertical form
                    var vertUnichar = UniChar(vertCp)
                    var vertFormGlyph: CGGlyph = 0
                    let vertFormFound = CTFontGetGlyphsForCharacters(font, &vertUnichar, &vertFormGlyph, 1)
                    if vertFormFound && vertFormGlyph != 0 && vertFormGlyph == horizGlyph {
                        // Base glyph IS the vertical form (e.g., H-ShinYaLan) → wrong
                        wrongRotation.append(label)
                        wrongRotationCodePoints.insert(baseCp)
                    }
                }
            }
        }

        // 4. Check for OpenType 'vert' GSUB feature
        let hasVertFeature = CTFontCopyTable(font, CTFontTableTag(0x47535542), []) != nil // 'GSUB'

        let vfTotal = verticalForms.count
        let hasRotationIssue = !wrongRotation.isEmpty

        // Report vertical forms status
        if vfPresent == 0 {
            if hasVertFeature {
                // Case: No dedicated vertical forms, but has GSUB (vert feature likely)
                details.append(FontDetail(
                    key: "Vertical Forms",
                    value: "○ No dedicated forms (0/\(vfTotal)), but has GSUB table (may use 'vert' feature)"
                ))
            } else {
                // Case 3: No vertical forms at all
                details.append(FontDetail(
                    key: "Vertical Forms",
                    value: "✗ No vertical forms (0/\(vfTotal)), no GSUB table",
                    isWarning: true
                ))
            }
        } else if vfPresent < vfTotal && hasRotationIssue {
            // Case 5: Partial set and not rotated
            details.append(FontDetail(
                key: "Vertical Forms",
                value: "✗ Incomplete \(vfPresent)/\(vfTotal) & rotation wrong: \(wrongRotation.joined(separator: " ")); missing: \(vfMissing.joined(separator: " "))",
                isWarning: true
            ))
        } else if vfPresent < vfTotal {
            // Case 4: Partial set, rotation OK
            details.append(FontDetail(
                key: "Vertical Forms",
                value: "△ Incomplete: \(vfPresent)/\(vfTotal), missing: \(vfMissing.joined(separator: " "))",
                isWarning: true
            ))
        } else if hasRotationIssue {
            // Case 2: Full set, rotation wrong
            details.append(FontDetail(
                key: "Vertical Forms",
                value: "⚠ All \(vfTotal) present, but rotation wrong: \(wrongRotation.joined(separator: " "))",
                isWarning: true
            ))
        } else {
            // Case 1: Full set, rotation correct
            details.append(FontDetail(
                key: "Vertical Forms",
                value: "✓ All \(vfTotal) vertical forms present, rotation correct"
            ))
        }

        return (details, missingCodePoints, wrongRotationCodePoints)
    }
}

struct FontDetail: Identifiable {
    let id = UUID()
    let key: String
    let value: String
    var isWarning: Bool = false
}

// Parse the font 'name' table to find Chinese-language name entries
private func extractChineseNames(from font: CTFont) -> (fullName: String?, family: String?) {
    guard let tableData = CTFontCopyTable(font, CTFontTableTag(kCTFontTableName), []) as? Data else {
        return (nil, nil)
    }

    let data = tableData

    guard data.count >= 6 else { return (nil, nil) }

    let count = Int(data[2]) << 8 | Int(data[3])
    let storageOffset = Int(data[4]) << 8 | Int(data[5])

    // Chinese language IDs
    // Platform 3 (Windows): 0x0804 = zh-CN, 0x0404 = zh-TW, 0x0C04 = zh-HK
    let windowsChineseLangs: Set<Int> = [0x0804, 0x0404, 0x0C04, 0x1404, 0x1004]
    // Platform 1 (Mac): 33 = zh-Hans, 19 = zh-Hant
    let macChineseLangs: Set<Int> = [33, 19]

    var fullName: String?
    var family: String?

    for i in 0..<count {
        let recordOffset = 6 + i * 12
        guard recordOffset + 12 <= data.count else { break }

        let platformID = Int(data[recordOffset]) << 8 | Int(data[recordOffset + 1])
        let encodingID = Int(data[recordOffset + 2]) << 8 | Int(data[recordOffset + 3])
        let languageID = Int(data[recordOffset + 4]) << 8 | Int(data[recordOffset + 5])
        let nameID = Int(data[recordOffset + 6]) << 8 | Int(data[recordOffset + 7])
        let length = Int(data[recordOffset + 8]) << 8 | Int(data[recordOffset + 9])
        let stringOff = Int(data[recordOffset + 10]) << 8 | Int(data[recordOffset + 11])

        let isChinese: Bool
        if platformID == 3 && windowsChineseLangs.contains(languageID) {
            isChinese = true
        } else if platformID == 1 && macChineseLangs.contains(languageID) {
            isChinese = true
        } else {
            isChinese = false
        }

        guard isChinese else { continue }
        guard nameID == 1 || nameID == 4 else { continue } // 1=family, 4=fullName

        let strStart = storageOffset + stringOff
        guard strStart + length <= data.count else { continue }

        let strData = data[strStart..<(strStart + length)]

        let decoded: String?
        if platformID == 3 {
            // Windows: UTF-16 BE
            decoded = String(data: strData, encoding: .utf16BigEndian)
        } else if platformID == 1 {
            // Mac: depends on encoding, but for Chinese it's usually Big5 or GB
            if encodingID == 25 { // simplified Chinese
                let cfEncoding = CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
                let nsEncoding = CFStringConvertEncodingToNSStringEncoding(cfEncoding)
                decoded = String(data: strData, encoding: String.Encoding(rawValue: nsEncoding))
            } else if encodingID == 2 { // traditional Chinese (Big5)
                let cfEncoding = CFStringEncoding(CFStringEncodings.big5.rawValue)
                let nsEncoding = CFStringConvertEncodingToNSStringEncoding(cfEncoding)
                decoded = String(data: strData, encoding: String.Encoding(rawValue: nsEncoding))
            } else {
                decoded = String(data: strData, encoding: .utf8)
            }
        } else {
            decoded = nil
        }

        guard let name = decoded, !name.isEmpty else { continue }

        if nameID == 4 && fullName == nil {
            fullName = name
        } else if nameID == 1 && family == nil {
            family = name
        }
    }

    return (fullName, family)
}

// Extract plain text from an EPUB file (which is a ZIP containing XHTML)
private func extractTextFromEpub(url: URL) -> String {
    guard let archive = try? FileHandle(forReadingFrom: url) else { return "" }
    defer { archive.closeFile() }

    let data = archive.readDataToEndOfFile()
    guard data.count > 22 else { return "" }

    // Find all local file entries in the ZIP
    var entries: [(name: String, data: Data)] = []
    var offset = 0

    while offset + 30 <= data.count {
        // Local file header signature: 0x04034b50
        let sig = data[offset..<offset+4]
        guard sig.elementsEqual([0x50, 0x4b, 0x03, 0x04]) else { break }

        let compMethod = UInt16(data[offset+8]) | UInt16(data[offset+9]) << 8
        let compSize = Int(UInt32(data[offset+18]) | UInt32(data[offset+19]) << 8 | UInt32(data[offset+20]) << 16 | UInt32(data[offset+21]) << 24)
        let uncompSize = Int(UInt32(data[offset+22]) | UInt32(data[offset+23]) << 8 | UInt32(data[offset+24]) << 16 | UInt32(data[offset+25]) << 24)
        let nameLen = Int(UInt16(data[offset+26]) | UInt16(data[offset+27]) << 8)
        let extraLen = Int(UInt16(data[offset+28]) | UInt16(data[offset+29]) << 8)

        let nameStart = offset + 30
        guard nameStart + nameLen <= data.count else { break }
        let nameData = data[nameStart..<nameStart+nameLen]
        let name = String(data: nameData, encoding: .utf8) ?? ""

        let dataStart = nameStart + nameLen + extraLen
        guard dataStart + compSize <= data.count else { break }

        let ext = (name as NSString).pathExtension.lowercased()
        if ["xhtml", "html", "htm", "xml"].contains(ext) && !name.contains("META-INF") {
            let rawData = data[dataStart..<dataStart+compSize]
            if compMethod == 0 {
                // Stored (no compression)
                entries.append((name: name, data: Data(rawData)))
            } else if compMethod == 8 {
                // Deflate
                let decompressed = decompressDeflate(Data(rawData), expectedSize: uncompSize)
                if let d = decompressed {
                    entries.append((name: name, data: d))
                }
            }
        }

        offset = dataStart + compSize
    }

    // Parse content.opf to get spine order if available
    var opfEntries: [(name: String, data: Data)] = []
    // Re-scan for OPF
    offset = 0
    while offset + 30 <= data.count {
        let sig = data[offset..<offset+4]
        guard sig.elementsEqual([0x50, 0x4b, 0x03, 0x04]) else { break }
        let compMethod = UInt16(data[offset+8]) | UInt16(data[offset+9]) << 8
        let compSize = Int(UInt32(data[offset+18]) | UInt32(data[offset+19]) << 8 | UInt32(data[offset+20]) << 16 | UInt32(data[offset+21]) << 24)
        let uncompSize = Int(UInt32(data[offset+22]) | UInt32(data[offset+23]) << 8 | UInt32(data[offset+24]) << 16 | UInt32(data[offset+25]) << 24)
        let nameLen = Int(UInt16(data[offset+26]) | UInt16(data[offset+27]) << 8)
        let extraLen = Int(UInt16(data[offset+28]) | UInt16(data[offset+29]) << 8)
        let nameStart = offset + 30
        guard nameStart + nameLen <= data.count else { break }
        let nameData = data[nameStart..<nameStart+nameLen]
        let name = String(data: nameData, encoding: .utf8) ?? ""
        let dataStart = nameStart + nameLen + extraLen
        guard dataStart + compSize <= data.count else { break }

        if name.hasSuffix(".opf") {
            let rawData = data[dataStart..<dataStart+compSize]
            if compMethod == 0 {
                opfEntries.append((name: name, data: Data(rawData)))
            } else if compMethod == 8 {
                if let d = decompressDeflate(Data(rawData), expectedSize: uncompSize) {
                    opfEntries.append((name: name, data: d))
                }
            }
        }
        offset = dataStart + compSize
    }

    // Try to order entries by spine
    var orderedEntries = entries
    if let opfData = opfEntries.first?.data,
       let opfStr = String(data: opfData, encoding: .utf8) {
        orderedEntries = orderBySpine(entries: entries, opfContent: opfStr)
    }

    // Strip HTML tags to get plain text
    var allText = ""
    for entry in orderedEntries {
        guard let html = String(data: entry.data, encoding: .utf8) ?? String(data: entry.data, encoding: .unicode) else { continue }
        let plain = stripHTMLTags(html)
        let trimmed = plain.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            if !allText.isEmpty { allText += "\n\n" }
            allText += trimmed
        }
    }

    return allText
}

private func orderBySpine(entries: [(name: String, data: Data)], opfContent: String) -> [(name: String, data: Data)] {
    // Parse manifest: <item id="..." href="..." .../>
    var idToHref: [String: String] = [:]
    let itemPattern = try? NSRegularExpression(pattern: #"<item\s[^>]*id="([^"]+)"[^>]*href="([^"]+)"[^>]*/?"#, options: [])
    if let matches = itemPattern?.matches(in: opfContent, range: NSRange(opfContent.startIndex..., in: opfContent)) {
        for match in matches {
            if let idRange = Range(match.range(at: 1), in: opfContent),
               let hrefRange = Range(match.range(at: 2), in: opfContent) {
                idToHref[String(opfContent[idRange])] = String(opfContent[hrefRange])
            }
        }
    }

    // Parse spine: <itemref idref="..." />
    var spineOrder: [String] = []
    let spinePattern = try? NSRegularExpression(pattern: #"<itemref\s[^>]*idref="([^"]+)""#, options: [])
    if let matches = spinePattern?.matches(in: opfContent, range: NSRange(opfContent.startIndex..., in: opfContent)) {
        for match in matches {
            if let idRange = Range(match.range(at: 1), in: opfContent) {
                spineOrder.append(String(opfContent[idRange]))
            }
        }
    }

    if spineOrder.isEmpty { return entries }

    let hrefOrder = spineOrder.compactMap { idToHref[$0] }
    var entryMap: [String: (name: String, data: Data)] = [:]
    for e in entries {
        let basename = (e.name as NSString).lastPathComponent
        entryMap[basename] = e
        entryMap[e.name] = e
    }

    var ordered: [(name: String, data: Data)] = []
    var used: Set<String> = []
    for href in hrefOrder {
        let decoded = href.removingPercentEncoding ?? href
        if let e = entryMap[decoded] ?? entryMap[(decoded as NSString).lastPathComponent] {
            if !used.contains(e.name) {
                ordered.append(e)
                used.insert(e.name)
            }
        }
    }
    // Append any remaining entries not in spine
    for e in entries where !used.contains(e.name) {
        ordered.append(e)
    }
    return ordered
}

private func stripHTMLTags(_ html: String) -> String {
    // Remove <head>...</head> block
    var result = html
    if let regex = try? NSRegularExpression(pattern: "<head[^>]*>[\\s\\S]*?</head>", options: .caseInsensitive) {
        result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "")
    }
    // Replace <br>, <p>, <div> with newlines
    result = result.replacingOccurrences(of: "<br[^>]*>", with: "\n", options: .regularExpression)
    result = result.replacingOccurrences(of: "</(p|div|h[1-6])>", with: "\n", options: .regularExpression)
    // Remove all remaining tags
    result = result.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    // Decode common HTML entities
    result = result.replacingOccurrences(of: "&amp;", with: "&")
    result = result.replacingOccurrences(of: "&lt;", with: "<")
    result = result.replacingOccurrences(of: "&gt;", with: ">")
    result = result.replacingOccurrences(of: "&quot;", with: "\"")
    result = result.replacingOccurrences(of: "&apos;", with: "'")
    result = result.replacingOccurrences(of: "&#160;", with: " ")
    result = result.replacingOccurrences(of: "&nbsp;", with: " ")
    // Collapse multiple newlines
    result = result.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
    return result
}

private func decompressDeflate(_ data: Data, expectedSize: Int) -> Data? {
    let bufferSize = max(expectedSize, data.count * 4)
    let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
    defer { destinationBuffer.deallocate() }

    let decompressedSize = data.withUnsafeBytes { srcPtr -> Int in
        guard let srcBase = srcPtr.baseAddress?.bindMemory(to: UInt8.self, capacity: data.count) else { return 0 }
        return compression_decode_buffer(destinationBuffer, bufferSize, srcBase, data.count, nil, COMPRESSION_ZLIB)
    }

    guard decompressedSize > 0 else { return nil }
    return Data(bytes: destinationBuffer, count: decompressedSize)
}
