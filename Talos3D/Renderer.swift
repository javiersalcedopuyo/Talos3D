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
let VERTEX_BUFFER_INDEX         = BufferIndices.VERTICES.rawValue
let SCENE_MATRICES_INDEX        = BufferIndices.SCENE_MATRICES.rawValue
let OBJECT_MATRICES_INDEX       = BufferIndices.OBJECT_MATRICES.rawValue
let LIGHTS_BUFFER_INDEX         = BufferIndices.LIGHTS.rawValue

let ALBEDO_MAP_INDEX            = TextureIndices.ALBEDO.rawValue

let WORLD_UP = Vector3(x:0, y:1, z:0)

let BUNNY_MODEL_NAME        = "bunny"
let TEAPOT_MODEL_NAME       = "teapot"
let OBJ_FILE_EXTENSION      = "obj"

let TEST_TEXTURE_NAME_1     = "TestTexture1"
let TEST_TEXTURE_NAME_2     = "TestTexture2"

let TEST_MATERIAL_NAME_1    = "Mat1"
let TEST_MATERIAL_NAME_2    = "Mat2"
let WRONG_MATERIAL_NAME     = "LoremIpsum"

public class Renderer: NSObject, MTKViewDelegate
{
    // MARK: - Public
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

        (self.defaultPipeline, self.mainPipeline) = Self.createPipelines(view: mView)

        self.defaultMaterial = Material(pipeline: self.defaultPipeline)

        let depthStencilDesc = MTLDepthStencilDescriptor()
        depthStencilDesc.depthCompareFunction = .less
        depthStencilDesc.isDepthWriteEnabled  = true

        mDepthStencilState = mView.device?.makeDepthStencilState(descriptor: depthStencilDesc)

        super.init()

        self.createMaterials(device: mtkView.device!)
        self.buildScene(device: mtkView.device!)
        mView.delegate = self
    }

    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize)
    {
        let newAspectRatio = Float(size.width / size.height)
        self.scene
            .mainCamera
            .updateAspectRatio(newAspectRatio)
    }

    public func onMouseDrag(deltaX: Float, deltaY: Float)
    {
        self.scene.mainCamera.rotateAround(localAxis: .X, radians: deg2rad(deltaY))
        self.scene.mainCamera.rotateAround(worldAxis: .Y, radians: deg2rad(deltaX))
    }

    public func onScroll(scroll: Float)
    {
        let d = Vector3(x: 0, y: 0, z: scroll)
        self.scene
            .mainCamera
            .move(localDirection: d)
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
        self.scene
            .mainCamera
            .move(localDirection: d)
    }

    public func draw(in view: MTKView) { self.update() }

    func update()
    {
        self.render()
        self.countAndDisplayFPS()
    }

    func render()
    {
        let view = self.scene.mainCamera.getView()
        let proj = self.scene.mainCamera.getProjection()

        let commandBuffer  = mCommandQueue.makeCommandBuffer()!
        let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: mView.currentRenderPassDescriptor!)
        commandEncoder?.setDepthStencilState(mDepthStencilState)
        commandEncoder?.setCullMode(.back)

        // Set Scene buffers
        commandEncoder?.setVertexBytes(view.asPackedArray() + proj.asPackedArray(),
                                       length: Matrix4x4.size() * 2,
                                       index: SCENE_MATRICES_INDEX)

        commandEncoder?.setFragmentBytes(view.asPackedArray() + proj.asPackedArray(),
                                         length: Matrix4x4.size() * 2,
                                        index: SCENE_MATRICES_INDEX)

        let dirLight = self.scene.lights[0] // TODO: Multiple lights
        commandEncoder?.setFragmentBytes(dirLight.getBufferData(),
                                         length: dirLight.getBufferSize(),
                                         index: LIGHTS_BUFFER_INDEX)

        // TODO: Extract renderModel()
        for model in self.scene.objects
        {
            let modelMatrix  = model.getModelMatrix()
            let normalMatrix = model.getNormalMatrix()

            let material = model.getMaterial()
            commandEncoder?.setRenderPipelineState(material.pipeline.state)
            commandEncoder?.setFrontFacing(model.getWinding())

            // Set buffers
            commandEncoder?.setVertexBuffer(model.getVertexBuffer(),
                                            offset: 0,
                                            index: VERTEX_BUFFER_INDEX)

            commandEncoder?.setVertexBytes(modelMatrix.asPackedArray() +
                                           normalMatrix.asPackedArray(),
                                           length: Matrix4x4.size() * 2,
                                           index: OBJECT_MATRICES_INDEX)

            commandEncoder?.setFragmentBytes(modelMatrix.asPackedArray() +
                                             normalMatrix.asPackedArray(),
                                             length: Matrix4x4.size() * 2,
                                             index: OBJECT_MATRICES_INDEX)
            // Set Textures
            for texture in material.textures
            {
                if let idx = texture.getIndexAtStage(.Vertex)
                {
                    commandEncoder?.setVertexTexture((texture.getResource() as! MTLTexture),
                                                     index: idx)
                }
                if let idx = texture.getIndexAtStage(.Fragment)
                {
                    commandEncoder?.setFragmentTexture((texture.getResource() as! MTLTexture),
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

    public var mView: MTKView

    // MARK: - Private
    static private func createPipelines(view: MTKView) -> (default: Pipeline, main: Pipeline)
    {
        guard let device = view.device else
        {
            fatalError("No device")
        }

        guard let library = view.device?.makeDefaultLibrary() else
        {
            fatalError("Couldn't create shader library!")
        }

        let defaultVertFunc = library.makeFunction(name: "default_vertex_main")
        let defaultFragFunc = library.makeFunction(name: "default_fragment_main")
        let mainVertFunc    = library.makeFunction(name: "vertex_main")
        let mainFragFunc    = library.makeFunction(name: "fragment_main")

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
        pipelineDescriptor.vertexFunction                  = defaultVertFunc
        pipelineDescriptor.fragmentFunction                = defaultFragFunc
        pipelineDescriptor.vertexDescriptor                = Model.getNewVertexDescriptor()
        pipelineDescriptor.depthAttachmentPixelFormat      = view.depthStencilPixelFormat

        guard let defaultPipeline = Pipeline(desc: pipelineDescriptor, device: device) else
        {
            fatalError("Couldn't create default pipeline state")
        }

        pipelineDescriptor.vertexFunction   = mainVertFunc
        pipelineDescriptor.fragmentFunction = mainFragFunc
        guard let mainPipeline = Pipeline(desc: pipelineDescriptor, device: device) else
        {
            fatalError("Couldn't create main pipeline state")
        }

        return (defaultPipeline, mainPipeline)
    }

    private func createMaterials(device: MTLDevice)
    {
        let material1 = Material(pipeline: self.mainPipeline)
        if let tex = Self.loadTexture(name: TEST_TEXTURE_NAME_1,
                                      index: ALBEDO_MAP_INDEX,
                                      device: device)
        {
            material1.textures.append(tex)
        }

        let material2 = material1.copy() as! Material
        if let tex = Self.loadTexture(name: TEST_TEXTURE_NAME_2,
                                      index: ALBEDO_MAP_INDEX,
                                      device: device)
        {
            material2.textures.append(tex)
        }

        self.materials[TEST_MATERIAL_NAME_1] = material1
        self.materials[TEST_MATERIAL_NAME_2] = material2
    }

    private func buildScene(device: MTLDevice)
    {
        let cam = Camera()
        cam.move(to: Vector3(x:0.5, y:0.25, z:-0.6))
        cam.lookAt(Vector3(x:0.2, y:0.1, z:0))

        let sceneBuilder = SceneBuilder()
                            .add(camera: cam)
                            .add(light: DirectionalLight())

        self.loadModelsIntoScene(device: device, sceneBuilder: sceneBuilder)

        self.scene = sceneBuilder.build(device: device)
    }

    // TODO: Read model and transform data from file
    private func loadModelsIntoScene(device: MTLDevice, sceneBuilder: SceneBuilder)
    {
        if let modelURL = Bundle.main.url(forResource: BUNNY_MODEL_NAME,
                                          withExtension: OBJ_FILE_EXTENSION)
        {
            let model = Model(device: device,
                              url: modelURL,
                              material: self.materials[TEST_MATERIAL_NAME_1] ?? self.defaultMaterial)

            let rotDegrees = SLA.rad2deg(0.5 * TAU)
            model.rotate(localEulerAngles: Vector3(x: 0, y: rotDegrees, z: 0))
            // model.flipHandedness()

            sceneBuilder.add(object: model)
        }
        else
        {
            SimpleLogs.ERROR("Couldn't load model '" + BUNNY_MODEL_NAME + "." + OBJ_FILE_EXTENSION + "'")
        }

        if let modelURL = Bundle.main.url(forResource: TEAPOT_MODEL_NAME,
                                          withExtension: OBJ_FILE_EXTENSION)
        {
            let model = Model(device: device,
                              url: modelURL,
                              material: self.materials[TEST_MATERIAL_NAME_2] ?? self.defaultMaterial)

            model.scale(by: 0.01)
            model.move(to: Vector3(x:0.35, y:0.075, z:0))

            sceneBuilder.add(object: model)
        }
        else
        {
            SimpleLogs.ERROR("Couldn't load model '" + TEAPOT_MODEL_NAME + "." + OBJ_FILE_EXTENSION + "'")
        }
    }

    static private func loadTexture(name: String, index: Int, device: MTLDevice) -> Texture?
    {
        // TODO: Async?
        let textureLoader = MTKTextureLoader(device: device)

        let textureLoaderOptions = [
            MTKTextureLoader.Option.textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue),
            MTKTextureLoader.Option.textureStorageMode: NSNumber(value: MTLStorageMode.`private`.rawValue),
            MTKTextureLoader.Option.generateMipmaps: true
        ]

        do
        {
            let mtlTex = try textureLoader.newTexture(name: name,
                                                      scaleFactor: 1.0,
                                                      bundle: nil,
                                                      options: textureLoaderOptions)

            var texture = Texture(mtlTexture: mtlTex, label: name)
            texture.setIndex(index, stage: .Fragment)
            return texture
        }
        catch
        {
            SimpleLogs.ERROR("Couldn't load texture \(name)")
            return nil
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

    private let mCommandQueue:  MTLCommandQueue
    // TODO: pipeline cache
    private let mainPipeline: Pipeline
    private let defaultPipeline: Pipeline

    private var mDepthStencilState: MTLDepthStencilState?

    private var scene: Scene!

    private let defaultMaterial: Material
    private var materials: [String: Material] = [:]
}
