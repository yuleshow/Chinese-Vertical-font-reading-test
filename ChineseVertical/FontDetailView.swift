import SwiftUI
import UniformTypeIdentifiers

struct FontDetailView: View {
    let fontName: String
    let fontDetails: [FontDetail]
    @Binding var isTargeted: Bool
    let onFontDrop: (URL) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Font: \(fontName)")
                    .font(.headline)
                Spacer()
                Text("Drag a font file here")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding(.horizontal)
            .padding(.top, 12)

            if fontDetails.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "textformat")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("Drop a .ttf or .otf font file anywhere")
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(fontDetails) { detail in
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
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url = url else { return }
                let ext = url.pathExtension.lowercased()
                guard ["ttf", "otf", "ttc", "dfont"].contains(ext) else { return }
                DispatchQueue.main.async {
                    onFontDrop(url)
                }
            }
            return true
        }
    }
}
