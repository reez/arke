//
//  BitcoinAddressField.swift
//  Ark wallet prototype
//
//  Created by Assistant on 3/25/26.
//

import SwiftUI

#if os(iOS)
import UIKit

struct BitcoinAddressField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    @FocusState.Binding var isFocused: Bool
    
    func makeUIView(context: Context) -> DynamicHeightTextView {
        let textView = DynamicHeightTextView()
        textView.delegate = context.coordinator
        textView.font = .monospacedSystemFont(ofSize: 17, weight: .regular)
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.textContentType = nil
        textView.backgroundColor = .clear
        textView.textColor = .label
        textView.isScrollEnabled = false
        textView.textContainer.lineBreakMode = .byCharWrapping
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.placeholderText = placeholder
        
        // Disable autocomplete bar and smart features
        textView.smartQuotesType = .no
        textView.smartDashesType = .no
        textView.smartInsertDeleteType = .no
        
        // Change return key to Done and dismiss keyboard on return
        textView.returnKeyType = .done
        
        // Remove the empty input accessory bar
        textView.inputAccessoryView = nil
        
        // Disable hyphenation and increase line height
        let style = NSMutableParagraphStyle()
        style.hyphenationFactor = 0
        style.lineBreakMode = .byCharWrapping
        style.lineSpacing = 4
        style.minimumLineHeight = 24
        textView.typingAttributes = [
            .paragraphStyle: style,
            .font: UIFont.monospacedSystemFont(ofSize: 17, weight: .regular)
        ]
        
        return textView
    }
    
    func updateUIView(_ uiView: DynamicHeightTextView, context: Context) {
        print("📱 [iOS] updateUIView called - text: '\(text)', isFirstResponder: \(uiView.isFirstResponder), isUpdatingText: \(context.coordinator.isUpdatingText), isFocused binding: \(isFocused)")
        
        // Update placeholder
        uiView.placeholderText = placeholder
        
        // Prevent any programmatic updates while user is actively editing
        if context.coordinator.isUpdatingText {
            print("📱 [iOS] Early return: isUpdatingText")
            return
        }
        
        // Only update text if it's different and not currently being edited by user
        if uiView.text != text {
            print("📱 [iOS] Text mismatch - view: '\(uiView.text ?? "")', binding: '\(text)'")
            // If user is actively typing, don't update the text from binding
            if uiView.isFirstResponder {
                print("📱 [iOS] Early return: isFirstResponder")
                return
            }
            
            print("📱 [iOS] Updating text from binding")
            uiView.text = text
            // Reapply paragraph style when text changes
            if let style = uiView.typingAttributes[.paragraphStyle] as? NSParagraphStyle {
                uiView.textStorage.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: uiView.text.count))
            }
        }
        
        // Update focus state only if there's a mismatch
        // BUT: never resign first responder if view is actually first responder
        // (binding might be out of sync due to timing issues)
        if isFocused != uiView.isFirstResponder {
            print("📱 [iOS] Focus mismatch - binding: \(isFocused), view: \(uiView.isFirstResponder)")
            if isFocused && !uiView.isFirstResponder {
                print("📱 [iOS] Calling becomeFirstResponder")
                uiView.becomeFirstResponder()
            } else if !isFocused && uiView.isFirstResponder {
                print("📱 [iOS] WARNING: Binding says not focused but view IS first responder - ignoring resignFirstResponder")
                // Don't resign - the view knows better than the binding
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, isFocused: $isFocused)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        @Binding var text: String
        @FocusState.Binding var isFocused: Bool
        var isUpdatingText = false
        
        init(text: Binding<String>, isFocused: FocusState<Bool>.Binding) {
            _text = text
            _isFocused = isFocused
        }
        
        func textViewDidChange(_ textView: UITextView) {
            print("📱 [iOS] textViewDidChange - text: '\(textView.text ?? "")', isUpdatingText: \(isUpdatingText), isFirstResponder: \(textView.isFirstResponder)")
            guard !isUpdatingText else {
                print("📱 [iOS] textViewDidChange skipped - already updating")
                return
            }
            
            // If text view is first responder but focus binding is false, fix it
            if textView.isFirstResponder && !isFocused {
                print("📱 [iOS] textViewDidChange - fixing focus mismatch, setting isFocused = true")
                isFocused = true
            }
            
            // Use a flag and batch the update to prevent re-entrancy
            isUpdatingText = true
            defer { isUpdatingText = false }
            
            print("📱 [iOS] textViewDidChange - updating binding")
            // Update the binding without triggering view updates
            DispatchQueue.main.async { [weak self] in
                print("📱 [iOS] textViewDidChange async - setting text binding")
                self?.text = textView.text
            }
        }
        
        func textViewDidBeginEditing(_ textView: UITextView) {
            print("📱 [iOS] textViewDidBeginEditing - isFocused was: \(isFocused)")
            if !isFocused {
                print("📱 [iOS] textViewDidBeginEditing - setting isFocused = true (synchronously)")
                isFocused = true
            }
        }
        
        func textViewDidEndEditing(_ textView: UITextView) {
            print("📱 [iOS] textViewDidEndEditing")
            DispatchQueue.main.async { [weak self] in
                print("📱 [iOS] textViewDidEndEditing async - isFocused was: \(self?.isFocused ?? false)")
                if self?.isFocused == true {
                    print("📱 [iOS] textViewDidEndEditing async - setting isFocused = false")
                    self?.isFocused = false
                }
            }
        }
        
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            // If the user presses return, dismiss the keyboard instead of inserting a newline
            if text == "\n" {
                textView.resignFirstResponder()
                return false
            }
            
            // Prevent spaces from being entered
            if text.contains(" ") {
                return false
            }
            
            // Enforce 500 character limit
            let currentText = textView.text ?? ""
            let proposedText = (currentText as NSString).replacingCharacters(in: range, with: text)
            if proposedText.count > 500 {
                return false
            }
            
            return true
        }
    }
}

// Custom UITextView that grows with content and shows placeholder
class DynamicHeightTextView: UITextView {
    var placeholderText: String = "" {
        didSet {
            setNeedsDisplay()
        }
    }
    
    override var text: String! {
        didSet {
            setNeedsDisplay()
        }
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        if text.isEmpty && !placeholderText.isEmpty {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font ?? UIFont.monospacedSystemFont(ofSize: 17, weight: .regular),
                .foregroundColor: UIColor.placeholderText
            ]
            
            let placeholderRect = CGRect(
                x: textContainerInset.left,
                y: textContainerInset.top,
                width: bounds.width - textContainerInset.left - textContainerInset.right,
                height: bounds.height - textContainerInset.top - textContainerInset.bottom
            )
            
            placeholderText.draw(in: placeholderRect, withAttributes: attributes)
        }
    }
    
    override var intrinsicContentSize: CGSize {
        let size = sizeThatFits(CGSize(width: bounds.width, height: .infinity))
        return CGSize(width: UIView.noIntrinsicMetric, height: max(size.height, 22))
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        invalidateIntrinsicContentSize()
    }
}
#elseif os(macOS)
import AppKit

struct BitcoinAddressField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    @FocusState.Binding var isFocused: Bool
    
    func makeNSView(context: Context) -> DynamicHeightTextViewWrapper {
        let wrapper = DynamicHeightTextViewWrapper()
        let textView = wrapper.textView
        
        textView.delegate = context.coordinator
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.textContainer?.lineBreakMode = .byCharWrapping
        textView.textContainer?.lineFragmentPadding = 0
        wrapper.placeholderString = placeholder
        
        // Disable hyphenation
        let style = NSMutableParagraphStyle()
        style.hyphenationFactor = 0
        style.lineBreakMode = .byCharWrapping
        textView.typingAttributes = [
            .paragraphStyle: style,
            .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        ]
        
        return wrapper
    }
    
    func updateNSView(_ nsView: DynamicHeightTextViewWrapper, context: Context) {
        let textView = nsView.textView
        
        // Update placeholder
        nsView.placeholderString = placeholder
        
        // Prevent any programmatic updates while user is actively editing
        if context.coordinator.isUpdatingText {
            return
        }
        
        // Only update text if it's different and not currently being edited by user
        if textView.string != text {
            // If user is actively typing, don't update the text from binding
            let isCurrentlyFocused = textView.window?.firstResponder == textView
            if isCurrentlyFocused {
                return
            }
            
            textView.string = text
            // Reapply paragraph style when text changes
            if let style = textView.typingAttributes[.paragraphStyle] as? NSParagraphStyle {
                textView.textStorage?.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: textView.string.count))
            }
            nsView.updateHeight()
        }
        
        // Update focus state only if there's a mismatch
        // BUT: never resign first responder if view is actually first responder
        // (binding might be out of sync due to timing issues)
        let isCurrentlyFocused = textView.window?.firstResponder == textView
        if isFocused != isCurrentlyFocused {
            if isFocused && !isCurrentlyFocused {
                textView.window?.makeFirstResponder(textView)
            } else if !isFocused && isCurrentlyFocused {
                // Don't resign - the view knows better than the binding
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, isFocused: $isFocused)
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        @FocusState.Binding var isFocused: Bool
        var isUpdatingText = false
        
        init(text: Binding<String>, isFocused: FocusState<Bool>.Binding) {
            _text = text
            _isFocused = isFocused
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            guard !isUpdatingText else { return }
            
            // Use a flag and batch the update to prevent re-entrancy
            isUpdatingText = true
            defer { isUpdatingText = false }
            
            // Enforce 500 character limit
            if textView.string.count > 500 {
                textView.string = String(textView.string.prefix(500))
            }
            
            // Update height when text changes
            if let wrapper = textView.superview as? DynamicHeightTextViewWrapper {
                wrapper.updateHeight()
            }
            
            // Update the binding without triggering view updates
            DispatchQueue.main.async { [weak self] in
                self?.text = textView.string
            }
        }
        
        func textDidBeginEditing(_ notification: Notification) {
            if !isFocused {
                isFocused = true
            }
        }
        
        func textDidEndEditing(_ notification: Notification) {
            DispatchQueue.main.async { [weak self] in
                if self?.isFocused == true {
                    self?.isFocused = false
                }
            }
        }
    }
}

// Custom wrapper for NSTextView that grows with content
class DynamicHeightTextViewWrapper: NSView {
    let textView: NSTextView
    private var heightConstraint: NSLayoutConstraint?
    private var placeholderLabel: NSTextField?
    
    var placeholderString: String = "" {
        didSet {
            updatePlaceholder()
        }
    }
    
    override init(frame frameRect: NSRect) {
        textView = NSTextView()
        super.init(frame: frameRect)
        
        textView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textView)
        
        // Create placeholder label
        let placeholder = NSTextField()
        placeholder.translatesAutoresizingMaskIntoConstraints = false
        placeholder.isEditable = false
        placeholder.isSelectable = false
        placeholder.isBordered = false
        placeholder.drawsBackground = false
        placeholder.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        placeholder.textColor = .placeholderTextColor
        addSubview(placeholder, positioned: .below, relativeTo: textView)
        placeholderLabel = placeholder
        
        NSLayoutConstraint.activate([
            textView.leadingAnchor.constraint(equalTo: leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: trailingAnchor),
            textView.topAnchor.constraint(equalTo: topAnchor),
            
            placeholder.leadingAnchor.constraint(equalTo: leadingAnchor),
            placeholder.trailingAnchor.constraint(equalTo: trailingAnchor),
            placeholder.topAnchor.constraint(equalTo: topAnchor)
        ])
        
        heightConstraint = heightAnchor.constraint(equalToConstant: 20)
        heightConstraint?.isActive = true
        
        // Observe text changes to update placeholder visibility
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textDidChange),
            name: NSText.didChangeNotification,
            object: textView
        )
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func textDidChange() {
        updatePlaceholder()
    }
    
    private func updatePlaceholder() {
        placeholderLabel?.stringValue = placeholderString
        placeholderLabel?.isHidden = !textView.string.isEmpty
    }
    
    func updateHeight() {
        let contentSize = textView.layoutManager?.usedRect(for: textView.textContainer!).height ?? 20
        let newHeight = max(contentSize, 20)
        heightConstraint?.constant = newHeight
        invalidateIntrinsicContentSize()
    }
    
    override var intrinsicContentSize: NSSize {
        let contentSize = textView.layoutManager?.usedRect(for: textView.textContainer!).height ?? 20
        let height = max(contentSize, 20)
        return NSSize(width: NSView.noIntrinsicMetric, height: height)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
#endif
