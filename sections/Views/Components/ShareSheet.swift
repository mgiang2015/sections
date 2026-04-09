import UIKit
import SwiftUI

/// Presents a UIActivityViewController directly from the root view controller.
/// This is more reliable than wrapping it in a SwiftUI .sheet on iOS 16+.
enum ShareSheet {

    static func present(items: [Any]) {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return }

        // Walk up to the topmost presented controller so we don't present on a buried VC
        var topVC = root
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)

        // Required on iPad to avoid a crash
        if let popover = controller.popoverPresentationController {
            popover.sourceView = topVC.view
            popover.sourceRect = CGRect(
                x: topVC.view.bounds.midX,
                y: topVC.view.bounds.midY,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = []
        }

        topVC.present(controller, animated: true)
    }
}
