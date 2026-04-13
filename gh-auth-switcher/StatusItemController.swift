import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusItemController: NSObject {
    private let appState: AppState
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let popover = NSPopover()
    private let hostingController: NSHostingController<AnyView>
    private let iconView = StatusIconView(frame: NSRect(x: 0, y: 0, width: 18, height: 18))
    private let badgeView = StatusBadgeView(frame: NSRect(x: 0, y: 0, width: 9, height: 9))
    private var cancellables = Set<AnyCancellable>()

    init(appState: AppState) {
        self.appState = appState
        self.hostingController = NSHostingController(
            rootView: AnyView(
                ContentView().environmentObject(appState)
            )
        )
        super.init()
        configurePopover()
        configureStatusItem()
        bindState()

        Task {
            await appState.loadIfNeeded()
        }
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = false
        popover.contentViewController = hostingController
        updatePopoverSize()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else {
            return
        }

        button.image = nil
        button.imagePosition = .noImage
        button.target = self
        button.action = #selector(togglePopover(_:))
        button.sendAction(on: [.leftMouseUp])
        button.addSubview(iconView)
        button.addSubview(badgeView)

        updateStatusAppearance()
    }

    private func bindState() {
        appState.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.updateStatusAppearance()
                }
            }
            .store(in: &cancellables)

        DistributedNotificationCenter.default()
            .publisher(for: Notification.Name("AppleInterfaceThemeChangedNotification"))
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateStatusAppearance()
            }
            .store(in: &cancellables)
    }

    @objc
    private func togglePopover(_ sender: Any?) {
        if popover.isShown {
            popover.performClose(sender)
            return
        }

        guard let button = statusItem.button else {
            return
        }

        updatePopoverSize()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.becomeKey()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func updateStatusAppearance() {
        guard let button = statusItem.button else {
            return
        }

        iconView.image = StatusIconRenderer.makeBaseImage()
        badgeView.badgeColor = StatusIconRenderer.makeBadgeColor(
            color: appState.menuBarColor,
            hasError: appState.hasError
        )
        badgeView.showsError = appState.hasError
        layoutIcon(in: button)
        layoutBadge(in: button)
    }

    private func layoutIcon(in button: NSStatusBarButton) {
        let size = NSSize(width: 18, height: 18)
        iconView.frame = NSRect(
            x: floor((button.bounds.width - size.width) / 2),
            y: floor((button.bounds.height - size.height) / 2),
            width: size.width,
            height: size.height
        )
    }

    private func layoutBadge(in button: NSStatusBarButton) {
        let size: CGFloat = appState.hasError ? 10 : 9
        let originX = max(0, floor((button.bounds.width / 2) + 3))
        let originY = max(0, floor((button.bounds.height / 2) - 1))
        badgeView.frame = NSRect(x: originX, y: originY, width: size, height: size)
    }

    private func updatePopoverSize() {
        let view = hostingController.view
        view.layoutSubtreeIfNeeded()
        let fittingSize = view.fittingSize
        popover.contentSize = NSSize(
            width: max(280, fittingSize.width),
            height: max(120, fittingSize.height)
        )
    }
}

@MainActor
final class StatusItemAppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        statusItemController = StatusItemController(appState: appState)
    }
}

private final class StatusIconView: NSImageView {
    override var isOpaque: Bool {
        false
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        imageScaling = .scaleProportionallyDown
        imageAlignment = .alignCenter
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class StatusBadgeView: NSView {
    var badgeColor: NSColor = .systemGray {
        didSet {
            needsDisplay = true
        }
    }

    var showsError = false {
        didSet {
            needsDisplay = true
        }
    }

    override var isOpaque: Bool {
        false
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let circleRect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let circlePath = NSBezierPath(ovalIn: circleRect)
        badgeColor.setFill()
        circlePath.fill()

        NSColor.controlBackgroundColor.withAlphaComponent(0.85).setStroke()
        circlePath.lineWidth = 1
        circlePath.stroke()

        guard showsError else {
            return
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 6, weight: .bold),
            .foregroundColor: NSColor.white
        ]
        let text = NSAttributedString(string: "!", attributes: attributes)
        let textSize = text.size()
        let textRect = NSRect(
            x: (bounds.width - textSize.width) / 2,
            y: (bounds.height - textSize.height) / 2 - 0.5,
            width: textSize.width,
            height: textSize.height
        )
        text.draw(in: textRect)
    }
}
