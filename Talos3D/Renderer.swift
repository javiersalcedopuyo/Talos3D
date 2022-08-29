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
let SCENE_MATRICES_INDEX        = 1
let OBJECT_MATRICES_INDEX       = 2
let LIGHTS_BUFFER_INDEX         = 3

let WORLD_UP = Vector3(x:0, y:1, z:0)

let TEST_MODEL_NAME        = "bunny"
let TEST_MODEL_EXTENSION   = "obj"

let TEST_TEXTURE_NAME      = "TestTexture1"
//let TEST_TEXTURE_EXTENSION = "png"

public class Renderer: NSObject, MTKViewDelegate
{
    public  var mView:          MTKView

    private let mCommandQueue:  MTLCommandQueue
    private let pipeline: Pipeline // TODO: pipeline cache
    private var mDepthStencilState: MTLDepthStencilState?

    private var mCamera: Camera!

    private var mModel:         Renderable?
    private var material:       Material // TODO: material cache?

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

        // TODO: Extract initPSOs()
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
        pipelineDescriptor.vertexFunction                  = vertexFunction
        pipelineDescriptor.fragmentFunction                = fragmentFunction
        pipelineDescriptor.vertexDescriptor                = Model.getNewVertexDescriptor()
        pipelineDescriptor.depthAttachmentPixelFormat      = mView.depthStencilPixelFormat

        guard let ps = Pipeline(desc: pipelineDescriptor, device: mtkView.device!) else
        {
            fatalError("Couldn't create pipeline state")
        }
        pipeline = ps

        let depthStencilDesc = MTLDepthStencilDescriptor()
        depthStencilDesc.depthCompareFunction = .less
        depthStencilDesc.isDepthWriteEnabled  = true

        mDepthStencilState = mView.device?.makeDepthStencilState(descriptor: depthStencilDesc)

        // TODO: Extract initScene()
        mCamera = Camera()
        mCamera.move(to: Vector3(x:0.25, y:0.25, z:-0.25))
        mCamera.lookAt(Vector3(x:0, y:0, z:0))

        material = Material(pipeline: pipeline)

        // TODO: Read model and transform data from file
        if let modelURL = Bundle.main.url(forResource: TEST_MODEL_NAME,
                                          withExtension: TEST_MODEL_EXTENSION)
        {
            mModel = Model(device: mtkView.device!,
                           url: modelURL,
                           material: material)

            let rotDegrees = SLA.rad2deg(0.5 * TAU)
            mModel?.rotate(eulerAngles: Vector3(x: 0, y: rotDegrees, z: 0))
            // mModel?.flipHandedness()
        }
        else
        {
            SimpleLogs.ERROR("Couldn't load model '" + TEST_MODEL_NAME + "." + TEST_MODEL_EXTENSION + "'")
        }

        super.init()

        self.material.textures = self.loadTextures()

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
        guard let device = mView.device else { return }

        // TODO: Throw or return early if mModel is nil
        let view  = mCamera.getView()
        let proj  = mCamera.getProjection()

        let dirLight = DirectionalLight.init()
        // TODO: Use private storage
        let lights = device.makeBuffer(bytes: dirLight.getBufferData(),
                                              length: dirLight.getBufferSize())
        lights?.label = "Lights"

        let commandBuffer  = mCommandQueue.makeCommandBuffer()!

        let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: mView.currentRenderPassDescriptor!)
        commandEncoder?.setDepthStencilState(mDepthStencilState)
        commandEncoder?.setCullMode(.back)

        commandEncoder?.setFragmentBuffer(lights, offset: 0, index: LIGHTS_BUFFER_INDEX)

        // TODO: Use private storage
        let sceneMatrices = device.makeBuffer(bytes:  view.asSingleArray() + proj.asSingleArray(),
                                              length: view.size + proj.size)
        sceneMatrices?.label = "Scene Matrices"
        commandEncoder?.setVertexBuffer(sceneMatrices, offset: 0, index: SCENE_MATRICES_INDEX)
        commandEncoder?.setFragmentBuffer(sceneMatrices, offset: 0, index: SCENE_MATRICES_INDEX)

        // TODO: Extract renderModel()
        if let model = mModel
        {
            let modelMatrix  = model.getModelMatrix()
            let normalMatrix = model.getNormalMatrix()

            let objMatrices = device.makeBuffer(bytes:  modelMatrix.asSingleArray() +
                                                        normalMatrix.asSingleArray(),
                                                length: modelMatrix.size + normalMatrix.size)
            objMatrices?.label = "Object Matrices"

            let material = model.getMaterial()
            commandEncoder?.setRenderPipelineState(material.pipeline.state)
            commandEncoder?.setFrontFacing(model.getWinding())

            // Set buffers
            commandEncoder?.setVertexBuffer(model.getVertexBuffer(),
                                            offset: 0,
                                            index: VERTEX_BUFFER_INDEX)

            commandEncoder?.setVertexBuffer(objMatrices, offset: 0, index: OBJECT_MATRICES_INDEX)
            commandEncoder?.setFragmentBuffer(objMatrices, offset: 0, index: OBJECT_MATRICES_INDEX)

            // Set Textures
            for texture in material.textures
            {
                if let idx = texture.GetIndexAtStage(.Vertex)
                {
                    commandEncoder?.setVertexTexture((texture.GetResource() as! MTLTexture),
                                                     index: idx)
                }
                if let idx = texture.GetIndexAtStage(.Fragment)
                {
                    commandEncoder?.setFragmentTexture((texture.GetResource() as! MTLTexture),
                                                       index: idx)
                }
            }

            // Draw
            for submesh in model.getMesh().submeshes
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

    // TODO: Load textures on demand
    private func loadTextures() -> [Texture]
    {
        // TODO: Async?
        let textureLoader = MTKTextureLoader(device: mView.device!)

        let textureLoaderOptions = [
            MTKTextureLoader.Option.textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue),
            MTKTextureLoader.Option.textureStorageMode: NSNumber(value: MTLStorageMode.`private`.rawValue)
        ]

        do
        {
            let mtlTex = try textureLoader.newTexture(name: TEST_TEXTURE_NAME,
                                                      scaleFactor: 1.0,
                                                      bundle: nil,
                                                      options: textureLoaderOptions)
            mtlTex.label = TEST_TEXTURE_NAME

            var texture = Texture(mtlTexture: mtlTex)
            texture.SetIndex(0, stage: .Fragment)
            return [texture]
        }
        catch
        {
            SimpleLogs.ERROR("Couldn't load texture \(TEST_TEXTURE_NAME)")
            return []
        }
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
