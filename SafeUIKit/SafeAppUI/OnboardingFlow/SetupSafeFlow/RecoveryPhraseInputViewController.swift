//
//  Copyright © 2018 Gnosis Ltd. All rights reserved.
//

import UIKit
import MultisigWalletApplication

protocol RecoveryPhraseInputViewControllerDelegate: class {

    func recoveryPhraseInputViewControllerDidPressNext()

}

class RecoveryPhraseInputViewController: BaseInputViewController {

    @IBOutlet weak var pasteButton: UIButton!
    @IBOutlet weak var phraseTextView: UITextView!
    var keyboardBehavior: KeyboardAvoidingBehavior!
    weak var delegate: RecoveryPhraseInputViewControllerDelegate?

    override var headerText: String {
        return LocalizedString("recovery.phrase.header", comment: "Recovery Phrase Input screen header")
    }

    override var actionFailureMessageFormat: String {
        return LocalizedString("recovery.phrase.error.format", comment: "Error format for invalid recovery phrase")
    }

    static let maxInputLength: Int = 500
    var placeholder: String = LocalizedString("recovery.phrase.placeholder",
                                              comment: "Placeholder for the recovery phrase")

    var text: String? {
        didSet {
            update()
        }
    }

    @IBOutlet weak var placeholderLabel: UILabel!
    @IBOutlet weak var placeholderTop: NSLayoutConstraint!
    @IBOutlet weak var placeholderTrailing: NSLayoutConstraint!
    @IBOutlet weak var placeholderLeading: NSLayoutConstraint!

    static func create(delegate: RecoveryPhraseInputViewControllerDelegate?) -> RecoveryPhraseInputViewController {
        let controller = StoryboardScene.RecoverSafe.recoveryPhraseInputViewController.instantiate()
        controller.delegate = delegate
        return controller
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        keyboardBehavior = KeyboardAvoidingBehavior(scrollView: scrollView)
        let insets = textInsets()
        placeholderTop.constant = insets.top
        placeholderLeading.constant = insets.left
        placeholderTrailing.constant = insets.right
        placeholderLabel.textColor = ColorName.darkSlateBlue.color.withAlphaComponent(0.7)
        view.setNeedsUpdateConstraints()
        update()
    }

    private func textInsets() -> UIEdgeInsets {
        var insets = phraseTextView.textContainerInset
        insets.left += phraseTextView.textContainer.lineFragmentPadding
        insets.right += phraseTextView.textContainer.lineFragmentPadding
        switch Locale.lineDirection(forLanguage: Locale.autoupdatingCurrent.languageCode ?? "en_US") {
        case .leftToRight, .topToBottom, .unknown:
            return insets
        case .rightToLeft:
            let tmp = insets.left
            insets.left = insets.right
            insets.right = tmp
            return insets
        case .bottomToTop:
            let tmp = insets.bottom
            insets.bottom = insets.top
            insets.top = tmp
            return insets
        }
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        keyboardBehavior.start()
    }

    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        keyboardBehavior.stop()
    }

    @IBAction func pasteFromClipboard(_ sender: Any) {
        if let value = UIPasteboard.general.string {
            text = value
        }
    }

    func update() {
        guard isViewLoaded else { return }
        phraseTextView.text = text
        updateTextDependentViews(with: text)
    }

    func updateTextDependentViews(with rawText: String?) {
        let text = (rawText ?? "")
        placeholderLabel.isHidden = !text.isEmpty
        nextButtonItem.isEnabled = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    override func next(_ sender: Any) {
        disableNextAction()
        startActivityIndicator()
        let phrase = safeUserInputText()
        DispatchQueue.global().async {
            let service = ApplicationServiceRegistry.recoveryService
            service.provide(recoveryPhrase: phrase, subscriber: self) { [weak self] error in
                guard let `self` = self else { return }
                DispatchQueue.main.async {
                    self.stopActivityIndicator()
                    self.enableNextAction()
                    self.show(error: error)
                }
            }
        }
    }

    private func safeUserInputText() -> String {
        return String((phraseTextView.text ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(RecoveryPhraseInputViewController.maxInputLength))
    }

    override func didUpdateFromAction() {
        DispatchQueue.main.async { [weak self] in
            guard let `self` = self else { return }
            self.stopActivityIndicator()
            self.enableNextAction()
            self.delegate?.recoveryPhraseInputViewControllerDidPressNext()
        }
    }

}

extension RecoveryPhraseInputViewController: UITextViewDelegate {

    func textViewDidBeginEditing(_ textView: UITextView) {
        keyboardBehavior.activeTextView = textView
    }

    func textViewDidChange(_ textView: UITextView) {
        updateTextDependentViews(with: textView.text)
    }

}
