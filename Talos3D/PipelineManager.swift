//
//  PipelineManager.swift
//  Talos3D
//
//  Created by Javier Salcedo on 17/4/23.
//
// TODO: Throw an error instead of crashing if the pipelines fail to be created
// TODO: Allow to create pipelines on demand / runtime
// TODO: Use handles


// MARK: Imports
import MetalKit
import SimpleLogs


// MARK: Constants and enums
enum PipelineID: Int
{
    case defaultPSO = 0
    case forwardLighting
    case deferredLighting
    case GBuffer
    case shadow
    case skybox
    case gridGizmo

    static var count: Int { Self.gridGizmo.rawValue + 1 }
}


// MARK: Types
typealias Timestamp = TimeInterval

class PipelineManager
{
    // - MARK: Public
    init(view: MTKView)
    {
        self.colorFormat = view.colorPixelFormat

        guard let d = view.device else
        {
            fatalError("☠️ The view doesn't have an associated device.")
        }
        self.device = d

        guard let lib = d.makeDefaultLibrary() else
        {
            fatalError("☠️ Couldn't create the default shader library.")
        }
        self.shaderLibrary = lib
        self.lastShaderUpdate = Date.now.timeIntervalSince1970
        self.recompiledShaderLibURL = FileManager
            .default
            .temporaryDirectory
            .appending(path: "shaders/recompiled.metallib")

        self.pipelines = Array(repeating: nil, count: PipelineID.count)
    }


    /// Lazily gets the pipeline associated with the provided ID
    /// - Parameters:
    ///     - id
    /// - Returns:
    ///     - The associated pipeline. If it doesn't exist yet, it creates it first.
    public func getOrCreatePipeline(_ id: PipelineID) -> Pipeline
    {
        if let pipeline = self.pipelines[id.rawValue]
        {
            return pipeline
        }

        let passType = Self.getPassType( ofPipeline: id )
        let desc = self.makeDescriptor( forPipeline: id )

        guard let pipeline = Pipeline(
            desc:   desc,
            device: self.device,
            type:   passType )
        else
        {
            fatalError("☠️ Couldn't create \(desc.label ?? "_unnamed_")'s PSO")
        }
        self.pipelines[id.rawValue] = pipeline
        return pipeline
    }

    /// Reloads the shader library if a newer binary is found in the expected path
    /// - Returns:
    ///     - Wether the library was reloaded or not (can be discarded)
    @discardableResult
    public func reloadShadersIfNecessary() -> Bool
    {
        let fm = FileManager.default
        if !fm.fileExists( atPath: self.recompiledShaderLibURL.path() )
        {
            return false
        }

        do
        {
            let attributesDict = try fm.attributesOfItem( atPath: self.recompiledShaderLibURL.path() )
            guard let lastModification = attributesDict[.modificationDate] as? NSDate else
            {
                ERROR("Couldn't obtain the shader's lib last modification date.")
                return false
            }

            if lastModification.timeIntervalSince1970 <= self.lastShaderUpdate
            {
                // We're already using the latest lib
                return false
            }
            self.shaderLibrary = try self.device.makeLibrary(URL: self.recompiledShaderLibURL)
            self.lastShaderUpdate = lastModification.timeIntervalSince1970
            self.resetAllPipelines() // TODO: Reset only the affected pipelines
            return true
        }
        catch
        {
            ERROR("Failed reloading shaders: \(error)")
            return false
        }
    }


    // MARK: - Private methods
    private func resetAllPipelines()
    {
        for i in 0..<self.pipelines.count
        {
            self.pipelines[i] = nil
        }
    }


    private static func getPassType(ofPipeline id: PipelineID) -> PassType
    {
        switch id
        {
            case .shadow:
                return .Shadows
            case .skybox, .deferredLighting, .gridGizmo:
                return .ScreenSpace
            case .GBuffer:
                return .GBuffer
            case .defaultPSO, .forwardLighting:
                return .ForwardLighting
        }
    }


    private func makeDescriptor(forPipeline id: PipelineID) -> MTLRenderPipelineDescriptor
    {
        switch id
        {
            case .defaultPSO:
                return self.makeDefaultDescriptor()
            case .forwardLighting:
                return self.makeForwardDescriptor()
            case .deferredLighting:
                return self.makeDeferredDescriptor()
            case .GBuffer:
                return self.makeGBufferDescriptor()
            case .shadow:
                return self.makeShadowDescriptor()
            case .skybox:
                return self.makeSkyboxDescriptor()
            case .gridGizmo:
                return self.makeGridGizmoDescriptor()
        }
    }

    
    // MARK: Descriptors' creation
    private func makeDefaultDescriptor() -> MTLRenderPipelineDescriptor
    {
        let desc = MTLRenderPipelineDescriptor()
        desc.label                            = "Default PSO"
        desc.vertexFunction                   = self.shaderLibrary.makeFunction(name: "default_vertex_main")
        desc.fragmentFunction                 = self.shaderLibrary.makeFunction(name: "default_fragment_main")
        desc.vertexDescriptor                 = Model.getNewVertexDescriptor()
        desc.colorAttachments[0].pixelFormat  = self.colorFormat
        desc.depthAttachmentPixelFormat       = .depth32Float_stencil8
        desc.stencilAttachmentPixelFormat     = .depth32Float_stencil8
        return desc
    }

    private func makeForwardDescriptor() -> MTLRenderPipelineDescriptor
    {
        let desc = MTLRenderPipelineDescriptor()
        desc.label                            = "Forward PSO"
        desc.vertexFunction                   = self.shaderLibrary.makeFunction(name: "vertex_main")
        desc.fragmentFunction                 = self.shaderLibrary.makeFunction(name: "fragment_main")
        desc.vertexDescriptor                 = Model.getNewVertexDescriptor()
        desc.colorAttachments[0].pixelFormat  = self.colorFormat
        desc.depthAttachmentPixelFormat       = .depth32Float_stencil8
        desc.stencilAttachmentPixelFormat     = .depth32Float_stencil8
        return desc
    }

    private func makeDeferredDescriptor() -> MTLRenderPipelineDescriptor
    {
        let desc = MTLRenderPipelineDescriptor()
        desc.label                            = "Deferred PSO"
        desc.vertexFunction                   = self.shaderLibrary.makeFunction(name: "deferred_lighting_vertex_main")
        desc.fragmentFunction                 = self.shaderLibrary.makeFunction(name: "deferred_lighting_fragment_main")
        desc.vertexDescriptor                 = MTLVertexDescriptor() // Empty
        desc.colorAttachments[0].pixelFormat  = self.colorFormat
        desc.depthAttachmentPixelFormat       = .depth32Float_stencil8
        desc.stencilAttachmentPixelFormat     = .depth32Float_stencil8
        return desc
    }

    private func makeGBufferDescriptor() -> MTLRenderPipelineDescriptor
    {
        let desc = MTLRenderPipelineDescriptor()
        desc.label                            = "G-Buffer PSO"
        desc.vertexFunction                   = self.shaderLibrary.makeFunction(name: "g_buffer_vertex_main")
        desc.fragmentFunction                 = self.shaderLibrary.makeFunction(name: "g_buffer_fragment_main")
        desc.vertexDescriptor                 = Model.getNewVertexDescriptor()
        desc.colorAttachments[0].pixelFormat  = .rgba32Float // Albedo & metallic
        desc.colorAttachments[1].pixelFormat  = .rgba32Float // Normal & roughness
        desc.colorAttachments[2].pixelFormat  = .r32Float   // Depth
        desc.depthAttachmentPixelFormat       = .depth32Float_stencil8
        desc.stencilAttachmentPixelFormat     = .depth32Float_stencil8
        return desc
    }

    private func makeShadowDescriptor() -> MTLRenderPipelineDescriptor
    {
        let desc = MTLRenderPipelineDescriptor()
        desc.label                            = "Shadow PSO"
        desc.vertexFunction                   = self.shaderLibrary.makeFunction(name: "shadow_vertex_main")
        desc.fragmentFunction                 = nil
        desc.vertexDescriptor                 = Model.getNewVertexDescriptor()
        desc.colorAttachments[0].pixelFormat  = .invalid
        desc.depthAttachmentPixelFormat       = .depth16Unorm // TODO: Tie this to the shadow map
        desc.stencilAttachmentPixelFormat     = .invalid
        return desc
    }

    private func makeSkyboxDescriptor() -> MTLRenderPipelineDescriptor
    {
        let desc = MTLRenderPipelineDescriptor()
        desc.label                            = "Skybox PSO"
        desc.vertexFunction                   = self.shaderLibrary.makeFunction(name: "skybox_vertex_main")
        desc.fragmentFunction                 = self.shaderLibrary.makeFunction(name: "skybox_fragment_main")
        desc.vertexDescriptor                 = MTLVertexDescriptor() // Empty
        desc.colorAttachments[0].pixelFormat  = self.colorFormat
        desc.depthAttachmentPixelFormat       = .depth32Float_stencil8
        desc.stencilAttachmentPixelFormat     = .depth32Float_stencil8
        return desc
    }

    private func makeGridGizmoDescriptor() -> MTLRenderPipelineDescriptor
    {
        let desc = MTLRenderPipelineDescriptor()
        desc.label                            = "Grid Gizmo PSO"
        desc.vertexFunction                   = self.shaderLibrary.makeFunction(name: "grid_gizmo_vertex_main")
        desc.fragmentFunction                 = self.shaderLibrary.makeFunction(name: "grid_gizmo_fragment_main")
        desc.vertexDescriptor                 = MTLVertexDescriptor() // Empty
        desc.depthAttachmentPixelFormat       = .depth32Float_stencil8
        desc.stencilAttachmentPixelFormat     = .depth32Float_stencil8

        desc.colorAttachments[0].pixelFormat                    = self.colorFormat
        desc.colorAttachments[0].isBlendingEnabled              = true
        desc.colorAttachments[0].rgbBlendOperation              = .add
        desc.colorAttachments[0].sourceRGBBlendFactor           = .sourceAlpha
        desc.colorAttachments[0].destinationRGBBlendFactor      = .oneMinusSourceAlpha
        desc.colorAttachments[0].alphaBlendOperation            = .add
        desc.colorAttachments[0].sourceAlphaBlendFactor         = .sourceAlpha
        desc.colorAttachments[0].destinationAlphaBlendFactor    = .oneMinusSourceAlpha
        return desc
    }


    // MARK: Private members
    private var shaderLibrary: MTLLibrary
    private let device:        MTLDevice
    private let colorFormat:   MTLPixelFormat
    private var pipelines:     [Pipeline?]

    private var lastShaderUpdate: Timestamp
    private let recompiledShaderLibURL: URL
}
