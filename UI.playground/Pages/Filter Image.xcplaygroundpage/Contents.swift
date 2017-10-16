//: [Previous](@previous)

import Foundation
import AppKit
import CoreGraphics
import PlaygroundSupport

var str = "Hello, playground"

//: [Next](@next)


let image = NSImage(size: NSSize(width: 15, height: 15))

image.lockFocus()

NSColor.blue.setStroke()
let circle = NSBezierPath(ovalIn: NSRect(origin: CGPoint(x: 1, y: 1), size: CGSize(width: 12, height: 12)))
circle.lineWidth = 1.5
circle.stroke()

let line1 = NSBezierPath()
line1.move(to: NSPoint(x: 3.5, y: 9))
line1.line(to: NSPoint(x: 10.5, y: 9))
line1.stroke()

let line2 = NSBezierPath()
line2.move(to: NSPoint(x: 4.5, y: 7))
line2.line(to: NSPoint(x: 9.5, y: 7))
line2.stroke()

let line3 = NSBezierPath()
line3.move(to: NSPoint(x: 5.5, y: 5))
line3.line(to: NSPoint(x: 8.5, y: 5))
line3.stroke()

image.unlockFocus()

let fileUrl = playgroundSharedDataDirectory.appendingPathComponent("filter.png")
if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
    let imageRep = NSBitmapImageRep(cgImage: cgImage)
    imageRep.size = image.size
    if let pngData = imageRep.representation(using: .png, properties: [:]) {
        try! pngData.write(to: fileUrl, options: .atomic)
    }
}


