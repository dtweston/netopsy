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

        let searchImage = NSImage(named: NSImage.Name.actionTemplate)!
        searchButton = NSButton()
        searchButton.image = searchImage

        let filter1Image = NSImage(named: .bookmarksTemplate)!
        let filter2Image = NSImage(named: .bluetoothTemplate)!
        filter1Button = NSButton()
        filter1Button.image = filter1Image
        filter2Button = NSButton()
        filter2Button.image = filter2Image

        super.init(frame: frameRect)

        self.addSubview(searchButton)
        self.addSubview(searchField)
        self.addSubview(filter1Button)
        self.addSubview(filter2Button)

        let views: [String: NSView] = ["search": searchButton,
                                       "text": searchField,
                                       "filter1": filter1Button,
                                       "filter2": filter2Button]
        for view in views.values {
            view.translatesAutoresizingMaskIntoConstraints = false
        }
        self.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[search][text(>=40)][filter1][filter2]|", options: .alignAllCenterY, metrics: nil, views: views))
    }
}

let container = NSBox(frame: NSRect(x: 0, y: 0, width: 300, height: 80))
container.boxType = .custom
container.fillColor = .systemBlue

PlaygroundPage.current.liveView = container

let img = #imageLiteral(resourceName: "inspiration.png")
let imgView = NSImageView(image: img)
imgView.translatesAutoresizingMaskIntoConstraints = false
imgView.frame = NSRect(origin: NSPoint(x: 0, y: 30), size: img.size)
container.addSubview(imgView)

let searchField = CustomSearchField(frame: NSRect(x: 0, y: 0, width: 230, height: 20))
container.addSubview(searchField)

let views = ["image": imgView, "search": searchField]
container.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-[search]-|", options: .alignAllFirstBaseline, metrics: nil, views: views))


