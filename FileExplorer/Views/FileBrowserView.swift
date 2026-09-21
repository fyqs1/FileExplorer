import SwiftUI
import UIKit

/// One-folder-per-screen browser. Supports list / create / rename / delete when `allowsMutation` is true.
struct FileBrowserView: View {
    let rootTitle: String
    let rootPath: String
    var allowsMutation: Bool = true

    private enum NameEditorKind: String, Identifiable {
        case rename
        case newFolder
        case newFile
        var id: String { rawValue }
    }

    private enum ActiveAlert: Identifiable {
        case delete
        case error(String)
        var id: String {
            switch self {
            case .delete: return "delete"
            case .error(let m): return "error-\(m)"
            }
        }
    }

    @State private var browsePath: String = ""
    @State private var nodes: [FileNode] = []
    @State private var isLoading = true
    @State private var errorText: String?
    @State private var emptyHint: String?
    @State private var toast: String?
    @State private var showHidden = true
    @State private var sortMode: FileSortMode = FileSortMode.stored
    @State private var loadToken = UUID()

    @State private var pendingDelete: FileNode?
    @State private var renameTarget: FileNode?
    @State private var editorText = ""
    @State private var nameEditor: NameEditorKind?
    @State private var activeAlert: ActiveAlert?
    @State private var preparingShare = false

    private var activePath: String {
        browsePath.isEmpty ? rootPath : browsePath
    }

    var body: some View {
        ZStack {
            Group {
                if isLoading {
                    ProgressView()
                } else if let errorText {
                    List {
                        Section { pathHeader }
                        if parentPath != nil {
                            Section { parentDirectoryLink }
                        }
                        Section {
                            Text(errorText).foregroundColor(.secondary)
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                } else if nodes.isEmpty {
                    List {
                        Section { pathHeader }
                        if parentPath != nil {
                            Section { parentDirectoryLink }
                        }
                        Section {
                            Text(emptyHint ?? "文件夹为空").foregroundColor(.secondary)
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                } else {
                    List {
                        Section { pathHeader }
                        Section(header: Text("共 \(nodes.count) 项")) {
                            if parentPath != nil {
                                parentDirectoryLink
                            }
                            ForEach(nodes) { node in
                                fileRow(node)
                            }
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
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

            if preparingShare {
                Color.black.opacity(0.12).edgesIgnoringSafeArea(.all)
                ProgressView("准备分享…")
                    .padding(16)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
            }
        }
        .navigationTitle(rootTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { copyPath(activePath) }) {
                        Label("复制当前路径", systemImage: "doc.on.doc")
                    }
                    Button(action: { showHidden.toggle() }) {
                        Label(
                            showHidden ? "隐藏点文件" : "显示点文件",
                            systemImage: showHidden ? "eye.slash" : "eye"
                        )
                    }

                    Menu {
                        ForEach(FileSortMode.allCases) { mode in
                            Button(action: { applySort(mode) }) {
                                HStack {
                                    Text(mode.title)
                                    if sortMode == mode {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Label("排序", systemImage: "arrow.up.arrow.down")
                    }

                    if allowsMutation {
                        Divider()
                        Button(action: {
                            editorText = ""
                            nameEditor = .newFolder
                        }) {
                            Label("新建文件夹", systemImage: "folder.badge.plus")
                        }
                        Button(action: {
                            editorText = "untitled.txt"
                            nameEditor = .newFile
                        }) {
                            Label("新建文本文件", systemImage: "doc.badge.plus")
                        }
                    }
                    Button(action: load) {
                        Label("刷新", systemImage: "arrow.clockwise")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(item: $nameEditor) { kind in
            NameEditorSheet(
                title: {
                    switch kind {
                    case .rename: return "重命名"
                    case .newFolder: return "新建文件夹"
                    case .newFile: return "新建文本文件"
                    }
                }(),
                placeholder: "名称",
                text: $editorText,
                onCancel: { nameEditor = nil },
                onConfirm: {
                    let kindCopy = kind
                    nameEditor = nil
                    switch kindCopy {
                    case .rename: performRename()
                    case .newFolder: performCreateFolder()
                    case .newFile: performCreateFile()
                    }
                }
            )
        }
        .alert(item: $activeAlert) { alert in
            switch alert {
            case .delete:
                return Alert(
                    title: Text("确认删除"),
                    message: Text(deleteMessage(for: pendingDelete)),
                    primaryButton: .destructive(Text("删除")) {
                        if let node = pendingDelete {
                            performDelete(node)
                        }
                    },
                    secondaryButton: .cancel(Text("取消"))
                )
            case .error(let message):
                return Alert(
                    title: Text("操作失败"),
                    message: Text(message),
                    dismissButton: .cancel(Text("好"))
                )
            }
        }
        .onAppear { load() }
        .onChange(of: showHidden) { _ in load() }
    }

    private var parentPath: String? {
        let path = activePath
        guard path != "/", !path.isEmpty else { return nil }
        let parent = (path as NSString).deletingLastPathComponent
        if parent.isEmpty { return "/" }
        return parent
    }

    @ViewBuilder
    private var parentDirectoryLink: some View {
        if let parent = parentPath {
            let title = parent == "/" ? "/" : (parent as NSString).lastPathComponent
            NavigationLink(
                destination: FileBrowserView(
                    rootTitle: title,
                    rootPath: parent,
                    allowsMutation: allowsMutation
                )
            ) {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.up.left.circle.fill")
                        .font(.title3)
                        .foregroundColor(Color.accentColor)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("上级目录")
                            .font(.body)
                        Text(parent)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 6)
            }
        }
    }

    private var pathHeader: some View {
        Button(action: { copyPath(activePath) }) {
            VStack(alignment: .leading, spacing: 6) {
                Text("当前目录")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(activePath)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                Text("点按复制路径")
                    .font(.caption2)
                    .foregroundColor(.accentColor)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }

    @ViewBuilder
    private func fileRow(_ node: FileNode) -> some View {
        Group {
            if node.isDirectory {
                NavigationLink(
                    destination: FileBrowserView(
                        rootTitle: node.name,
                        rootPath: node.path,
                        allowsMutation: allowsMutation
                    )
                ) {
                    rowLabel(node, systemImage: "folder.fill", tint: true, detail: "进入目录")
                }
            } else if FileTreeLoader.isLikelyTextFile(path: node.path, size: node.fileSize) {
                NavigationLink(
                    destination: TextPreviewView(
                        path: node.path,
                        title: node.name,
                        allowsEditing: allowsMutation
                    )
                ) {
                    rowLabel(node, systemImage: "doc.text", tint: false, detail: "打开文本")
                }
            } else {
                let packaged = FileTreeLoader.isPackageFile(node.path)
                NavigationLink(
                    destination: FileDetailView(
                        path: node.path,
                        name: node.name,
                        fileSize: node.fileSize
                    )
                ) {
                    rowLabel(
                        node,
                        systemImage: FileTreeLoader.systemImage(for: node.path),
                        tint: packaged,
                        detail: "查看详情"
                    )
                }
            }
        }
        .contextMenu { contextMenu(for: node) }
    }

    @ViewBuilder
    private func contextMenu(for node: FileNode) -> some View {
        Button(action: { copyPath(node.path) }) {
            Label("复制路径", systemImage: "doc.on.doc")
        }
        if !node.isDirectory {
            Button(action: { shareFile(at: node.path) }) {
                Label("分享", systemImage: "square.and.arrow.up")
            }
        }
        if allowsMutation {
            Button(action: {
                renameTarget = node
                editorText = node.name
                nameEditor = .rename
            }) {
                Label("重命名", systemImage: "pencil")
            }
            Button(action: {
                pendingDelete = node
                activeAlert = .delete
            }) {
                Label("删除", systemImage: "trash")
            }
        }
    }

    private func rowLabel(_ node: FileNode, systemImage: String, tint: Bool, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundColor(tint ? Color.accentColor : Color.secondary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(node.name)
                        .font(.body)
                        .lineLimit(2)
                    if node.isHidden {
                        Text("•")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                HStack(spacing: 8) {
                    if let size = node.fileSize {
                        Text(Formatters.bytes(size))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Text(detail)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    private func load() {
        let token = UUID()
        loadToken = token
        isLoading = true
        errorText = nil
        emptyHint = nil
        let requested = rootPath
        let hidden = showHidden
        FileTreeLoader.ioQueue.async {
            let resolved = FileTreeLoader.resolveDirectoryPath(requested)
            let outcome = FileTreeLoader.listChildren(at: resolved, includeHidden: hidden)
            DispatchQueue.main.async {
                guard loadToken == token else { return }
                browsePath = resolved
                isLoading = false
                switch outcome {
                case .listed(let listed):
                    var sorted = listed
                    FileSortMode.sort(&sorted, mode: sortMode)
                    nodes = sorted
                    if listed.isEmpty {
                        emptyHint = "文件夹为空"
                    }
                case .unreadable(let message):
                    nodes = []
                    errorText = "无法读取：\(message)"
                case .missing:
                    nodes = []
                    errorText = "路径不可用"
                }
            }
        }
    }

    private func applySort(_ mode: FileSortMode) {
        sortMode = mode
        FileSortMode.stored = mode
        var sorted = nodes
        FileSortMode.sort(&sorted, mode: mode)
        nodes = sorted
    }

    private func copyPath(_ path: String) {
        UIPasteboard.general.string = path
        withAnimation { toast = "路径已复制" }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation { toast = nil }
        }
    }

    private func shareFile(at path: String) {
        FileShareCoordinator.prepare(path: path) { preparingShare = $0 } completion: { result in
            switch result {
            case .success(let payload):
                ShareSheetPresenter.present(items: payload.items) {
                    payload.cleanup()
                }
            case .failure(let error):
                activeAlert = .error(error.localizedDescription)
            }
        }
    }

    private func deleteMessage(for node: FileNode?) -> String {
        guard let node else { return "" }
        var msg = "将删除：\n\(node.path)"
        if FileTreeLoader.isSensitivePath(node.path) {
            msg += "\n\n这是敏感系统路径，请确认。"
        }
        return msg
    }

    private func performDelete(_ node: FileNode) {
        FileTreeLoader.ioQueue.async {
            let result = FileTreeLoader.removeItem(at: node.path)
            DispatchQueue.main.async {
                switch result {
                case .success:
                    toast = "已删除"
                    load()
                case .failure(let error):
                    activeAlert = .error(error.localizedDescription)
                }
            }
        }
    }

    private func performRename() {
        guard let target = renameTarget else { return }
        let name = editorText
        FileTreeLoader.ioQueue.async {
            let result = FileTreeLoader.renameItem(at: target.path, to: name)
            DispatchQueue.main.async {
                switch result {
                case .success:
                    toast = "已重命名"
                    load()
                case .failure(let error):
                    activeAlert = .error(error.localizedDescription)
                }
            }
        }
    }

    private func performCreateFolder() {
        let name = editorText
        let parent = activePath
        FileTreeLoader.ioQueue.async {
            let result = FileTreeLoader.createDirectory(named: name, in: parent)
            DispatchQueue.main.async {
                switch result {
                case .success:
                    toast = "已创建"
                    load()
                case .failure(let error):
                    activeAlert = .error(error.localizedDescription)
                }
            }
        }
    }

    private func performCreateFile() {
        let name = editorText
        let parent = activePath
        FileTreeLoader.ioQueue.async {
            let result = FileTreeLoader.createTextFile(named: name, in: parent)
            DispatchQueue.main.async {
                switch result {
                case .success:
                    toast = "已创建"
                    load()
                case .failure(let error):
                    activeAlert = .error(error.localizedDescription)
                }
            }
        }
    }
}

private struct NameEditorSheet: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        NavigationView {
            Form {
                TextField(placeholder, text: $text)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确定", action: onConfirm)
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
