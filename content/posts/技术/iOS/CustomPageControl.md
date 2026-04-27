+++
date = '2026-04-27T22:13:06+08:00'
draft = false
title = 'CustomPageControl'
tags = ["iOS"]
categories = ["iOS"]

# cover: https://picsum.photos/1920/1080 随机每次刷新页面都会更改
cover = "https://picsum.photos/seed/2026-04-27T22:13:06+08:00/1920/1080"
+++

# CustomPageControl

效果:
![custom page control](/images/custom-pagecontrol.png)

```swift
import UIKit

/// A lightweight page control that supports custom dot spacing/size and tap-to-select.
/// Designed to be iOS 14 compatible (no private subview hacks).
final class CustomPageControl: UIControl {

    var animationDuration: CFTimeInterval = 0.28
    var animationTimingFunction: CAMediaTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

    var numberOfPages: Int = 0 {
        didSet {
            if numberOfPages < 0 { numberOfPages = 0 }
            if currentPage >= numberOfPages { currentPage = max(0, numberOfPages - 1) }
            rebuildDots()
        }
    }

    var currentPage: Int = 0 {
        didSet {
            guard oldValue != currentPage else { return }
            if currentPage < 0 { currentPage = 0 }
            if currentPage >= numberOfPages { currentPage = max(0, numberOfPages - 1) }
            invalidateIntrinsicContentSize()
            animateToCurrentState()
        }
    }

    func setCurrentPage(_ page: Int, animated: Bool) {
        let clamped = max(0, min(page, max(0, numberOfPages - 1)))
        guard clamped != currentPage else { return }
        if animated {
            currentPage = clamped
        } else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            currentPage = clamped
            updateDotAppearance(animated: false)
            layoutDots(animated: false)
            CATransaction.commit()
        }
    }

    var dotSize: CGSize = CGSize(width: 7, height: 7) {
        didSet {
            dotSize.width = max(1, dotSize.width)
            dotSize.height = max(1, dotSize.height)
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    var dotSpacing: CGFloat = 8 {
        didSet {
            dotSpacing = max(0, dotSpacing)
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    /// Width for the current page indicator. Height follows `dotSize.height`.
    var currentDotWidth: CGFloat = 18 {
        didSet {
            currentDotWidth = max(dotSize.width, currentDotWidth)
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    var inactiveTintColor: UIColor = UIColor.secondaryLabel.withAlphaComponent(0.35) {
        didSet { updateDotAppearance(animated: false) }
    }

    var activeTintColor: UIColor = .label {
        didSet { updateDotAppearance(animated: false) }
    }

    var hidesForSinglePage: Bool = true {
        didSet { updateHiddenState() }
    }

    private var dotLayers: [CALayer] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        isAccessibilityElement = true
        accessibilityTraits = [.adjustable]
        backgroundColor = .clear
        rebuildDots()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        isAccessibilityElement = true
        accessibilityTraits = [.adjustable]
        backgroundColor = .clear
        rebuildDots()
    }

    override var intrinsicContentSize: CGSize {
        guard numberOfPages > 0 else { return CGSize(width: 1, height: max(1, dotSize.height)) }
        let baseW = CGFloat(numberOfPages) * dotSize.width
        let spacingW = CGFloat(max(0, numberOfPages - 1)) * dotSpacing
        let extraCurrent = max(0, currentDotWidth - dotSize.width)
        return CGSize(width: ceil(baseW + spacingW + extraCurrent), height: ceil(dotSize.height))
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutDots(animated: false)
    }

    // MARK: - Interaction

    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        let x = touch.location(in: self).x
        setCurrentPage(fromTapX: x, shouldSend: false)
        return true
    }

    override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        let x = touch.location(in: self).x
        setCurrentPage(fromTapX: x, shouldSend: false)
        return true
    }

    override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        guard let touch else { return }
        setCurrentPage(fromTapX: touch.location(in: self).x, shouldSend: true)
    }

    private func setCurrentPage(fromTapX x: CGFloat, shouldSend: Bool) {
        guard numberOfPages > 0 else { return }
        let frames = dotFrames()
        guard let idx = frames.enumerated().min(by: { abs($0.element.midX - x) < abs($1.element.midX - x) })?.offset else {
            return
        }
        if idx != currentPage {
            setCurrentPage(idx, animated: true)
            if shouldSend {
                sendActions(for: .valueChanged)
            }
        } else if shouldSend {
            // Still send for parity with UIPageControl tap behavior
            sendActions(for: .valueChanged)
        }
    }

    // MARK: - Accessibility

    override var accessibilityValue: String? {
        get { "\(currentPage + 1) / \(max(1, numberOfPages))" }
        set { /* ignore */ }
    }

    override func accessibilityIncrement() {
        guard numberOfPages > 0 else { return }
        currentPage = min(numberOfPages - 1, currentPage + 1)
        sendActions(for: .valueChanged)
    }

    override func accessibilityDecrement() {
        guard numberOfPages > 0 else { return }
        currentPage = max(0, currentPage - 1)
        sendActions(for: .valueChanged)
    }

    // MARK: - Private

    private func updateHiddenState() {
        isHidden = hidesForSinglePage && numberOfPages <= 1
    }

    private func rebuildDots() {
        dotLayers.forEach { $0.removeFromSuperlayer() }
        dotLayers.removeAll()

        guard numberOfPages > 0 else {
            updateHiddenState()
            invalidateIntrinsicContentSize()
            setNeedsLayout()
            return
        }

        for _ in 0..<numberOfPages {
            let l = CALayer()
            layer.addSublayer(l)
            dotLayers.append(l)
        }
        updateHiddenState()
        updateDotAppearance(animated: false)
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    private func updateDotAppearance(animated: Bool) {
        guard dotLayers.count == numberOfPages else { return }

        CATransaction.begin()
        CATransaction.setDisableActions(!animated)
        if animated {
            CATransaction.setAnimationDuration(animationDuration)
            CATransaction.setAnimationTimingFunction(animationTimingFunction)
        }

        for (idx, l) in dotLayers.enumerated() {
            l.backgroundColor = (idx == currentPage ? activeTintColor : inactiveTintColor).cgColor
            l.cornerRadius = dotSize.height / 2
        }

        CATransaction.commit()
    }

    private func animateToCurrentState() {
        CATransaction.begin()
        CATransaction.setAnimationDuration(animationDuration)
        CATransaction.setAnimationTimingFunction(animationTimingFunction)
        CATransaction.setDisableActions(false)
        updateDotAppearance(animated: true)
        layoutDots(animated: true)
        CATransaction.commit()
    }

    private func layoutDots(animated: Bool) {
        guard dotLayers.count == numberOfPages, numberOfPages > 0 else { return }

        let frames = dotFrames()
        CATransaction.begin()
        CATransaction.setDisableActions(!animated)
        if animated {
            CATransaction.setAnimationDuration(animationDuration)
            CATransaction.setAnimationTimingFunction(animationTimingFunction)
        }
        for (idx, f) in frames.enumerated() {
            dotLayers[idx].frame = f
            dotLayers[idx].cornerRadius = f.height / 2
        }
        CATransaction.commit()
    }

    private func dotFrames() -> [CGRect] {
        guard numberOfPages > 0 else { return [] }

        let totalW = intrinsicContentSize.width
        let startX = (bounds.width - totalW) / 2
        let y = (bounds.height - dotSize.height) / 2

        var frames: [CGRect] = []
        frames.reserveCapacity(numberOfPages)

        var x = startX
        for idx in 0..<numberOfPages {
            let w = (idx == currentPage) ? currentDotWidth : dotSize.width
            frames.append(CGRect(x: x, y: y, width: w, height: dotSize.height))
            x += w + dotSpacing
        }
        return frames
    }
}


```

