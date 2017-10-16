import Cocoa
import PlaygroundSupport

class CustomSearchField: NSControl {
    let searchButton: NSButton
    let searchField: NSTextField
    let filter1Button: NSButton
    let filter2Button: NSButton

    required init?(coder: NSCoder) {
        fatalError()
    }

    override init(frame frameRect: NSRect) {
        searchField = NSTextField()
        searchField.drawsBackground = false
        searchField.isBordered = false
        searchField.placeholderString = "Filter"

        let searchImage = #imageLiteral(resourceName: "filter.png")
        let searchSelectedImage = #imageLiteral(resourceName: "selected-filter.png")
        searchImage.isTemplate = true
        searchButton = NSButton()
        searchButton.image = searchImage
        searchButton.alternateImage = searchSelectedImage
        searchButton.isBordered = false
        searchButton.setButtonType(.toggle)

        let filter1Image = NSImage(named: .bookmarksTemplate)!
        let filter2Image = NSImage(named: .bluetoothTemplate)!
        filter1Button = NSButton()
        filter1Button.image = filter1Image
        filter1Button.isBordered = false
        filter2Button = NSButton()
        filter2Button.image = filter2Image
        filter2Button.isBordered = false

        super.init(frame: frameRect)

        addSubview(searchButton)
        addSubview(searchField)
        addSubview(filter1Button)
        addSubview(filter2Button)

        let views: [String: NSView] = ["search": searchButton,
                                       "text": searchField,
                                       "filter1": filter1Button,
                                       "filter2": filter2Button]
        for view in views.values {
            view.translatesAutoresizingMaskIntoConstraints = false
        }
//        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[search][text(>=40)][filter1][filter2]|", options: .alignAllCenterY, metrics: nil, views: views))
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-5-[search]-3-[text(>=40)]-3-[filter1]-3-[filter2]-5-|", options: .alignAllCenterY, metrics: nil, views: views))
        searchButton.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let border = NSBezierPath(roundedRect: dirtyRect.insetBy(dx: 1, dy: 1), xRadius: 3, yRadius: 3)
        border.lineWidth = 1
        NSColor.controlShadowColor.setStroke()
        NSColor.controlColor.setFill()
        border.fill()
        border.stroke()
    }
}

let container = NSBox(frame: NSRect(x: 0, y: 0, width: 300, height: 80))
container.boxType = .custom
container.fillColor = .controlColor

PlaygroundPage.current.liveView = container

let img = #imageLiteral(resourceName: "inspiration.png")
let imgView = NSImageView(image: img)
imgView.translatesAutoresizingMaskIntoConstraints = false
imgView.frame = NSRect(origin: NSPoint(x: 0, y: 30), size: img.size)
container.addSubview(imgView)

let searchField = CustomSearchField(frame: NSRect(x: 0, y: 0, width: 230, height: 25))
container.addSubview(searchField)

let views = ["image": imgView, "search": searchField]
container.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-[search]-|", options: .alignAllFirstBaseline, metrics: nil, views: views))



