import SwiftUI

struct TextPreviewView: View {
    let path: String
    let title: String
    var allowsEditing: Bool = false

    @State private var text: String = ""
    @State private var originalText: String = ""
    @State private var errorText: String?
    @State private var loading = true
    @State private var saving = false
    @State private var toast: String?
    @State private var saveError: String?
    @State private var showSaveFailed = false

    private var isDirty: Bool { allowsEditing && text != originalText }

    var body: some View {
        ZStack {
            Group {
                if loading {
                    ProgressView()
                } else if let errorText {
                    Text(errorText)
                        .foregroundColor(.secondary)
                        .padding()
                } else if allowsEditing {
                    TextEditor(text: $text)
                        .font(.system(.footnote, design: .monospaced))
                        .padding(.horizontal, 8)
                } else {
                    ScrollView {
                        Text(text)
                            .font(.system(.footnote, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                }
            }

            if let toast {
                VStack {
                    Spacer()
                    Text(toast)
                        .font(.footnote)
                        .padding(10)
                        .background(Color(UIColor.secondarySystemBackground).opacity(0.95))
                        .cornerRadius(10)
                        .padding(.bottom, 20)
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    UIPasteboard.general.string = path
                    toast = "路径已复制"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { toast = nil }
                }) {
                    Image(systemName: "doc.on.doc")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: save) {
                    if saving {
                        ProgressView()
                    } else {
                        Text("保存")
                    }
                }
                .disabled(!allowsEditing || !isDirty || saving)
                .opacity(allowsEditing ? 1 : 0)
            }
        }
        .alert(isPresented: $showSaveFailed) {
            Alert(
                title: Text("操作失败"),
                message: Text(saveError ?? ""),
                dismissButton: .cancel(Text("好"))
            )
        }
        .onAppear(perform: load)
    }

    private func load() {
        FileTreeLoader.ioQueue.async {
            let result = FileTreeLoader.loadTextPreview(path: path)
            DispatchQueue.main.async {
                loading = false
                switch result {
                case .success(let value):
                    text = value
                    originalText = value
                case .failure(let error):
                    errorText = error.localizedDescription
                }
            }
        }
    }

    private func save() {
        guard allowsEditing else { return }
        saving = true
        let snapshot = text
        FileTreeLoader.ioQueue.async {
            let result = FileTreeLoader.writeText(snapshot, to: path)
            DispatchQueue.main.async {
                saving = false
                switch result {
                case .success:
                    originalText = snapshot
                    toast = "已保存"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { toast = nil }
                case .failure(let error):
                    saveError = error.localizedDescription
                    showSaveFailed = true
                }
            }
        }
    }
}
