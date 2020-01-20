//
//  ViewController.swift
//  TestTraitCollectionOverriding
//
//  Created by Chris Hawkins on 12/10/19.
//  Copyright © 2019 Trade Me. All rights reserved.
//

import UIKit

class TraitLoggingViewController: UITableViewController {
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return tableView.dequeueReusableCell(withIdentifier: "cell")!
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        print("-----")
        print("[TRAITS CHANGED] view controller: \(previousTraitCollection?.preferredContentSizeCategory.rawValue ?? "nil") -> \(traitCollection.preferredContentSizeCategory.rawValue)")
    }
}

class TraitLoggingTableView: UITableView {
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        print("[TRAITS CHANGED] table view: \(previousTraitCollection?.preferredContentSizeCategory.rawValue ?? "nil") -> \(traitCollection.preferredContentSizeCategory.rawValue)")
    }
}

class TraitLoggingCell: UITableViewCell {
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        print("[TRAITS CHANGED] cell: \(previousTraitCollection?.preferredContentSizeCategory.rawValue ?? "nil") -> \(traitCollection.preferredContentSizeCategory.rawValue)")
    }
}

class TraitLoggingLabel: UILabel {
    
//    override func didMoveToSuperview() {
//        super.didMoveToSuperview()
//        refreshFontIfNecessary()
//    }
//
//    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
//        super.traitCollectionDidChange(previousTraitCollection)
//        print("[TRAITS CHANGED] label: \(previousTraitCollection?.preferredContentSizeCategory.rawValue ?? "nil") -> \(traitCollection.preferredContentSizeCategory.rawValue)")
//        refreshFontIfNecessary()
//    }
//
//    private func refreshFontIfNecessary() {
//        guard let textStyle = font.fontDescriptor.object(forKey: .textStyle) as? UIFont.TextStyle else { return }
//
//        let recreatedFont = UIFont.preferredFont(forTextStyle: textStyle, compatibleWith: traitCollection)
//        if (abs(recreatedFont.pointSize - font.pointSize) > 0.5) {
//            self.font = recreatedFont
//        }
//    }
}

class CustomNavigationController: UINavigationController {
    override func overrideTraitCollection(forChild childViewController: UIViewController) -> UITraitCollection? {
        
        return .init(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge)
    }
}

@objc
extension UIView {

    /// Apple provides APIs for overriding trait collections for children
    /// In theory this API lets us override the preferrredContentSizeCategory to enforce a particular type size
    /// This is useful as it allows us to turn on dynamic type support screen by screen
    /// Unfortunately there is a major issue post Xcode11 where labels seem to believe their fonts are up to date even after overriding the trait collection
    ///
    /// To get around this we swizzle methods on UILabel to detect when this case occured and recreate a new font to convince UILabel to update.
    /// Chris has opened a radar (FB7538707) and hopefully this gets addressed so this hack can get deleted
    /// Anyway this hack is actually pretty straightforward
    static func swizzleToFixFontScalingInXcode11() {
        do {
            let originalSelector = #selector(UIView.didMoveToSuperview)
            let swizzledSelector = #selector(UIView.swizzled_didMoveToSuperview)
            
            guard let originalMethod = class_getInstanceMethod(self, originalSelector), let swizzledMethod = class_getInstanceMethod(self, swizzledSelector) else { return assertionFailure("Couldn't swizzle method") }
            
            method_exchangeImplementations(originalMethod, swizzledMethod)
        }
        do {
            let originalSelector = #selector(UIView.traitCollectionDidChange(_:))
            let swizzledSelector = #selector(UIView.swizzled_traitCollectionDidChange(_:))
            
            guard let originalMethod = class_getInstanceMethod(self, originalSelector), let swizzledMethod = class_getInstanceMethod(self, swizzledSelector) else { return assertionFailure("Couldn't swizzle method") }
            
            method_exchangeImplementations(originalMethod, swizzledMethod)
        }
    }
    
    
    @objc
    private func swizzled_didMoveToSuperview() {
        swizzled_didMoveToSuperview() // old/base implementation
        refreshFontIfNecessary()
    }
    
    @objc
    private func swizzled_traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        swizzled_traitCollectionDidChange(previousTraitCollection) // old/base implementation
        refreshFontIfNecessary()
    }
    
    private func refreshFontIfNecessary() {
        guard let textElement = self as? TextElement else { return }
        
        // Pull out the font and try recreate it
        guard let textStyle = textElement.font.fontDescriptor.object(forKey: .textStyle) as? UIFont.TextStyle else { return }
        let recreatedFont = UIFont.preferredFont(forTextStyle: textStyle, compatibleWith: traitCollection)
        
        // If our reacreated font and actual font differ in size we've hit Apple's UITraitCollection propogation but (see documentation in swizzleToFixFontScalingInXcode11)
        if (abs(recreatedFont.pointSize - textElement.font.pointSize) > 0.5) {
            textElement.font = recreatedFont
        }
    }
}

@objc
fileprivate protocol TextElement {
    var font: UIFont! { get set }
}

extension UITextView: TextElement { }
extension UILabel: TextElement { }
extension UITextField: TextElement { }
