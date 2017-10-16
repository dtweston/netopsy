import Cocoa
import PlaygroundSupport

extension NSImage.Name {
    static let inspiration = NSImage.Name("inspiration.png")
}

protocol CustomSearchTextFieldDelegate: class {
    func textFieldDidBecomeFirstResponder(_ textField: NSTextField)
}

class CustomSearchTextField: NSTextField {
    weak var customDelegate: CustomSearchTextFieldDelegate?

    override func becomeFirstResponder() -> Bool {
        let didAccept = super.becomeFirstResponder()
        if didAccept {
            customDelegate?.textFieldDidBecomeFirstResponder(self)
        }
        return didAccept
    }
}

class CustomSearchField: NSControl, NSTextFieldDelegate, CustomSearchTextFieldDelegate {
    let searchButton: NSButton
    let searchField: CustomSearchTextField
    let filter1Button: NSButton
    let filter2Button: NSButton

    required init?(coder: NSCoder) {
        fatalError()
    }

    var backgroundColor: NSColor

    override init(frame frameRect: NSRect) {
        searchField = CustomSearchTextField()
        searchField.font = NSFont.systemFont(ofSize: NSFont.systemFontSize(for: .small))
        searchField.frame = frameRect.insetBy(dx: 22, dy: 3)
        searchField.focusRingType = .none
        searchField.placeholderString = "Filter"
//        searchField.controlSize = .small
        searchField.isBordered = false
        searchField.drawsBackground = false
        searchField.usesSingleLineMode = true
        searchField.maximumNumberOfLines = 1

        backgroundColor = .controlColor

        let searchImage = NSImage(named: NSImage.Name.actionTemplate)!
        searchButton = NSButton(frame: NSRect(x: 0, y: 0, width: 25, height: 20))
        searchButton.image = searchImage
        searchButton.isBordered = false
        searchButton.setButtonType(.momentaryChange)

        let filter1Image = NSImage(named: .bookmarksTemplate)!
        let filter2Image = NSImage(named: .bluetoothTemplate)!
        filter1Button = NSButton(frame: NSRect(x: 210, y: 0, width: 25, height: 20))
        filter1Button.image = filter1Image
        filter1Button.isBordered = false
        filter1Button.setButtonType(.momentaryChange)
        filter2Button = NSButton(frame: NSRect(x: 225, y: 0, width: 25, height: 20))
        filter2Button.image = filter2Image
        filter2Button.isBordered = false
        filter2Button.setButtonType(.momentaryChange)

//        searchButton.highlight(true)

        super.init(frame: frameRect)

        NotificationCenter.default.addObserver(self, selector: #selector(controlTextDidBeginEditing), name: NSControl.textDidEndEditingNotification, object: searchField)
        searchField.delegate = self
        searchField.customDelegate = self
        self.addSubview(searchButton)
        self.addSubview(searchField)
        self.addSubview(filter1Button)
        self.addSubview(filter2Button)
    }

    override func draw(_ dirtyRect: NSRect) {
        let border = NSBezierPath(roundedRect: dirtyRect.insetBy(dx: 0.5, dy: 0.5), xRadius: 3, yRadius: 3)
        border.lineWidth = 0.5
        NSColor.controlShadowColor.setStroke()
        backgroundColor.setFill()
        border.fill()
        border.stroke()
    }

    // MARK: - CustomSearchTextFieldDelegate method

    func textFieldDidBecomeFirstResponder(_ textField: NSTextField) {
        backgroundColor = .controlBackgroundColor
        setNeedsDisplay()
    }

    // MARK: - NSTextFieldDelegate methods

    override func controlTextDidEndEditing(_ obj: Notification) {
        backgroundColor = .controlColor
        setNeedsDisplay()
    }
}

let container = NSBox(frame: NSRect(x: 0, y: 0, width: 300, height: 80))
container.boxType = .custom
container.fillColor = .controlColor

let img = NSImage(named: .inspiration)!
let imgView = NSImageView(image: img)
imgView.translatesAutoresizingMaskIntoConstraints = false
imgView.frame = NSRect(origin: NSPoint(x: 0, y: 30), size: img.size)
container.addSubview(imgView)

PlaygroundPage.current.liveView = container

let searchField = CustomSearchField(frame: NSRect(x: 0, y: 0, width: 250, height: 20))
container.addSubview(searchField)

let views = ["image": imgView, "search": searchField]
//container.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-[image]-[search]-|", options: .alignAllCenterX, metrics: nil, views: views))
container.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-[search]-|", options: .alignAllFirstBaseline, metrics: nil, views: views))

