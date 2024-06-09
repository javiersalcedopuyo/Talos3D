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
let MATERIAL_PARAMS_INDEX       = BufferIndices.MATERIAL_PARAMS.rawValue
let CAMERA_POSITION_INDEX       = BufferIndices.CAMERA_POSITION.rawValue

let ALBEDO_MAP_INDEX            = TextureIndices.ALBEDO.rawValue
let SHADOW_MAP_INDEX            = TextureIndices.SHADOW_MAP.rawValue
let SKYBOX_INDEX                = TextureIndices.SKYBOX.rawValue

let ALBEDO_AND_METALLIC_INDEX   = TextureIndices.ALBEDO_AND_METALLIC.rawValue
let NORMAL_AND_ROUGHNESS_INDEX  = TextureIndices.NORMAL_AND_ROUGHNESS.rawValue
let DEPTH_INDEX                 = TextureIndices.DEPTH.rawValue

let WORLD_UP = Vector3(x:0, y:1, z:0)

let BUNNY_MODEL_NAME        = "bunny"
let TEAPOT_MODEL_NAME       = "teapot"
let QUAD_MODEL_NAME         = "quad"
let OBJ_FILE_EXTENSION      = "obj"

let TEST_TEXTURE_NAME_1     = "TestTexture1"
let TEST_TEXTURE_NAME_2     = "TestTexture2"
let SKYBOX_TEXTURE_NAME_1   = "Skybox1"

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

        self.shadowMap = Self.createShadowMap(width: 512,
                                              height: 512,
                                              format: .depth16Unorm,
                                              device: device)

        self.depthStencil = Self.createDepthStencilTexture(width:  Int(mtkView.drawableSize.width),
                                                           height: Int(mtkView.drawableSize.height),
                                                           format: .depth32Float_stencil8,
                                                           device: device)

        self.pipelineManager = PipelineManager(view: mView)

        self.defaultMaterial = Material(pipeline: self.pipelineManager.getOrCreateDefaultPipeline())
        self.skyboxMaterial  = Material(pipeline: self.pipelineManager.getOrCreateSkyboxPipeline())
        if let tex = Self.loadTexture(name: SKYBOX_TEXTURE_NAME_1,
                                      index: SKYBOX_INDEX,
                                      device: device)
        {
            self.skyboxMaterial.textures.append(tex)
        }

        guard let dummy = Self.createMetalTexture(size: MTLSize(width: 1, height: 1, depth: 1),
                                                  initialValue: 128,
                                                  device: device)
        else
        {
            fatalError("Failed to create the dummy texture.")
        }
        self.dummyTexture = dummy

        // TODO: createGBuffer()
        let gBufferDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba32Float,
                                                                   width:  Int(mtkView.drawableSize.width),
                                                                   height: Int(mtkView.drawableSize.height),
                                                                   mipmapped: false)
        gBufferDesc.usage = [.renderTarget, .shaderRead]
        gBufferDesc.storageMode = .private
        self.gBufferAlbedoAndMetallic = device.makeTexture(descriptor: gBufferDesc)!
        self.gBufferAlbedoAndMetallic.label = "G-Buffer Albedo & Metallic"

        self.gBufferNormalAndRoughness = device.makeTexture(descriptor: gBufferDesc)!
        self.gBufferNormalAndRoughness.label = "G-Buffer Normal & Roughness"

        let gBufferDepthDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r32Float,
                                                                        width: Int(mtkView.drawableSize.width),
                                                                        height: Int(mtkView.drawableSize.height),
                                                                        mipmapped: false)
        gBufferDepthDesc.usage = [.renderTarget, .shaderRead]
        gBufferDepthDesc.storageMode = .private
        self.gBufferDepth = device.makeTexture(descriptor: gBufferDepthDesc)!
        self.gBufferDepth.label = "G-Buffer Depth"

        self.quadIndexBuffer = device.makeBuffer(
            bytes: [0,1,2,1,3,2] as [UInt16],
            length: 6 * 2, // In bytes!
            options: [.storageModeManaged, .hazardTrackingModeUntracked])

        super.init()

        self.createDepthStencilStates(device: device)
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
        self.renderGBuffer()
        self.applyDeferredLighting()
        // TODO: self.renderGizmos()

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
        self.currentlyBoundPipelineID = nil

        guard let cb = self.currentCommandBuffer else
        {
            SimpleLogs.WARNING("There's no command buffer in use. Did you forget to call beginFrame()?")
            return
        }

        cb.present(mView.currentDrawable!)
        cb.commit()

        self.currentCommandBuffer = nil // ARC should take care of deallocating this
    }

    /// Shadow pass. Renders the scene from the light's perspective into the shadow map
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
        commandEncoder.setDepthStencilState(self.shadowDepthStencilState)
        commandEncoder.setDepthBias(1, slopeScale: 3, clamp: 1/128)

        self.boundResources.removeAll()

        // Set Scene buffers
        // TODO: Adapt this to multiple lights
        let view = self.scene.lights[0].getView()
        let proj = self.scene.lights[0].projection ?? .identity()
        commandEncoder.setVertexBytes((proj * view).asPackedArray(),
                                      length: Matrix4x4.size(),
                                      index: SCENE_MATRICES_INDEX)

        // All objects in the shadow pass use the same PSO
        self.bind(pipeline: self.pipelineManager.getOrCreateShadowPipeline(),
                  inEncoder: commandEncoder)

        for model in self.scene.objects
        {
            encodeRenderCommand(encoder:    commandEncoder,
                                object:     model,
                                passType:   .Shadows)
        }
        commandEncoder.endEncoding()
    }

    func renderGBuffer()
    {
        let view = self.scene.mainCamera.getView()
        let proj = self.scene.mainCamera.getProjection()

        let renderPassDesc = MTLRenderPassDescriptor()
        // Albedo & metallic
        renderPassDesc.colorAttachments[0].texture     = self.gBufferAlbedoAndMetallic
        renderPassDesc.colorAttachments[0].loadAction  = .clear
        renderPassDesc.colorAttachments[0].storeAction = .store
        // Normal & roughness
        renderPassDesc.colorAttachments[1].texture     = self.gBufferNormalAndRoughness
        renderPassDesc.colorAttachments[1].loadAction  = .clear
        renderPassDesc.colorAttachments[1].storeAction = .store
        // G-Buffer Depth
        renderPassDesc.colorAttachments[2].texture     = self.gBufferDepth
        renderPassDesc.colorAttachments[2].loadAction  = .clear
        renderPassDesc.colorAttachments[2].storeAction = .store
        // Depth buffer
        renderPassDesc.depthAttachment.texture          = self.depthStencil
        renderPassDesc.depthAttachment.loadAction       = .clear
        renderPassDesc.depthAttachment.storeAction      = .store
        // Stencil buffer
        renderPassDesc.stencilAttachment.texture        = self.depthStencil
        renderPassDesc.stencilAttachment.loadAction     = .clear
        renderPassDesc.stencilAttachment.storeAction    = .store

        guard let commandEncoder = self.currentCommandBuffer?
                                       .makeRenderCommandEncoder(descriptor: renderPassDesc) else
        {
            SimpleLogs.ERROR("Couldn't creater a command encoder. Skipping pass.")
            return
        }
        commandEncoder.label = "G-Buffer pass"

        self.boundResources.removeAll()

        commandEncoder.setDepthStencilState(self.mainDepthStencilState)
        
        // Set Scene buffers
        commandEncoder.setVertexBytes(view.asPackedArray() + proj.asPackedArray(),
                                      length: Matrix4x4.size() * 2,
                                      index: SCENE_MATRICES_INDEX)

        for model in self.scene.objects
        {
            encodeRenderCommand(encoder:    commandEncoder,
                                object:     model,
                                passType:   .GBuffer)
        }

        commandEncoder.endEncoding()
    }


    func applyDeferredLighting()
    {
        guard let renderPassDesc = mView.currentRenderPassDescriptor else
        {
            SimpleLogs.ERROR("No render pass descriptor. Skipping pass.")
            return
        }
        renderPassDesc.depthAttachment.texture          = self.depthStencil
        renderPassDesc.depthAttachment.loadAction       = .load
        renderPassDesc.depthAttachment.storeAction      = .dontCare

        renderPassDesc.stencilAttachment.texture        = self.depthStencil
        renderPassDesc.stencilAttachment.loadAction     = .load
        renderPassDesc.stencilAttachment.storeAction    = .dontCare

        guard let commandEncoder = self.currentCommandBuffer?
                                       .makeRenderCommandEncoder(descriptor: renderPassDesc) else
        {
            SimpleLogs.ERROR("Couldn't create a command encoder. Skipping pass.")
            return
        }
        commandEncoder.label = "Deferred lighting / composition"

        commandEncoder.setCullMode(.back)
        
        // In the lighting stage we want to shade the fragments that have already been "touched",
        // while in the skybox draw call we'll shade the ones that haven't
        commandEncoder.setStencilReferenceValue(0)
        commandEncoder.setDepthStencilState(self.screenSpaceLightingStencilState)

        self.boundResources.removeAll()

        self.bind(pipeline: self.pipelineManager.getOrCreateDeferredLightingPipeline(),
                  inEncoder: commandEncoder)

        self.bind(texture: self.gBufferAlbedoAndMetallic,
                  at: BindingPoint(index: ALBEDO_AND_METALLIC_INDEX, stage: .Fragment),
                  inEncoder: commandEncoder)

        self.bind(texture: self.gBufferNormalAndRoughness,
                  at: BindingPoint(index: NORMAL_AND_ROUGHNESS_INDEX, stage: .Fragment),
                  inEncoder: commandEncoder)

        self.bind(texture: self.gBufferDepth,
                  at: BindingPoint(index: DEPTH_INDEX, stage: .Fragment),
                  inEncoder: commandEncoder)

        self.bind(texture: self.shadowMap,
                  at: BindingPoint(index: SHADOW_MAP_INDEX, stage: .Fragment),
                  inEncoder: commandEncoder)

        commandEncoder.setVertexBytes(
            self.scene.mainCamera.getView().asPackedArray()
                + self.scene.mainCamera.getProjection().asPackedArray(),
            length: Matrix4x4.size() * 2,
            index: SCENE_MATRICES_INDEX)

        commandEncoder.setVertexBytes(
            self.scene.mainCamera.getPosition().asPackedArray(),
            length: MemoryLayout<Vector3>.size,
            index: CAMERA_POSITION_INDEX)

        // TODO: Invert the matrices
        commandEncoder.setFragmentBytes(self.scene.mainCamera.getView().asPackedArray() +
                                            self.scene.mainCamera.getProjection().asPackedArray(),
                                        length: Matrix4x4.size() * 2,
                                        index: SCENE_MATRICES_INDEX)

        // TODO: Multiple lights
        let dirLight = self.scene.lights[0] as! DirectionalLight
        // Transform the light direction into view space to save the conversion in the shader
        let directionInViewSpace = scene.mainCamera.getView() * -Vector4(dirLight.getDirection(), 0)
        commandEncoder.setFragmentBytes(directionInViewSpace.normalized().asPackedArray() +
                                            dirLight.color.asPackedArray(),
                                        length: dirLight.getBufferSize(),
                                        index: LIGHTS_BUFFER_INDEX)

        let lightMatrix = (dirLight.projection ?? .identity()) * dirLight.getView()
        commandEncoder.setFragmentBytes(lightMatrix.asPackedArray(),
                                        length: Matrix4x4.size(),
                                        index: LIGHT_MATRIX_INDEX)

        // TODO: Use a big triangle instead of a quad
        commandEncoder.drawIndexedPrimitives(
             type:               .triangleStrip,
             indexCount:         6,
             indexType:          .uint16,
             indexBuffer:        self.quadIndexBuffer,
             indexBufferOffset:  0)

        // Skybox
        if let skybox = self.scene.skybox
        {
            commandEncoder.setDepthStencilState(self.skyboxDepthStencilState)

            encodeRenderCommand(encoder:    commandEncoder,
                                object:     skybox,
                                passType:   .ScreenSpace)
        }

        // Grid plane
        commandEncoder.setCullMode(.none) // We want to still see the plane from bellow

        // The grid is just a normal plane and needs depth testing
        commandEncoder.setDepthStencilState(self.mainDepthStencilState)

        self.bind(
            pipeline: self.pipelineManager.getOrCreateGridGizmoPipeline(),
            inEncoder: commandEncoder)

        // The vertex positions are hardcoded in the shader
        commandEncoder.drawIndexedPrimitives(
            type:               .triangleStrip,
            indexCount:         6,
            indexType:          .uint16,
            indexBuffer:        self.quadIndexBuffer,
            indexBufferOffset:  0)

        commandEncoder.endEncoding()
    }

    /// Main pass. Renders the scene objects in a forward way.
    func renderSceneForward()
    {
        let view = self.scene.mainCamera.getView()
        let proj = self.scene.mainCamera.getProjection()

        guard let renderPassDesc = mView.currentRenderPassDescriptor else
        {
            // TODO: Create a dedicated render pass descriptor
            SimpleLogs.ERROR("No render pass descriptor. Skipping pass.")
            return
        }
        renderPassDesc.depthAttachment.texture          = self.depthStencil
        renderPassDesc.depthAttachment.loadAction       = .clear
        renderPassDesc.depthAttachment.storeAction      = .dontCare

        renderPassDesc.stencilAttachment.texture        = self.depthStencil
        renderPassDesc.stencilAttachment.loadAction     = .clear
        renderPassDesc.stencilAttachment.storeAction    = .dontCare

        guard let commandEncoder = self.currentCommandBuffer?
                                       .makeRenderCommandEncoder(descriptor: renderPassDesc) else
        {
            SimpleLogs.ERROR("Couldn't creater a command encoder. Skipping pass.")
            return
        }
        commandEncoder.label = "Main pass"

        self.boundResources.removeAll()

        commandEncoder.setDepthStencilState(self.mainDepthStencilState)

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

        self.bind(texture: self.shadowMap,
                  at: BindingPoint(index: SHADOW_MAP_INDEX, stage: .Fragment),
                  inEncoder: commandEncoder)

        for model in self.scene.objects
        {
            encodeRenderCommand(encoder:    commandEncoder,
                                object:      model,
                                passType:   .ForwardLighting)
        }

        if let skybox = self.scene.skybox
        {
            commandEncoder.setDepthStencilState(self.skyboxDepthStencilState)
            commandEncoder.setStencilReferenceValue(0) // We only want to write to the untouched fragments

            encodeRenderCommand(encoder:    commandEncoder,
                                object:     skybox,
                                passType:   .ScreenSpace)
        }

        commandEncoder.endEncoding()
    }

    public var mView: MTKView

    // MARK: - Private
    private func renderGizmos()
    {
        SimpleLogs.UNIMPLEMENTED("")
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

    /// Creates a new texture to be used as a depth/stencil buffer
    /// - Parameters:
    ///     - width
    ///     - height
    ///     - format: Must be a depth/stencil format
    ///     - device: The MTLDevice that will create the texture
    /// - Returns:
    ///     - depthStencil
    static private func createDepthStencilTexture(width:  Int,
                                                  height: Int,
                                                  format: MTLPixelFormat,
                                                  device: MTLDevice)
    -> MTLTexture
    {
        assert(format == .depth16Unorm || format == .depth32Float ||
               format == .stencil8 ||
               format == .depth24Unorm_stencil8 || format == .depth32Float_stencil8)

        let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: format,
                                                            width:       width,
                                                            height:      height,
                                                            mipmapped:   false)
        desc.storageMode = .private
        desc.usage       = .renderTarget
        desc.sampleCount = 1

        guard let ds = device.makeTexture(descriptor: desc) else
        {
            // TODO: Handle this gracefully
            fatalError("Couldn't create the depth/stencil")
        }
        return ds
    }

    /// Creates the internal depth/stencil states
    /// - Parameters:
    ///     - device: The MTLDevice used to create the states
    private func createDepthStencilStates(device: MTLDevice)
    {
        // Shadow
        let depthStencilDesc = MTLDepthStencilDescriptor()
        depthStencilDesc.depthCompareFunction = .less
        depthStencilDesc.isDepthWriteEnabled  = true

        guard let sds = device.makeDepthStencilState(descriptor: depthStencilDesc) else
        {
            fatalError("Couldn't create the shadow depth/stencil state")
        }
        self.shadowDepthStencilState = sds

        // Main
        let stencilDesc = MTLStencilDescriptor()
        stencilDesc.depthStencilPassOperation   = .incrementClamp
        stencilDesc.stencilCompareFunction      = .always // The main pass always writes to the stencil

        depthStencilDesc.frontFaceStencil = stencilDesc
        depthStencilDesc.backFaceStencil  = stencilDesc
        guard let mds = device.makeDepthStencilState(descriptor: depthStencilDesc) else
        {
            fatalError("Couldn't create the shadow depth/stencil state")
        }
        self.mainDepthStencilState = mds

        let screenSpaceDSDesc = MTLDepthStencilDescriptor()
        // Don't write to the stencil anymore
        screenSpaceDSDesc.frontFaceStencil.depthStencilPassOperation = .keep
        // The screen-space quad will be in front of the camera so we have to ignore the depth
        screenSpaceDSDesc.isDepthWriteEnabled  = false
        screenSpaceDSDesc.depthCompareFunction = .always

        // Screen-space lighting
        // Only write to the fragments that have been already "touched" (reference will be 0)
        screenSpaceDSDesc.frontFaceStencil.stencilCompareFunction = .less
        screenSpaceDSDesc.backFaceStencil.stencilCompareFunction = .less
        if let ds = device.makeDepthStencilState(descriptor: screenSpaceDSDesc)
        {
            self.screenSpaceLightingStencilState = ds
        }
        else
        {
            fatalError("Couldn't create the screen space lighting depth/stencil state")
        }

        // Skybox
        // Only write to the untouched fragments
        screenSpaceDSDesc.frontFaceStencil.stencilCompareFunction = .equal
        if let ds = device.makeDepthStencilState(descriptor: screenSpaceDSDesc)
        {
            self.skyboxDepthStencilState = ds
        }
        else
        {
            fatalError("Couldn't create the screen space depth/stencil state")
        }
    }

    private func createMaterials(device: MTLDevice)
    {
        let mainPipeline = self.pipelineManager.getOrCreateGBufferPipeline()

        let material1 = Material(pipeline: mainPipeline, label: TEST_MATERIAL_NAME_1)
        if let tex = Self.loadTexture(name: TEST_TEXTURE_NAME_1,
                                      index: ALBEDO_MAP_INDEX,
                                      device: device)
        {
            material1.textures.append(tex)
        }

        let material2 = material1.copy() as! Material
        material2.label = TEST_MATERIAL_NAME_2
        if let tex = Self.loadTexture(name: TEST_TEXTURE_NAME_2,
                                      index: ALBEDO_MAP_INDEX,
                                      device: device)
        {
            material2.swapTexture(idx: 0, newTexture: tex)
        }
        material2.params.setTint(Vector3(x:1, y:1, z:0))
        material2.params.setRoughness(0.15)

        var whiteTex = Texture(mtlTexture: self.dummyTexture,
                               label: "Dummy")
        whiteTex.setIndex(0, stage: .Fragment)

        let material3 = material1.copy() as! Material
        material3.label = WHITE_MATERIAL_NAME
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

        self.scene = Scene().add(camera: cam)
                            .add(light: light)

        self.loadModels(intoScene: self.scene, withDevice: device)
    }

    /// Loads models from file into the scene using a scene builder
    /// - Parameters:
    ///     - scene: Passed by reference, the new models will be added to it
    ///     - device
    // TODO: Read model and transform data from file
    private func loadModels(intoScene scene: Scene, withDevice device: MTLDevice)
    {
        // BUNNY
        if let modelURL = Bundle.main.url(forResource: BUNNY_MODEL_NAME,
                                          withExtension: OBJ_FILE_EXTENSION)
        {
            let model = Model(device: device,
                              url: modelURL,
                              material: self.materials[WHITE_MATERIAL_NAME] ?? self.defaultMaterial,
                              label: "Stanford Bunny")

            let rotDegrees = SLA.rad2deg(0.5 * TAU)
            model.rotate(localEulerAngles: Vector3(x: 0, y: rotDegrees, z: 0))
            model.move(to: Vector3(x:-0.15, y:0, z:0))
            // model.flipHandedness()

            scene.add(object: model)
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
                              label: "Utah Teapot",
                              culling: .none)

            model.scale(by: 0.01)
            model.move(to: Vector3(x:0.15, y:0.075, z:0))

            scene.add(object: model)
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
                              label: "Floor",
                              culling: .none)

            scene.add(object: model)
        }
        else
        {
            SimpleLogs.ERROR("Couldn't load model '" + QUAD_MODEL_NAME + "." + OBJ_FILE_EXTENSION + "'")
        }

        // TODO: Replace with a triangle
        if let modelURL = Bundle.main.url(forResource: QUAD_MODEL_NAME,
                                          withExtension: OBJ_FILE_EXTENSION)
        {
            let model = Model(device: device,
                              url: modelURL,
                              material: self.skyboxMaterial,
                              label: "Screen Space Skybox",
                              culling: .back)

            self.scene.set(skybox: model)
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

    // TODO: Refactor or delete this whole thing
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
        if passType != .ScreenSpace
        {
            // Screen-space passes don't need a vertex buffer because the vertex positions are
            // hardcoded. All they need is the index buffer.
            self.bind(buffer:       object.getVertexBuffer(),
                      at:           BindingPoint(index: VERTEX_BUFFER_INDEX, stage: .Vertex),
                      withOffset:   0,
                      inEncoder:    encoder)
        }

        // Bind fragment resources
        switch passType
        {
        case .ForwardLighting:
            objMatrixData.append(contentsOf: object.getNormalMatrix().asPackedArray() )

            encoder.setVertexBytes(objMatrixData,
                                   length: MemoryLayout<Float>.size * objMatrixData.count,
                                   index: OBJECT_MATRICES_INDEX)

            encoder.setFragmentBytes(objMatrixData,
                                     length: MemoryLayout<Float>.size * objMatrixData.count,
                                     index: OBJECT_MATRICES_INDEX)

            // TODO: Sort the models by material
            let material = object.getMaterial()
            assert(material.pipeline.type == .ForwardLighting)
            self.bind(pipeline: material.pipeline, inEncoder: encoder)

            encoder.setFrontFacing(object.getWinding())

            encoder.setFragmentBytes(material.params.getPackedData(),
                                     length: MaterialParams.packedSize,
                                     index: MATERIAL_PARAMS_INDEX)

            // Set Textures
            for texture in material.textures
            {
                if let idx = texture.getIndexAtStage(.Vertex)
                {
                    self.bind(texture: texture.getResource() as! MTLTexture,
                              at: BindingPoint(index: idx, stage: .Vertex),
                              inEncoder: encoder)
                }
                if let idx = texture.getIndexAtStage(.Fragment)
                {
                    self.bind(texture: texture.getResource() as! MTLTexture,
                              at: BindingPoint(index: idx, stage: .Fragment),
                              inEncoder: encoder)
                }
            }

        case .Shadows:
            // The shadow passes don't have a fragment stage and don't need materials
            encoder.setVertexBytes(objMatrixData,
                                   length: MemoryLayout<Float>.size * objMatrixData.count,
                                   index: OBJECT_MATRICES_INDEX)
            break

        case .ScreenSpace:
            // A screen space pass won't need the object's matrices because the transformed position
            // is fixed.
            // It won't need the material parameters either because doesn't have a "real" material.
            let material = object.getMaterial()
            assert(material.pipeline.type == .ScreenSpace)
            self.bind(pipeline: material.pipeline, inEncoder: encoder)

            // Set Textures
            for texture in material.textures
            {
                if let idx = texture.getIndexAtStage(.Vertex)
                {
                    self.bind(texture: texture.getResource() as! MTLTexture,
                              at: BindingPoint(index: idx, stage: .Vertex),
                              inEncoder: encoder)
                }
                if let idx = texture.getIndexAtStage(.Fragment)
                {
                    self.bind(texture: texture.getResource() as! MTLTexture,
                              at: BindingPoint(index: idx, stage: .Fragment),
                              inEncoder: encoder)
                }
            }
            break

        case .GBuffer:
            objMatrixData.append(contentsOf: object.getNormalMatrix().asPackedArray() )

            encoder.setVertexBytes(objMatrixData,
                                   length: MemoryLayout<Float>.size * objMatrixData.count,
                                   index: OBJECT_MATRICES_INDEX)

            // TODO: Sort the models by material
            let material = object.getMaterial()
            assert(material.pipeline.type == .GBuffer)
            self.bind(pipeline: material.pipeline, inEncoder: encoder)

            encoder.setFrontFacing(object.getWinding())

            encoder.setFragmentBytes(material.params.getPackedData(),
                                     length: MaterialParams.packedSize,
                                     index: MATERIAL_PARAMS_INDEX)

            // Set Textures
            for texture in material.textures
            {
                if let idx = texture.getIndexAtStage(.Fragment)
                {
                    self.bind(texture: texture.getResource() as! MTLTexture,
                              at: BindingPoint(index: idx, stage: .Fragment),
                              inEncoder: encoder)
                }
            }

        case .DeferredComposite:
            UNIMPLEMENTED("Deferred composite pass is not supported yet")
        }

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

    /// Binds a buffer in a render command encoder
    /// - Parameters:
    ///     - buffer
    ///     - bindingPoint: Index and stage
    ///     - offset
    ///     - encoder
    // TODO: Use a closure to use this for any resource and any encoder?
    private func bind(buffer:                   MTLBuffer,
                      at            bindPoint:  BindingPoint,
                      withOffset    offset:     Int,
                      inEncoder     encoder:    MTLRenderCommandEncoder)
    {
        let id = ObjectIdentifier(buffer)

        if self.boundResources[bindPoint] == id
        {
            return
        }

        switch bindPoint.stage
        {
        case .Vertex:
            encoder.setVertexBuffer(buffer, offset: offset, index: bindPoint.index)
        case .Fragment:
            encoder.setFragmentBuffer(buffer, offset: offset, index: bindPoint.index)
        default:
            ERROR("Invalid stage. Only for render command encoders.")
            return
        }

        self.boundResources[bindPoint] = id
    }

    /// Binds a texture in a render command encoder
    /// - Parameters:
    ///     - texture
    ///     - bindingPoint: Index and stage
    ///     - encoder
    // TODO: Use a closure to use this for any resource and any encoder?
    private func bind(texture:              MTLTexture,
                      at        bindPoint:  BindingPoint,
                      inEncoder encoder:    MTLRenderCommandEncoder)
    {
        let id = ObjectIdentifier(texture)

        if self.boundResources[bindPoint] == id
        {
            return
        }

        switch bindPoint.stage
        {
        case .Vertex:
            encoder.setVertexTexture(texture, index: bindPoint.index)
        case .Fragment:
            encoder.setFragmentTexture(texture, index: bindPoint.index)
        default:
            ERROR("Invalid stage. Only for render command encoders.")
            return
        }

        self.boundResources[bindPoint] = id
    }

    /// Binds a Pipeline State if it's not already bound
    /// - Parameters:
    ///     - pipeline
    ///     - encoder
    private func bind(pipeline: Pipeline, inEncoder encoder: MTLRenderCommandEncoder)
    {
        // TODO: Track them per encoder so it can be used in a multithreaded way
        let psoID = ObjectIdentifier(pipeline)
        if  psoID != self.currentlyBoundPipelineID
        {
            encoder.setRenderPipelineState(pipeline.state)
            self.currentlyBoundPipelineID = psoID
        }
    }

    private let commandQueue:  MTLCommandQueue
    private var currentCommandBuffer: MTLCommandBuffer?

    // TODO: pipeline cache
    private let pipelineManager: PipelineManager
    private var currentlyBoundPipelineID: ObjectIdentifier? = nil // TODO: Per encoder

    private var mainDepthStencilState:              MTLDepthStencilState!
    private var shadowDepthStencilState:            MTLDepthStencilState!
    private var screenSpaceLightingStencilState:    MTLDepthStencilState!
    private var skyboxDepthStencilState:            MTLDepthStencilState!

    private var shadowMap:    MTLTexture
    private var depthStencil: MTLTexture
    private let dummyTexture: MTLTexture

    // G-Buffer
    private let gBufferAlbedoAndMetallic: MTLTexture
    private let gBufferNormalAndRoughness: MTLTexture
    private let gBufferDepth: MTLTexture

    private let quadIndexBuffer: MTLBuffer!

    private var scene: Scene!

    private let defaultMaterial: Material
    private let skyboxMaterial: Material
    private var materials: [String: Material] = [:]

    private var boundResources: [BindingPoint: ObjectIdentifier] = [:] // TODO: Per encoder?
}
