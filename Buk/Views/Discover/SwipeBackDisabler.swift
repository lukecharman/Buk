import SwiftUI
#if canImport(UIKit) && (os(iOS) || os(visionOS))
import UIKit

/// Disables the system left-edge interactive pop gesture for the screen this
/// modifier is attached to, restoring it on disappear. Pair with
/// `.navigationBarBackButtonHidden(true)` (or a hidden nav bar) when replacing
/// the back-swipe with a custom dismiss gesture.
struct SwipeBackDisabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller { Controller() }
    func updateUIViewController(_ vc: Controller, context: Context) {}

    final class Controller: UIViewController {
        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        }
        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        }
    }
}

extension View {
    func disableSwipeBack() -> some View {
        background(SwipeBackDisabler().frame(width: 0, height: 0).allowsHitTesting(false))
    }
}
#else
extension View {
    /// No-op on platforms without UIKit's interactive pop gesture (e.g. macOS).
    func disableSwipeBack() -> some View { self }
}
#endif
