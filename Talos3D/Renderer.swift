//
//  Renderer.swift
//  Talos3D
//
//  Created by Javier Salcedo on 30/12/21.
//
import Foundation
import MetalKit

import SLA
import SimpleLogs

// TODO: Move to a header file in common with the shaders?
let VERTEX_BUFFER_INDEX         = 0
let TRANSFORM_MATRICES_INDEX    = 1
let LIGHTS_BUFFER_INDEX         = 2

let WORLD_UP = Vector3(x:0, y:1, z:0)

let TEST_MODEL_NAME        = "bunny"
let TEST_MODEL_EXTENSION   = "obj"

let TEST_TEXTURE_NAME      = "TestTexture1"
//let TEST_TEXTURE_EXTENSION = "png"

public class Renderer: NSObject, MTKViewDelegate
{

    public  var mView:          MTKView

    private let mCommandQueue:  MTLCommandQueue
    private let mPipelineState: MTLRenderPipelineState
    private var mDepthStencilState: MTLDepthStencilState?

    private var mCamera: Camera!

    private var mModel:         Renderable?
    // TODO: Load textures on demand
    private var mTexture:       MTLTexture?
    // TODO: Pre-built collection?
    private var mSamplerState:  MTLSamplerState?


    // TODO: Make it throw
    public init?(mtkView: MTKView)
    {
        if mtkView.device == nil
        {
            fatalError("NO GPU!")
        }

        mView = mtkView
        mView.depthStencilPixelFormat = MTLPixelFormat.depth16Unorm
        mView.clearDepth              = 1.0
        mView.clearColor              = MTLClearColor(red: 0.25, green: 0.25, blue: 0.25, alpha: 1.0)

        guard let cq = mView.device?.makeCommandQueue() else
        {
            fatalError("Could not create command queue")
        }
        mCommandQueue = cq

        // TODO: Extract initShaders() (Should be loaded alongside the assets? loadMaterials()?)
        guard let library = mView.device?.makeDefaultLibrary() else
        {
            fatalError("Couldn't create shader library!")
        }
        let vertexFunction   = library.makeFunction(name: "vertex_main")
        let fragmentFunction = library.makeFunction(name: "fragment_main")

        // TODO: Read model and transform data from file
        if let modelURL = Bundle.main.url(forResource: TEST_MODEL_NAME,
                                          withExtension: TEST_MODEL_EXTENSION)
        {
            mModel = Model(device: mtkView.device!, url: modelURL)

            let rotDegrees = SLA.rad2deg(0.5 * TAU)
            mModel?.rotate(eulerAngles: Vector3(x: 0, y: rotDegrees, z: 0))
            // mModel?.flipHandedness()
        }
        else
        {
            SimpleLogs.ERROR("Couldn't load model '" + TEST_MODEL_NAME + "." + TEST_MODEL_EXTENSION + "'")
        }

        // TODO: Extract initPSOs()
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
        pipelineDescriptor.vertexFunction                  = vertexFunction
        pipelineDescriptor.fragmentFunction                = fragmentFunction
        pipelineDescriptor.vertexDescriptor                = mModel?.getVertexDescriptor()
        pipelineDescriptor.depthAttachmentPixelFormat      = mView.depthStencilPixelFormat

        guard let ps = try! mView.device?.makeRenderPipelineState(descriptor: pipelineDescriptor) else
        {
            fatalError("Couldn't create pipeline state")
        }
        mPipelineState = ps

        let depthStencilDesc = MTLDepthStencilDescriptor()
        depthStencilDesc.depthCompareFunction = .less
        depthStencilDesc.isDepthWriteEnabled  = true

        mDepthStencilState = mView.device?.makeDepthStencilState(descriptor: depthStencilDesc)

        mCamera = Camera()
        mCamera.move(to: Vector3(x:0.25, y:0.25, z:-0.25))
        mCamera.lookAt(Vector3(x:0, y:0, z:0))

        super.init()

        self.loadTextures()
        self.buildSamplerState()

        mView.delegate = self
    }

    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize)
    {
        let newAspectRatio = Float(size.width / size.height)
        mCamera.updateAspectRatio(newAspectRatio)
    }

    public func onMouseDrag(deltaX: Float, deltaY: Float)
    {
        let d = Vector3(x: deltaY, y: deltaX, z: 0)
        mCamera.rotate(eulerAngles: d)
    }

    public func onScroll(scroll: Float)
    {
        let d = Vector3(x: 0, y: 0, z: scroll)
        mCamera.move(localDirection: d)
    }

    public func onKeyPress(keyCode: UInt16)
    {
        var d = Vector3.zero()
        switch keyCode
        {
            case 0:
//                SimpleLogs.INFO("A")
                d.x = -1
                break

            case 0x02:
//                SimpleLogs.INFO("D")
                d.x = 1
                break

            case 0x01:
//                SimpleLogs.INFO("S")
                d.z = -1
                break

            case 0x0D:
//                SimpleLogs.INFO("W")
                d.z = 1
                break

            default:
//                SimpleLogs.INFO("Unsupported key")
                break
        }
        mCamera.move(localDirection: d)
    }

    public func draw(in view: MTKView) { self.update() }

    func update()
    {
        self.render()
        self.countAndDisplayFPS()
    }

    func render()
    {
        // TODO: Throw or return early if mModel is nil
        let vertexBuffer = mModel?.getVertexBuffer()

        let model = mModel?.getModelMatrix() ?? Matrix4x4.identity()
        let view  = mCamera.getView()
        let proj  = mCamera.getProjection()

        let normalMatrix = Matrix4x4(from3x3: model.get3x3()
                                                   .inverse()?
                                                   .transposed()
                                              ??
                                              model.get3x3())

        // TODO: Use private storage
        let transformMatrices = mView.device?.makeBuffer(bytes: model.asSingleArray() +
                                                                view.asSingleArray() +
                                                                proj.asSingleArray() +
                                                                normalMatrix.asSingleArray(),
                                                         length: model.size * 4,
                                                         options: [])
        transformMatrices?.label = "Transform Matrices"

        let dirLight = DirectionalLight.init()
        // TODO: Use private storage
        let lights = mView.device?.makeBuffer(bytes: dirLight.getBufferData(),
                                              length: dirLight.getBufferSize(),
                                              options: [])
        lights?.label = "Lights"

        let commandBuffer  = mCommandQueue.makeCommandBuffer()!

        let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: mView.currentRenderPassDescriptor!)
        commandEncoder?.setRenderPipelineState(mPipelineState)
        commandEncoder?.setDepthStencilState(mDepthStencilState)
        commandEncoder?.setFrontFacing(mModel?.getWinding() ?? .clockwise)
        commandEncoder?.setCullMode(.back)

        commandEncoder?.setVertexBuffer(vertexBuffer, offset: 0, index: VERTEX_BUFFER_INDEX)
        commandEncoder?.setVertexBuffer(transformMatrices, offset: 0, index: TRANSFORM_MATRICES_INDEX)

        commandEncoder?.setFragmentBuffer(transformMatrices, offset: 0, index: TRANSFORM_MATRICES_INDEX)
        commandEncoder?.setFragmentBuffer(lights, offset: 0, index: LIGHTS_BUFFER_INDEX)

        commandEncoder?.setFragmentTexture(mTexture, index: 0)
        commandEncoder?.setFragmentSamplerState(mSamplerState, index: 0)

        if (mModel != nil)
        {
            for submesh in mModel!.getMesh().submeshes
            {
                commandEncoder?.drawIndexedPrimitives(type: submesh.primitiveType,
                                                      indexCount: submesh.indexCount,
                                                      indexType: submesh.indexType,
                                                      indexBuffer: submesh.indexBuffer.buffer,
                                                      indexBufferOffset: submesh.indexBuffer.offset)
            }
        }

        commandEncoder?.endEncoding()

        commandBuffer.present(mView.currentDrawable!)
        commandBuffer.commit()
    }

    private func loadTextures()
    {
        // TODO: Async?
        let textureLoader = MTKTextureLoader(device: mView.device!)

        let textureLoaderOptions = [
            MTKTextureLoader.Option.textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue),
            MTKTextureLoader.Option.textureStorageMode: NSNumber(value: MTLStorageMode.`private`.rawValue)
        ]

        do
        {
            mTexture = try textureLoader.newTexture(name: TEST_TEXTURE_NAME,
                                            scaleFactor: 1.0,
                                            bundle: nil,
                                            options: textureLoaderOptions)
            mTexture?.label = TEST_TEXTURE_NAME
        }
        catch
        {
            mTexture = nil
            SimpleLogs.ERROR("Couldn't load texture \(TEST_TEXTURE_NAME)")
        }
    }

    private func buildSamplerState()
    {
        // TODO: Read sampler descriptors from file?
        let texSamplerDesc          = MTLSamplerDescriptor()
        texSamplerDesc.minFilter    = .nearest
        texSamplerDesc.magFilter    = .linear
        texSamplerDesc.sAddressMode = .mirrorRepeat
        texSamplerDesc.tAddressMode = .mirrorRepeat

        mSamplerState = mView.device?.makeSamplerState(descriptor: texSamplerDesc)
    }

    private func countAndDisplayFPS()
    {
        struct StaticWrapper
        {
            static var start = DispatchTime.now().uptimeNanoseconds
            static var cummulativeTime: UInt64 = 0
            static var frameCount = 0
        }

        StaticWrapper.frameCount += 1

        let currentTime = DispatchTime.now().uptimeNanoseconds
        let deltaTime = currentTime > StaticWrapper.start ? currentTime - StaticWrapper.start : 0
        StaticWrapper.cummulativeTime += deltaTime
        StaticWrapper.start = currentTime

        // Refresh after roughly 1 second
        if (StaticWrapper.cummulativeTime >= 1_000_000_000)
        {
            // TODO: Display on UI instead of on the title bar
            mView.window?.title = "Talos [" + String(StaticWrapper.frameCount) + "fps]"
            StaticWrapper.frameCount = 0
            StaticWrapper.cummulativeTime = 0
        }
    }
}
