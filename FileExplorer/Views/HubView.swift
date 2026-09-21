import SwiftUI

struct HubView: View {
    private struct Shortcut: Identifiable {
        let id: String
        let title: String
        let path: String
        let subtitle: String?
    }

    @State private var onMyiPhonePath: String?
    @State private var didResolve = false

    private var shortcuts: [Shortcut] {
        var items: [Shortcut] = [
            Shortcut(id: "root", title: "/", path: "/", subtitle: "文件系统根目录"),
            Shortcut(id: "jb-mobile", title: "/var/jb/var/mobile", path: "/var/jb/var/mobile", subtitle: "越狱用户目录"),
            Shortcut(
                id: "app-data",
                title: "App Data",
                path: "/var/mobile/Containers/Data/Application",
                subtitle: "应用数据容器"
            ),
            Shortcut(
                id: "app-bundle",
                title: "App Bundle",
                path: "/var/containers/Bundle/Application",
                subtitle: "应用安装包"
            )
        ]
        if let path = onMyiPhonePath {
            items.append(
                Shortcut(
                    id: "on-my-iphone",
                    title: "我的 iPhone",
                    path: path,
                    subtitle: "文件 App → 我的 iPhone"
                )
            )
        } else if didResolve {
            items.append(
                Shortcut(
                    id: "on-my-iphone-missing",
                    title: "我的 iPhone",
                    path: OnMyiPhoneLocator.appGroupBase,
                    subtitle: "未找到 File Provider Storage"
                )
            )
        }
        return items
    }

    var body: some View {
        List {
            Section(header: Text("快捷入口"), footer: Text("需要 TrollStore 安装并具备无沙盒 / 根路径权限。可进入任意目录浏览与编辑。")) {
                ForEach(shortcuts) { item in
                    let openPath = FileTreeLoader.resolveDirectoryPath(item.path)
                    let available = pathAvailable(item.path, openPath: openPath)
                        && item.id != "on-my-iphone-missing"

                    if available {
                        NavigationLink(
                            destination: FileBrowserView(
                                rootTitle: item.title,
                                rootPath: item.path,
                                allowsMutation: true
                            )
                        ) {
                            shortcutLabel(item, unavailable: false)
                        }
                    } else {
                        shortcutLabel(item, unavailable: true)
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("FileExplorer")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            if !didResolve {
                onMyiPhonePath = OnMyiPhoneLocator.resolvePath()
                didResolve = true
            }
        }
    }

    private func pathAvailable(_ path: String, openPath: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
            || FileManager.default.fileExists(atPath: openPath)
            || (try? FileManager.default.destinationOfSymbolicLink(atPath: path)) != nil
    }

    private func shortcutLabel(_ item: Shortcut, unavailable: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(item.title)
                .font(.body)
            if let subtitle = item.subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            if item.title != item.path {
                Text(item.path)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            if unavailable {
                Text("路径不可用")
                    .font(.caption2)
                    .foregroundColor(Color(UIColor.tertiaryLabel))
            }
        }
        .padding(.vertical, 2)
    }
}
