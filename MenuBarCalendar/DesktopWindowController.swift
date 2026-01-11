import SwiftUI
import AppKit
import Combine

class DesktopWindowController: NSWindowController, NSWindowDelegate {
    class DragState: ObservableObject {
        @Published var isDragging: Bool = false
    }
    private let dragState = DragState()
    
    init() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 350, height: 600),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = false
        panel.isMovableByWindowBackground = true
        
        super.init(window: panel)
        panel.delegate = self
        
        setupContentView()
        setupNotificationObservers()
        positionOnRightEdge()
    }
    
    private func setupContentView() {
        let viewModel = (NSApp.delegate as? AppDelegate)?.calendarViewModel ?? CalendarViewModel()
        // 去除這裡的 padding(50)，讓 SwiftUI 內部決定真實大小
        let contentView = DesktopContentView(viewModel: viewModel, dragState: dragState)
        window?.contentView = NSHostingView(rootView: contentView)
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(updateSize(_:)), name: Notification.Name("UpdateDesktopWindowSize"), object: nil)
    }
    
    @objc private func updateSize(_ notification: Notification) {
        guard let sizeDict = notification.object as? [String: CGFloat],
              let width = sizeDict["width"],
              let height = sizeDict["height"],
              let window = self.window else { return }
        
        let newSize = NSSize(width: width, height: height)
        guard window.frame.size != newSize else { return }
        
        // 保持右上角固定，向下/向左延伸
        let currentFrame = window.frame
        let newX = currentFrame.maxX - width
        let newY = currentFrame.maxY - height
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().setFrame(NSRect(x: newX, y: newY, width: width, height: height), display: true)
        }
    }
    
    func windowWillMove(_ notification: Notification) {
        dragState.isDragging = true 
    }
    
    func windowDidMove(_ notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.dragState.isDragging = false
        }
    }
    
    func positionOnRightEdge() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let width: CGFloat = 350 + 80 // 預設寬度 + 陰影空間
        let height: CGFloat = 650 + 80 // 預設高度 + 陰影空間
        let x = screenFrame.maxX - width - 20
        let y = screenFrame.maxY - height - 20
        window?.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
    }
    
    func show() {
        window?.alphaValue = 0
        window?.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.4
            window?.animator().alphaValue = 1.0
        }
    }
    
    func hide() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            window?.animator().alphaValue = 0
        }, completionHandler: {
            self.window?.orderOut(nil)
        })
    }

    required init?(coder: NSCoder) { fatalError() }
}

struct DesktopContentView: View {
    @ObservedObject var viewModel: CalendarViewModel
    @ObservedObject var dragState: DesktopWindowController.DragState
    var body: some View {
        CalendarPopoverView(viewModel: viewModel, dragState: dragState)
    }
}
