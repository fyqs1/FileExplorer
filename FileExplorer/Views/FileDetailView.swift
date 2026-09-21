import SwiftUI
import UIKit

struct FileDetailView: View {
    let path: String
    let name: String
    var fileSize: UInt64?

    @State private var meta = FileTreeLoader.FileDetailMeta(
        exists: true,
        size: nil,
        modified: nil,
        isReadable: false,
        isWritable: false
    )
    @State private var toast: String?
    @State private var preparingShare = false
    @State private var actionError: String?
    @State private var showActionError = false

    var body: some View {
        ZStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        Image(systemName: FileTreeLoader.systemImage(for: path))
                            .font(.largeTitle)
                            .foregroundColor(FileTreeLoader.isPackageFile(path) ? Color.accentColor : Color.secondary)
                            .frame(width: 52, height: 52)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(name)
                                .font(.title3)
                                .fontWeight(.semibold)
                            Text(FileTreeLoader.typeDisplayName(for: path))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    infoRow("大小", sizeText)
                    infoRow("类型", FileTreeLoader.typeDisplayName(for: path))
                    infoRow("修改时间", modifiedText)
                    infoRow("可读", meta.isReadable ? "是" : "否")
                    infoRow("可写", meta.isWritable ? "是" : "否")
                }

                Section {
                    Button(action: copyPath) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("完整路径")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(path)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)
                            Text("点按复制路径")
                                .font(.caption2)
                                .foregroundColor(.accentColor)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .listStyle(InsetGroupedListStyle())

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

            if preparingShare {
                Color.black.opacity(0.12).edgesIgnoringSafeArea(.all)
                ProgressView("准备分享…")
                    .padding(16)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
            }
        }
        .navigationTitle("文件详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: share) {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(preparingShare || !meta.exists)
            }
        }
        .alert(isPresented: $showActionError) {
            Alert(
                title: Text("分享失败"),
                message: Text(actionError ?? ""),
                dismissButton: .cancel(Text("好"))
            )
        }
        .onAppear {
            meta = FileTreeLoader.loadDetailMeta(at: path)
        }
    }

    private var sizeText: String {
        if let size = meta.size ?? fileSize {
            return Formatters.bytes(size)
        }
        return "—"
    }

    private var modifiedText: String {
        guard let date = meta.modified else { return "—" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title).foregroundColor(.secondary)
            Spacer()
            Text(value).multilineTextAlignment(.trailing)
        }
    }

    private func copyPath() {
        UIPasteboard.general.string = path
        withAnimation { toast = "路径已复制" }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation { toast = nil }
        }
    }

    private func share() {
        FileShareCoordinator.prepare(path: path) { preparingShare = $0 } completion: { result in
            switch result {
            case .success(let payload):
                ShareSheetPresenter.present(items: payload.items) {
                    payload.cleanup()
                }
            case .failure(let error):
                actionError = error.localizedDescription
                showActionError = true
            }
        }
    }
}
