import SwiftUI
import CoreText

struct VerticalTextView: NSViewRepresentable {
    let text: String
    let font: CTFont?
    let missingCodePoints: Set<UInt32>
    let wrongRotationCodePoints: Set<UInt32>
    @Binding var fontSize: CGFloat
    var isPaginated: Bool = false
    var onPageInfo: ((Int, Int) -> Void)? = nil  // (currentPage, totalPages)

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> VerticalTextNSView {
        let view = VerticalTextNSView()
        view.text = text
        view.customFont = font
        view.missingCodePoints = missingCodePoints
        view.wrongRotationCodePoints = wrongRotationCodePoints
        view.fontSize = fontSize
        view.isPaginated = isPaginated
        view.onFontSizeChange = { newSize in
            DispatchQueue.main.async {
                self.fontSize = newSize
            }
        }
        view.onPageInfo = onPageInfo
        view.coordinator = context.coordinator
        context.coordinator.view = view
        return view
    }

    func updateNSView(_ nsView: VerticalTextNSView, context: Context) {
        let textChanged = nsView.text != text
        let fontChanged = nsView.fontSize != fontSize
        nsView.text = text
        nsView.customFont = font
        nsView.missingCodePoints = missingCodePoints
        nsView.wrongRotationCodePoints = wrongRotationCodePoints
        nsView.fontSize = fontSize
        nsView.isPaginated = isPaginated
        nsView.onPageInfo = onPageInfo
        if textChanged || fontChanged {
            nsView.pageBreaks = nil  // recalculate
            nsView.currentPage = 0
        }
        nsView.needsDisplay = true
    }

    class Coordinator {
        weak var view: VerticalTextNSView?

        func nextPage() {
            view?.goNextPage()
        }
        func prevPage() {
            view?.goPrevPage()
        }
    }
}

class VerticalTextNSView: NSView {
    var text: String = ""
    var customFont: CTFont?
    var missingCodePoints: Set<UInt32> = []
    var wrongRotationCodePoints: Set<UInt32> = []
    var fontSize: CGFloat = 48
    var isPaginated: Bool = false
    var currentPage: Int = 0
    var pageBreaks: [CFIndex]? = nil  // character offsets where each page starts
    var onFontSizeChange: ((CGFloat) -> Void)?
    var onPageInfo: ((Int, Int) -> Void)?
    weak var coordinator: VerticalTextView.Coordinator?

    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { false }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if isPaginated {
            DispatchQueue.main.async {
                self.window?.makeFirstResponder(self)
            }
        }
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        if isPaginated {
            // Click on right half = previous page (vertical-rl: right is earlier),
            // click on left half = next page
            let loc = convert(event.locationInWindow, from: nil)
            if loc.x < bounds.midX {
                goNextPage()
            } else {
                goPrevPage()
            }
        }
    }

    override func scrollWheel(with event: NSEvent) {
        if event.modifierFlags.contains(.command) {
            let delta = event.scrollingDeltaY
            let newSize = max(12, min(200, fontSize + delta))
            fontSize = newSize
            onFontSizeChange?(newSize)
            needsDisplay = true
        } else {
            super.scrollWheel(with: event)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let context = NSGraphicsContext.current?.cgContext else { return }

        let font: CTFont
        if let customFont = customFont {
            font = CTFontCreateCopyWithAttributes(customFont, fontSize, nil, nil)
        } else {
            font = CTFontCreateWithName("STSong" as CFString, fontSize, nil)
        }

        // Replace missing characters with □, keep rest as-is
        let processedText: String
        if !missingCodePoints.isEmpty {
            processedText = String(text.unicodeScalars.map { scalar -> Character in
                if missingCodePoints.contains(scalar.value) {
                    return "□"
                }
                return Character(scalar)
            })
        } else {
            processedText = text
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.textColor,
            .verticalGlyphForm: true
        ]

        let attributedString = NSMutableAttributedString(string: processedText, attributes: attributes)

        // Color missing characters (□) in red
        if !missingCodePoints.isEmpty {
            var offset = 0
            for scalar in text.unicodeScalars {
                let replacement = missingCodePoints.contains(scalar.value) ? "□" : String(scalar)
                let charLen = replacement.utf16.count
                if missingCodePoints.contains(scalar.value) {
                    attributedString.addAttribute(.foregroundColor, value: NSColor.red, range: NSRange(location: offset, length: charLen))
                }
                offset += charLen
            }
        }

        // Color wrong-rotation characters in red
        if !wrongRotationCodePoints.isEmpty {
            var offset = 0
            for scalar in processedText.unicodeScalars {
                let charLen = String(scalar).utf16.count
                if wrongRotationCodePoints.contains(scalar.value) {
                    attributedString.addAttribute(.foregroundColor, value: NSColor.red, range: NSRange(location: offset, length: charLen))
                }
                offset += charLen
            }
        }

        let frameAttrs: [CFString: Any] = [
            kCTFrameProgressionAttributeName: CTFrameProgression.rightToLeft.rawValue
        ]

        let padding: CGFloat = 40
        let textRect = bounds.insetBy(dx: padding, dy: padding)
        let path = CGPath(rect: textRect, transform: nil)

        if isPaginated {
            // Calculate page breaks if needed
            let totalLength = attributedString.length
            if pageBreaks == nil {
                var breaks: [CFIndex] = [0]
                let setter = CTFramesetterCreateWithAttributedString(attributedString)
                var startIndex: CFIndex = 0
                while startIndex < totalLength {
                    let frame = CTFramesetterCreateFrame(setter, CFRange(location: startIndex, length: 0), path, frameAttrs as CFDictionary)
                    let visibleRange = CTFrameGetVisibleStringRange(frame)
                    if visibleRange.length == 0 { break }
                    startIndex += visibleRange.length
                    if startIndex < totalLength {
                        breaks.append(startIndex)
                    }
                }
                pageBreaks = breaks
            }

            guard let breaks = pageBreaks, !breaks.isEmpty else { return }
            let totalPages = breaks.count
            currentPage = max(0, min(currentPage, totalPages - 1))

            let pageStart = breaks[currentPage]
            let pageLength: CFIndex
            if currentPage + 1 < breaks.count {
                pageLength = breaks[currentPage + 1] - pageStart
            } else {
                pageLength = totalLength - pageStart
            }

            let setter = CTFramesetterCreateWithAttributedString(attributedString)
            let frame = CTFramesetterCreateFrame(setter, CFRange(location: pageStart, length: pageLength), path, frameAttrs as CFDictionary)

            context.saveGState()
            CTFrameDraw(frame, context)
            context.restoreGState()

            onPageInfo?(currentPage + 1, totalPages)
        } else {
            // Non-paginated: render all text
            let frameSetter = CTFramesetterCreateWithAttributedString(attributedString)
            let frame = CTFramesetterCreateFrame(frameSetter, CFRange(location: 0, length: 0), path, frameAttrs as CFDictionary)

            context.saveGState()
            CTFrameDraw(frame, context)
            context.restoreGState()
        }
    }

    func goNextPage() {
        guard let breaks = pageBreaks else { return }
        if currentPage < breaks.count - 1 {
            currentPage += 1
            needsDisplay = true
        }
    }

    func goPrevPage() {
        if currentPage > 0 {
            currentPage -= 1
            needsDisplay = true
        }
    }

    override func keyDown(with event: NSEvent) {
        guard isPaginated else {
            super.keyDown(with: event)
            return
        }
        switch event.keyCode {
        case 123, 1, 49, 125:  // left, s, space, down → next page
            goNextPage()
        case 124, 13, 2, 126:  // right, w, d, up → previous page
            goPrevPage()
        case 0:  // a → next page
            goNextPage()
        case 53:  // esc → previous page
            goPrevPage()
        default:
            super.keyDown(with: event)
        }
    }
}
