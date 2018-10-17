//
//  Copyright © 2018 Gnosis Ltd. All rights reserved.
//

import UIKit
import Kingfisher

public class TextInput: UITextField {

    private let clearButton = UIButton(type: .custom)
    private let padding: CGFloat = 14

    public var isDimmed: Bool = false {
        didSet {
            updateAdjustableUI()
        }
    }

    public var leftImage: UIImage? {
        didSet {
            updateImage()
        }
    }

    /// To use this property the one should set leftImage first containing image placeholder.
    public var leftImageURL: URL? {
        didSet {
            guard imageView != nil else { return }
            updateImageView(url: leftImageURL)
        }
    }

    func updateImageView(url: URL?) {
        imageView?.kf.setImage(with: url)
    }

    private var imageView: UIImageView?

    public override var placeholder: String? {
        didSet {
            updatePlaceholder()
        }
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    public override func awakeFromNib() {
        super.awakeFromNib()
        commonInit()
    }

    private func commonInit() {
        heightAnchor.constraint(equalToConstant: 50).isActive = true
        font = UIFont.systemFont(ofSize: 17)
        configureBorder()
        addCustomClearButton()
        updateAdjustableUI()
    }

    private func configureBorder() {
        layer.borderWidth = 1
        layer.cornerRadius = 6
        layer.borderColor = UIColor.white.cgColor
    }

    private func addCustomClearButton() {
        clearButton.accessibilityIdentifier = "Clear text"
        clearButton.frame = CGRect(x: 0, y: 0, width: 14, height: 14)
        clearButton.addTarget(self, action: #selector(clearText), for: .touchUpInside)
        rightView = clearButton
        rightViewMode = .whileEditing
    }

    @objc private func clearText() {
        if delegate?.textFieldShouldClear?(self) ?? true {
            text = ""
        }
    }

    private func updateAdjustableUI() {
        updateBackgroundAndText()
        updatePlaceholder()
        updateButton()
    }

    private func updateBackgroundAndText() {
        if isDimmed {
            backgroundColor = UIColor.white.withAlphaComponent(0.4)
            textColor = .white
            tintColor = ColorName.lightishBlue.color
        } else {
            backgroundColor = .white
            textColor = ColorName.battleshipGrey.color
            tintColor = ColorName.battleshipGrey.color
        }
    }

    private func updatePlaceholder() {
        let color = isDimmed ? .white : ColorName.blueyGrey.color
        attributedPlaceholder = NSAttributedString(
            string: placeholder != nil ?  placeholder! : "",
            attributes: [NSAttributedString.Key.foregroundColor: color])
    }

    private func updateButton() {
        let image = isDimmed ? Asset.TextInputs.tmpClose.image : Asset.TextInputs.tmpCloseGray.image
        clearButton.setImage(image, for: .normal)
    }

    private func updateImage() {
        if let image = leftImage {
            setLeftImageView(with: image)
        } else {
            leftViewMode = UITextField.ViewMode.never
            leftView = nil
        }
    }

    private func setLeftImageView(with image: UIImage) {
        leftViewMode = UITextField.ViewMode.always
        imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 26, height: 26))
        imageView!.contentMode = .scaleAspectFit
        imageView!.image = image
        leftView = imageView!
    }

    override public func leftViewRect(forBounds bounds: CGRect) -> CGRect {
        var leftRect = super.leftViewRect(forBounds: bounds)
        leftRect.origin.x += padding
        return leftRect
    }

    public override func rightViewRect(forBounds bounds: CGRect) -> CGRect {
        var rightRect = super.rightViewRect(forBounds: bounds)
        rightRect.origin.x -= padding / 2
        return rightRect
    }

    public override func textRect(forBounds bounds: CGRect) -> CGRect {
        let textRect = super.textRect(forBounds: bounds)
        return paddedRect(from: textRect)
    }

    public override func editingRect(forBounds bounds: CGRect) -> CGRect {
        let editingRect = super.editingRect(forBounds: bounds)
        return paddedRect(from: editingRect)
    }

    private func paddedRect(from rect: CGRect) -> CGRect {
        let xPadding = leftImage == nil ? padding : 0
        let resultingRect = CGRect(
            x: rect.origin.x + xPadding,
            y: rect.origin.y,
            width: rect.width - xPadding,
            height: rect.height)
        return resultingRect
    }

}
