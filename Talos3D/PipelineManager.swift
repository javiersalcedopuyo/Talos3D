//
//  PipelineManager.swift
//  Talos3D
//
//  Created by Javier Salcedo on 17/4/23.
//

import MetalKit

// TODO: Throw an error instead of crashing if the pipelines fail to be created
// TODO: Allow to create pipelines on demand / runtime

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
    }

    /// Lazily gets the default pipeline
    public func getOrCreateDefaultPipeline() -> Pipeline
    {
        if let pipeline = self.defaultPipeline
        {
            return pipeline
        }

        let desc = MTLRenderPipelineDescriptor()
        desc.label                            = "Default PSO"
        desc.vertexFunction                   = self.shaderLibrary.makeFunction(name: "default_vertex_main")
        desc.fragmentFunction                 = self.shaderLibrary.makeFunction(name: "default_fragment_main")
        desc.vertexDescriptor                 = Model.getNewVertexDescriptor()
        desc.colorAttachments[0].pixelFormat  = self.colorFormat
        desc.depthAttachmentPixelFormat       = .depth32Float_stencil8
        desc.stencilAttachmentPixelFormat     = .depth32Float_stencil8

        guard let pipeline = Pipeline(desc: desc,
                                      device: device,
                                      type: .ForwardLighting) else
        {
            fatalError("☠️ Couldn't create default pipeline state")
        }

        self.defaultPipeline = pipeline
        return pipeline
    }

    /// Lazily gets the main pipeline
    public func getOrCreateMainPipeline() -> Pipeline
    {
        if let pipeline = self.mainPipeline
        {
            return pipeline
        }

        let desc = MTLRenderPipelineDescriptor()
        desc.label                            = "Main PSO"
        desc.vertexFunction                   = self.shaderLibrary.makeFunction(name: "vertex_main")
        desc.fragmentFunction                 = self.shaderLibrary.makeFunction(name: "fragment_main")
        desc.vertexDescriptor                 = Model.getNewVertexDescriptor()
        desc.colorAttachments[0].pixelFormat  = self.colorFormat
        desc.depthAttachmentPixelFormat       = .depth32Float_stencil8
        desc.stencilAttachmentPixelFormat     = .depth32Float_stencil8

        guard let pipeline = Pipeline(desc: desc,
                                      device: device,
                                      type: .ForwardLighting) else
        {
            fatalError("☠️ Couldn't create main pipeline state")
        }

        self.mainPipeline = pipeline
        return pipeline
    }

    /// Lazily gets the shadow pipeline
    public func getOrCreateShadowPipeline() -> Pipeline
    {
        if let pipeline = self.shadowPipeline
        {
            return pipeline
        }

        let desc = MTLRenderPipelineDescriptor()
        desc.label                            = "Shadow PSO"
        desc.vertexFunction                   = self.shaderLibrary.makeFunction(name: "shadow_vertex_main")
        desc.fragmentFunction                 = nil
        desc.vertexDescriptor                 = Model.getNewVertexDescriptor()
        desc.colorAttachments[0].pixelFormat  = .invalid
        desc.depthAttachmentPixelFormat       = .depth16Unorm // TODO: Tie this to the shadow map
        desc.stencilAttachmentPixelFormat     = .invalid

        guard let pipeline = Pipeline(desc: desc,
                                      device: device,
                                      type: .Shadows) else
        {
            fatalError("☠️ Couldn't create shadow pipeline state")
        }

        self.shadowPipeline = pipeline
        return pipeline
    }

    /// Lazily gets the skybox pipeline
    public func getOrCreateSkyboxPipeline() -> Pipeline
    {
        if let pipeline = self.skyboxPipeline
        {
            return pipeline
        }

        let desc = MTLRenderPipelineDescriptor()
        desc.label                            = "Skybox PSO"
        desc.vertexFunction                   = self.shaderLibrary.makeFunction(name: "skybox_vertex_main")
        desc.fragmentFunction                 = self.shaderLibrary.makeFunction(name: "skybox_fragment_main")
        desc.vertexDescriptor                 = MTLVertexDescriptor() // Empty
        desc.colorAttachments[0].pixelFormat  = self.colorFormat
        desc.depthAttachmentPixelFormat       = .depth32Float_stencil8
        desc.stencilAttachmentPixelFormat     = .depth32Float_stencil8

        guard let pipeline = Pipeline(desc:   desc,
                                      device: device,
                                      type:   .ScreenSpace)
        else
        {
            fatalError("☠️ Couldn't create the skybox pipeline state")
        }

        self.skyboxPipeline = pipeline
        return pipeline
    }

    // - MARK: Private
    private let shaderLibrary:      MTLLibrary
    private let device:             MTLDevice
    private let colorFormat:        MTLPixelFormat

    private var mainPipeline:       Pipeline? = nil
    private var defaultPipeline:    Pipeline? = nil
    private var shadowPipeline:     Pipeline? = nil
    private var skyboxPipeline:     Pipeline? = nil
}
