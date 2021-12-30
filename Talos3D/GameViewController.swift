//
//  GameViewController.swift
//  Talos3D
//
//  Created by Javier Salcedo on 30/12/21.
//

import Cocoa
import MetalKit

import SimpleLogs

public extension MTKView
{
    override var acceptsFirstResponder: Bool { return true } // Enables keyboard events
}

// Our macOS specific view controller
class GameViewController: NSViewController
{
    var renderer: Renderer!
    var mtkView: MTKView!

    override func viewDidLoad() {
        super.viewDidLoad()

        guard let mtkView = self.view as? MTKView else {
            SimpleLogs.ERROR("View attached to GameViewController is not an MTKView")
            return
        }

        // Select the device to render with.  We choose the default device
        guard let defaultDevice = MTLCreateSystemDefaultDevice() else {
            SimpleLogs.ERROR("Metal is not supported on this device")
            return
        }

        mtkView.device = defaultDevice

        guard let newRenderer = Renderer(metalKitView: mtkView) else {
            SimpleLogs.ERROR("Renderer cannot be initialized")
            return
        }

        renderer = newRenderer

        renderer.mtkView(mtkView, drawableSizeWillChange: mtkView.drawableSize)

        mtkView.delegate = renderer
    }

    override func mouseDragged(with event: NSEvent)
    {
        SimpleLogs.INFO("DRAG")
        // TODO: renderer.onMouseDrag()
    }

    override func keyDown(with event: NSEvent)
    {
        SimpleLogs.INFO("DOWN")
        // TODO: renderer.onKeyDown()
    }
}
