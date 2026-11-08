import UIKit

/// Presents the system share sheet (AirDrop first, Messages as the fallback) from the top view controller.
enum Share {
    static func present(_ items: [Any], completion: @escaping (Bool) -> Void = { _ in }) {
        guard let root = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?.rootViewController else {
            completion(false)
            return
        }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        vc.excludedActivityTypes = [.assignToContact, .addToReadingList, .openInIBooks, .postToFacebook, .postToTwitter]
        vc.completionWithItemsHandler = { _, completed, _, _ in completion(completed) }
        vc.popoverPresentationController?.sourceView = top.view
        top.present(vc, animated: true)
    }
}
