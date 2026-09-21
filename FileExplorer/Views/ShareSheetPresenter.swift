import UniformTypeIdentifiers
import UIKit

enum ShareSheetPresenter {
    private static var isPresenting = false

    static func present(items: [Any], completion: (() -> Void)? = nil) {
        DispatchQueue.main.async {
            guard !items.isEmpty else {
                completion?()
                return
            }
            if isPresenting {
                completion?()
                return
            }
            guard let presenter = topViewController(),
                  presenter.presentedViewController == nil,
                  !presenter.isBeingDismissed
            else {
                completion?()
                return
            }

            let controller = AnchoredActivityViewController(
                activityItems: items,
                applicationActivities: nil
            )
            controller.completionWithItemsHandler = { _, _, _, _ in
                DispatchQueue.main.async {
                    isPresenting = false
                    completion?()
                }
            }
            anchorPopover(of: controller, to: presenter.view)

            isPresenting = true
            presenter.present(controller, animated: true) {
                if presenter.presentedViewController == nil {
                    isPresenting = false
                    completion?()
                }
            }
        }
    }

    static func typeIdentifier(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        if #available(iOS 14.0, *), let type = UTType(filenameExtension: ext) {
            return type.identifier
        }
        switch ext {
        case "json": return "public.json"
        case "txt", "text", "md": return "public.plain-text"
        case "plist": return "com.apple.property-list"
        default: return "public.data"
        }
    }

    private static func anchorPopover(of controller: UIViewController, to view: UIView) {
        guard let popover = controller.popoverPresentationController else { return }
        popover.sourceView = view
        popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
        popover.permittedArrowDirections = []
        popover.canOverlapSourceViewRect = true
    }

    private static func topViewController(base: UIViewController? = nil) -> UIViewController? {
        let root = base ?? activeWindow()?.rootViewController
        if let nav = root as? UINavigationController {
            return topViewController(base: nav.visibleViewController ?? nav.topViewController)
        }
        if let tab = root as? UITabBarController {
            return topViewController(base: tab.selectedViewController)
        }
        if let split = root as? UISplitViewController {
            return topViewController(base: split.viewControllers.last)
        }
        if let presented = root?.presentedViewController {
            if presented is UIAlertController || presented is UIActivityViewController {
                return root
            }
            return topViewController(base: presented)
        }
        return root
    }

    private static func activeWindow() -> UIWindow? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let preferred = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        return preferred?.windows.first(where: \.isKeyWindow) ?? preferred?.windows.first
    }
}

final class AnchoredActivityViewController: UIActivityViewController {
    override func present(
        _ viewControllerToPresent: UIViewController,
        animated flag: Bool,
        completion: (() -> Void)? = nil
    ) {
        if let popover = viewControllerToPresent.popoverPresentationController,
           popover.sourceView == nil {
            if let anchor = view ?? presentingViewController?.view {
                popover.sourceView = anchor
                popover.sourceRect = CGRect(
                    x: anchor.bounds.midX,
                    y: anchor.bounds.midY,
                    width: 1,
                    height: 1
                )
                popover.permittedArrowDirections = []
                popover.canOverlapSourceViewRect = true
            }
        }
        super.present(viewControllerToPresent, animated: flag, completion: completion)
    }
}

final class FileActivityItem: NSObject, UIActivityItemSource {
    let url: URL
    let typeIdentifier: String

    init(url: URL, typeIdentifier: String) {
        self.url = url
        self.typeIdentifier = typeIdentifier
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        url
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        url
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        typeIdentifier
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        subjectForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        url.lastPathComponent
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        thumbnailForActivityType activityType: UIActivity.ActivityType?,
        suggestedSize size: CGSize
    ) -> UIImage? {
        nil
    }
}

enum FileShareCoordinator {
    static func prepare(
        path: String,
        preparing: @escaping (Bool) -> Void,
        completion: @escaping (Result<FileSharePayload, Error>) -> Void
    ) {
        preparing(true)
        FileTreeLoader.ioQueue.async {
            let result = FileTreeLoader.copyForSharing(path: path).map { url -> FileSharePayload in
                FileSharePayload(
                    items: [FileActivityItem(url: url, typeIdentifier: FileTreeLoader.typeIdentifier(for: path))],
                    cleanupURL: url
                )
            }
            DispatchQueue.main.async {
                preparing(false)
                completion(result)
            }
        }
    }
}

struct FileSharePayload: Identifiable {
    let id = UUID()
    let items: [Any]
    let cleanupURL: URL?

    func cleanup() {
        guard let cleanupURL else { return }
        FileTreeLoader.removeShareStaging(around: cleanupURL)
    }
}
