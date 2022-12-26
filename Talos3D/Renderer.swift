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
let LIGHT_MATRIX_INDEX          = BufferIndices.LIGHT_MATRIX.rawValue

let ALBEDO_MAP_INDEX            = TextureIndices.ALBEDO.rawValue
let SHADOW_MAP_INDEX            = TextureIndices.SHADOW_MAP.rawValue

let WORLD_UP = Vector3(x:0, y:1, z:0)

let BUNNY_MODEL_NAME        = "bunny"
let TEAPOT_MODEL_NAME       = "teapot"
let QUAD_MODEL_NAME         = "quad"
let OBJ_FILE_EXTENSION      = "obj"

let TEST_TEXTURE_NAME_1     = "TestTexture1"
let TEST_TEXTURE_NAME_2     = "TestTexture2"

let TEST_MATERIAL_NAME_1    = "Mat1"
let TEST_MATERIAL_NAME_2    = "Mat2"
let WHITE_MATERIAL_NAME     = "White Material"
let WRONG_MATERIAL_NAME     = "LoremIpsum"

public class Renderer: NSObject, MTKViewDelegate
{
    // MARK: - Public
    public init?(mtkView: MTKView)
    {
        guard let device = mtkView.device else
        {
            fatalError("NO GPU!")
        }

        mView = mtkView
        mView.depthStencilPixelFormat = MTLPixelFormat.depth16Unorm
        mView.clearDepth              = 1.0
        mView.clearColor              = MTLClearColor(red: 0.25, green: 0.25, blue: 0.25, alpha: 1.0)

        guard let cq = device.makeCommandQueue() else
        {
            fatalError("Could not create command queue")
        }
        commandQueue = cq

        (self.defaultPipeline,
         self.shadowPipeline,
         self.mainPipeline) = Self.createPipelines(view: mView)

        self.shadowMap = Self.createShadowMap(width: 512,
                                              height: 512,
                                              format: .depth16Unorm,
                                              device: device)

        self.defaultMaterial = Material(pipeline: self.defaultPipeline)

        let depthStencilDesc = MTLDepthStencilDescriptor()
        depthStencilDesc.depthCompareFunction = .less
        depthStencilDesc.isDepthWriteEnabled  = true

        mDepthStencilState = device.makeDepthStencilState(descriptor: depthStencilDesc)

        guard let dummy = Self.createMetalTexture(size: MTLSize(width: 1, height: 1, depth: 1),
                                                  initialValue: 255,
                                                  device: device)
        else
        {
            fatalError("Failed to create the dummy texture.")
        }
        self.dummyTexture = dummy

        super.init()

        self.createMaterials(device: device)
        self.buildScene(device: device)
        mView.delegate = self
    }

    /// Creates a new Metal Texture with a given size and initial value
    /// - Parameters:
    ///     - size
    ///     - initialValue: [0,255] Will be set for all channels of all texels
    ///     - device: The device used to create the texture
    /// - Returns:
    ///     - MTLTexture: With RGBA8Unorm pixel format
    private static func createMetalTexture(size:            MTLSize,
                                           initialValue:    UInt8,
                                           device:          MTLDevice)
    -> MTLTexture?
    {
        let texDesc = MTLTextureDescriptor()
        texDesc.width  = size.width
        texDesc.height = size.height
        texDesc.depth  = size.depth

        guard let mtlTex = device.makeTexture(descriptor: texDesc) else
        {
            ERROR("Failed to create texture.")
            return nil
        }

        let dataSize = 4 * size.width * size.height * size.depth
        let data = Array(repeating: initialValue, count: dataSize)

        mtlTex.replace(region:      MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0), size: size),
                       mipmapLevel: 0,
                       withBytes:   data,
                       bytesPerRow: dataSize)

        return mtlTex
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
        self.beginFrame()

        self.renderShadowMap()
        self.renderScene()

        self.endFrame()
    }

    // TODO: Double/Triple buffer
    func beginFrame()
    {
        if self.currentCommandBuffer != nil
        {
            SimpleLogs.WARNING("There's a command buffer in use currently. endFrame() will be called. This can impact performance.")
            self.endFrame()
        }
        self.currentCommandBuffer = self.commandQueue.makeCommandBuffer()
    }

    func endFrame()
    {
        guard let cb = self.currentCommandBuffer else
        {
            SimpleLogs.WARNING("There's no command buffer in use. Did you forget to call beginFrame()?")
            return
        }

        cb.present(mView.currentDrawable!)
        cb.commit()

        self.currentCommandBuffer = nil // ARC should take care of deallocating this
    }

    func renderShadowMap()
    {
        let renderPassDesc = MTLRenderPassDescriptor()
        renderPassDesc.depthAttachment.texture = self.shadowMap
        renderPassDesc.depthAttachment.storeAction = .store

        guard let commandEncoder = self.currentCommandBuffer?
                                       .makeRenderCommandEncoder(descriptor: renderPassDesc) else
        {
            SimpleLogs.ERROR("Couldn't create a command encoder. Skipping pass.")
            return
        }
        commandEncoder.label = "Shadow pass"
        commandEncoder.setDepthStencilState(mDepthStencilState)
        commandEncoder.setDepthBias(1, slopeScale: 3, clamp: 1/128)

        // Set Scene buffers
        // TODO: Adapt this to multiple lights
        let view = self.scene.lights[0].getView()
        let proj = self.scene.lights[0].projection ?? .identity()
        commandEncoder.setVertexBytes((proj * view).asPackedArray(),
                                      length: Matrix4x4.size(),
                                      index: SCENE_MATRICES_INDEX)

        // All objects in the shadow pass use the same PSO
        let psoID = ObjectIdentifier(self.shadowPipeline)
        if  psoID != self.currentlyBoundPipelineID
        {
            commandEncoder.setRenderPipelineState(self.shadowPipeline.state)
            self.currentlyBoundPipelineID = psoID
        }

        for model in self.scene.objects
        {
            encodeRenderCommand(encoder:    commandEncoder,
                                object:     model,
                                passType:   .Shadows)
        }
        commandEncoder.endEncoding()
    }

    func renderScene()
    {
        let view = self.scene.mainCamera.getView()
        let proj = self.scene.mainCamera.getProjection()

        guard let renderPassDesc = mView.currentRenderPassDescriptor else
        {
            // TODO: Create a dedicated render pass descriptor
            SimpleLogs.ERROR("No render pass descriptor. Skipping pass.")
            return
        }
        renderPassDesc.depthAttachment.storeAction = .dontCare

        guard let commandEncoder = self.currentCommandBuffer?
                                       .makeRenderCommandEncoder(descriptor: renderPassDesc) else
        {
            SimpleLogs.ERROR("Couldn't creater a command encoder. Skipping pass.")
            return
        }

        commandEncoder.label = "Main pass"

        commandEncoder.setDepthStencilState(mDepthStencilState)

        // Set Scene buffers
        commandEncoder.setVertexBytes(view.asPackedArray() + proj.asPackedArray(),
                                      length: Matrix4x4.size() * 2,
                                      index: SCENE_MATRICES_INDEX)

        commandEncoder.setFragmentBytes(view.asPackedArray() + proj.asPackedArray(),
                                        length: Matrix4x4.size() * 2,
                                        index: SCENE_MATRICES_INDEX)

        let dirLight = self.scene.lights[0] // TODO: Multiple lights
        commandEncoder.setFragmentBytes(dirLight.getBufferData(),
                                        length: dirLight.getBufferSize(),
                                        index: LIGHTS_BUFFER_INDEX)

        let lightMatrix = (dirLight.projection ?? .identity()) * dirLight.getView() // Inverse View?
        commandEncoder.setVertexBytes(lightMatrix.asPackedArray(),
                                      length: Matrix4x4.size(),
                                      index: LIGHT_MATRIX_INDEX)

        commandEncoder.setFragmentTexture(self.shadowMap, index: SHADOW_MAP_INDEX)

        for model in self.scene.objects
        {
            encodeRenderCommand(encoder:    commandEncoder,
                                object:      model,
                                passType:   .ForwardLighting)
        }

        commandEncoder.endEncoding()
    }

    public var mView: MTKView

    // MARK: - Private
    /// Creates the pipelines needed by the engine.
    /// - Parameters:
    ///     - view: the current MTKView
    /// - Returns:
    ///    - Default: Pipeline used by the default material (aka the material-missing pink material)
    ///    - Shadow: Pipeline used to render the shadow map
    ///    - Main: Pipeline used by the main render pass
    // TODO: This is slowly getting out of control. Refactor.
    static private func createPipelines(view: MTKView) -> (default: Pipeline,
                                                           shadow: Pipeline,
                                                           main: Pipeline)
    {
        guard let device = view.device else
        {
            fatalError("No device")
        }

        guard let library = view.device?.makeDefaultLibrary() else
        {
            fatalError("Couldn't create shader library!")
        }

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.label                            = "Default PSO"
        pipelineDescriptor.colorAttachments[0].pixelFormat  = view.colorPixelFormat
        pipelineDescriptor.vertexFunction                   = library.makeFunction(name: "default_vertex_main")
        pipelineDescriptor.fragmentFunction                 = library.makeFunction(name: "default_fragment_main")
        pipelineDescriptor.vertexDescriptor                 = Model.getNewVertexDescriptor()
        pipelineDescriptor.depthAttachmentPixelFormat       = view.depthStencilPixelFormat

        guard let defaultPipeline = Pipeline(desc: pipelineDescriptor,
                                             device: device,
                                             type: .ForwardLighting) else
        {
            fatalError("Couldn't create default pipeline state")
        }

        pipelineDescriptor.label            = "Main PSO"
        pipelineDescriptor.vertexFunction   = library.makeFunction(name: "vertex_main")
        pipelineDescriptor.fragmentFunction = library.makeFunction(name: "fragment_main")
        guard let mainPipeline = Pipeline(desc: pipelineDescriptor,
                                          device: device,
                                          type: .ForwardLighting) else
        {
            fatalError("Couldn't create main pipeline state")
        }

        pipelineDescriptor.label                            = "Shadow Pass PSO"
        // We don't need a color attachment or a fragment function because we just want the depth
        pipelineDescriptor.colorAttachments[0].pixelFormat  = .invalid
        pipelineDescriptor.fragmentFunction                 = nil
        pipelineDescriptor.vertexFunction                   = library.makeFunction(name: "shadow_vertex_main")
        pipelineDescriptor.vertexDescriptor                 = Model.getNewVertexDescriptor()
        guard let shadowPipeline = Pipeline(desc: pipelineDescriptor,
                                            device: device,
                                            type: .Shadows) else
        {
            fatalError("Couldn't create shadow pipeline state")
        }

        return (defaultPipeline, shadowPipeline, mainPipeline)
    }

    /// Creates a new texture to be used as a shadow map
    /// - Parameters:
    ///     - width
    ///     - height
    ///     - format: Must be either depth16Unorm or depth32Float
    ///     - device: The MTLDevice that will create the texture
    /// - Returns:
    ///     - shadowMap
    static private func createShadowMap(width: Int,
                                        height: Int,
                                        format: MTLPixelFormat,
                                        device: MTLDevice)
    -> MTLTexture
    {
        assert(format == .depth16Unorm || format == .depth32Float)

        let descriptor = MTLTextureDescriptor()
        descriptor.width = width
        descriptor.height = height
        descriptor.pixelFormat = format
        descriptor.storageMode = .private
        descriptor.usage = [.renderTarget, .shaderRead]

        guard let shadowMap = device.makeTexture(descriptor: descriptor) else
        {
            // TODO: Handle this gracefully
            fatalError("Couldn't create the depth buffer")
        }
        shadowMap.label = "Shadow Map"

        return shadowMap
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
            material2.swapTexture(idx: 0, newTexture: tex)
        }

        var whiteTex = Texture(mtlTexture: self.dummyTexture,
                               label: "Dummy")
        whiteTex.setIndex(0, stage: .Fragment)

        let material3 = material1.copy() as! Material
        material3.swapTexture(idx: 0, newTexture: whiteTex)

        self.materials[TEST_MATERIAL_NAME_1] = material1
        self.materials[TEST_MATERIAL_NAME_2] = material2
        self.materials[WHITE_MATERIAL_NAME]  = material3
    }

    private func buildScene(device: MTLDevice)
    {
        let cam = Camera()
        cam.move(to: Vector3(x:0, y:0.25, z:-0.6))
        cam.lookAt(Vector3.zero())

        let light = DirectionalLight(direction: Vector3(x:1, y:-1, z:1),
                                     color: .one,
                                     intensity: 1,
                                     castsShadows: true);

        let sceneBuilder = SceneBuilder()
                            .add(camera: cam)
                            .add(light: light)

        self.loadModelsIntoScene(device: device, sceneBuilder: sceneBuilder)

        self.scene = sceneBuilder.build(device: device)
    }

    /// Loads models from file into the scene using a scene builder
    /// - Parameters:
    ///     - device
    ///     - sceneBuilder: Passed by reference, the new models will be added to it
    // TODO: Read model and transform data from file
    private func loadModelsIntoScene(device: MTLDevice, sceneBuilder: SceneBuilder)
    {
        // BUNNY
        if let modelURL = Bundle.main.url(forResource: BUNNY_MODEL_NAME,
                                          withExtension: OBJ_FILE_EXTENSION)
        {
            let model = Model(device: device,
                              url: modelURL,
                              material: self.materials[WHITE_MATERIAL_NAME] ?? self.defaultMaterial)

            let rotDegrees = SLA.rad2deg(0.5 * TAU)
            model.rotate(localEulerAngles: Vector3(x: 0, y: rotDegrees, z: 0))
            model.move(to: Vector3(x:-0.15, y:0, z:0))
            // model.flipHandedness()

            sceneBuilder.add(object: model)
        }
        else
        {
            SimpleLogs.ERROR("Couldn't load model '" + BUNNY_MODEL_NAME + "." + OBJ_FILE_EXTENSION + "'")
        }

        // TEAPOT
        if let modelURL = Bundle.main.url(forResource: TEAPOT_MODEL_NAME,
                                          withExtension: OBJ_FILE_EXTENSION)
        {
            let model = Model(device: device,
                              url: modelURL,
                              material: self.materials[TEST_MATERIAL_NAME_2] ?? self.defaultMaterial,
                              culling: .none)

            model.scale(by: 0.01)
            model.move(to: Vector3(x:0.15, y:0.075, z:0))

            sceneBuilder.add(object: model)
        }
        else
        {
            SimpleLogs.ERROR("Couldn't load model '" + TEAPOT_MODEL_NAME + "." + OBJ_FILE_EXTENSION + "'")
        }

        // FLOOR
        if let modelURL = Bundle.main.url(forResource: QUAD_MODEL_NAME,
                                          withExtension: OBJ_FILE_EXTENSION)
        {
            let model = Model(device: device,
                              url: modelURL,
                              material: self.materials[TEST_MATERIAL_NAME_1] ?? self.defaultMaterial,
                              culling: .none)

            sceneBuilder.add(object: model)
        }
        else
        {
            SimpleLogs.ERROR("Couldn't load model '" + QUAD_MODEL_NAME + "." + OBJ_FILE_EXTENSION + "'")
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

    /// Renders a model
    /// - Parameters:
    ///    - encoder:
    ///    - object: Renderable to be rendered
    ///    - passType: This will be used to determine the material to use and the resources to bind
    private func encodeRenderCommand(encoder: MTLRenderCommandEncoder,
                                     object: Renderable,
                                     passType: PassType)
    {
        var objMatrixData = object.getModelMatrix().asPackedArray()

        encoder.setCullMode(object.faceCulling)

        // Set buffers
        encoder.setVertexBuffer(object.getVertexBuffer(),
                                offset: 0,
                                index: VERTEX_BUFFER_INDEX)

        // Bind fragment resources
        switch passType
        {
        case .ForwardLighting:
            objMatrixData.append(contentsOf: object.getNormalMatrix().asPackedArray() )

            encoder.setFragmentBytes(objMatrixData,
                                     length: MemoryLayout<Float>.size * objMatrixData.count,
                                     index: OBJECT_MATRICES_INDEX)

            // TODO: Sort the models by material
            let material = object.getMaterial()
            let psoID = ObjectIdentifier(material.pipeline)
            if psoID != self.currentlyBoundPipelineID
            {
                encoder.setRenderPipelineState(material.pipeline.state)
                self.currentlyBoundPipelineID = psoID
            }
            encoder.setFrontFacing(object.getWinding())

            // Set Textures
            for texture in material.textures
            {
                if let idx = texture.getIndexAtStage(.Vertex)
                {
                    encoder.setVertexTexture((texture.getResource() as! MTLTexture),
                                             index: idx)
                }
                if let idx = texture.getIndexAtStage(.Fragment)
                {
                    encoder.setFragmentTexture((texture.getResource() as! MTLTexture),
                                               index: idx)
                }
            }

        case .Shadows:
            break // The shadow passes don't have a fragment stage and don't need materials

        case .GBuffer, .DeferredLighting:
            UNIMPLEMENTED("Deferred rendering is not supported yet.") // TODO: Deferred Rendering
        }

        encoder.setVertexBytes(objMatrixData,
                               length: MemoryLayout<Float>.size * objMatrixData.count,
                               index: OBJECT_MATRICES_INDEX)

        // Draw
        for submesh in object.getMesh().submeshes
        {
            encoder.drawIndexedPrimitives(type:                 submesh.primitiveType,
                                          indexCount:           submesh.indexCount,
                                          indexType:            submesh.indexType,
                                          indexBuffer:          submesh.indexBuffer.buffer,
                                          indexBufferOffset:    submesh.indexBuffer.offset)
        }
    }

    private let commandQueue:  MTLCommandQueue
    private var currentCommandBuffer: MTLCommandBuffer?

    // TODO: pipeline cache
    private let mainPipeline: Pipeline
    private let defaultPipeline: Pipeline
    private let shadowPipeline: Pipeline
    private var currentlyBoundPipelineID: ObjectIdentifier? = nil

    private var mDepthStencilState: MTLDepthStencilState?

    private var shadowMap: MTLTexture
    private let dummyTexture: MTLTexture

    private var scene: Scene!

    private let defaultMaterial: Material
    private var materials: [String: Material] = [:]
}
