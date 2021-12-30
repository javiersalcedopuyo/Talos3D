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

let VERTEX_BUFFER_INDEX  = 0
let UNIFORM_BUFFER_INDEX = 1

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

    private var mCameraMoveSpeed:       Float
    private var mCameraMoveSensitivity: Float
    private var mCameraZoomSensitivity: Float
    private var mCameraPos:             Vector3

    private var mModel:         Model?
    // TODO: Load textures on demand
    private var mTexture:       MTLTexture?
    // TODO: Pre-built collection?
    private var mSamplerState:  MTLSamplerState?


    public init?(mtkView: MTKView)
    {
        if mtkView.device == nil
        {
            fatalError("NO GPU!")
        }

        mView = mtkView
        mView.depthStencilPixelFormat = MTLPixelFormat.depth16Unorm
        mView.clearDepth              = 1.0

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

        if let modelURL = Bundle.main.url(forResource: TEST_MODEL_NAME,
                                          withExtension: TEST_MODEL_EXTENSION)
        {
            mModel = Model(device: mtkView.device!, url: modelURL)
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
        pipelineDescriptor.vertexDescriptor                = mModel?.mVertexDescriptor
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

        // TODO: Extract initCamera()
        mCameraMoveSpeed       = 0.01
        mCameraMoveSensitivity = 0.005
        mCameraZoomSensitivity = 0.01
        mCameraPos             = Vector3(x:0, y:0, z:-0.5)

        super.init()

        self.loadTextures()
        self.buildSamplerState()

        mView.delegate = self
    }

    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) { /* TODO: */ }

    public func onMouseDrag(deltaX: Float, deltaY: Float)
    {
        // TODO: Make it rotate instead
        mCameraPos.x -= deltaX * mCameraMoveSensitivity
        mCameraPos.y += deltaY * mCameraMoveSensitivity
        // SimpleLogs.INFO("New pos: " + mCameraPos.description)
    }

    public func onScroll(scroll: Float)
    {
        mCameraPos.z += scroll * mCameraMoveSpeed
        // SimpleLogs.INFO("New pos: " + mCameraPos.description)
    }

    public func onKeyPress(keyCode: UInt16)
    {
        switch keyCode
        {
            case 0:
//                SimpleLogs.INFO("A")
                mCameraPos.x -= mCameraMoveSpeed
                break

            case 0x02:
//                SimpleLogs.INFO("D")
                mCameraPos.x += mCameraMoveSpeed
                break

            case 0x01:
//                SimpleLogs.INFO("S")
                mCameraPos.z -= mCameraZoomSensitivity
                break

            case 0x0D:
//                SimpleLogs.INFO("W")
                mCameraPos.z += mCameraZoomSensitivity
                break

            default:
//                SimpleLogs.INFO("Unsupported key")
                break
        }
    }

    public func draw(in view: MTKView) { self.update() }

    func update()
    {
        struct Wrapper { static var i = 0.0 }
        Wrapper.i = (Wrapper.i + 0.01).truncatingRemainder(dividingBy: 1.0)

        self.render()
    }

    func render()
    {
        let vertexBuffer = mModel?.mMeshes[0].vertexBuffers[0].buffer

        var ubo   = UniformBufferObject()
        ubo.model = mModel?.mModelMatrix ?? Matrix4x4.identity()
        ubo.model = ubo.model * Matrix4x4.makeRotation(radians: TAU * 0.5, axis: Vector4(x: 0, y: 1, z: 0, w:0))

        // TODO: Use Constant Buffer?
        ubo.view  = Matrix4x4.lookAtLH(eye:    mCameraPos,
                                       target: mCameraPos + Vector3(x:0, y:0, z:1),
                                       upAxis: WORLD_UP)

        ubo.proj  = Matrix4x4.perspectiveLH(fovy: SLA.deg2rad(45.0),
                                            aspectRatio: Float(mView.frame.width / mView.frame.height),
                                            near: 0.1,
                                            far: 1000.0)

        let uniformsSize  = ubo.size()
        let uniformBuffer = mView.device?.makeBuffer(bytes: ubo.asArray(),
                                                     length: uniformsSize,
                                                     options: [])

        let commandBuffer  = mCommandQueue.makeCommandBuffer()!

        let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: mView.currentRenderPassDescriptor!)
        commandEncoder?.setRenderPipelineState(mPipelineState)
        commandEncoder?.setDepthStencilState(mDepthStencilState)
        commandEncoder?.setFrontFacing(mModel?.mWinding ?? .clockwise)
        commandEncoder?.setCullMode(.back)
        commandEncoder?.setVertexBuffer(vertexBuffer, offset: 0, index: VERTEX_BUFFER_INDEX)
        commandEncoder?.setVertexBuffer(uniformBuffer, offset: 0, index: UNIFORM_BUFFER_INDEX)
        commandEncoder?.setFragmentTexture(mTexture, index: 0)
        commandEncoder?.setFragmentSamplerState(mSamplerState, index: 0)

        if (mModel != nil)
        {
            for submesh in mModel!.mMeshes[0].submeshes
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
}
