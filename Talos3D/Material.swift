//
//  Material.swift
//  Talos3D
//
//  Created by Javier Salcedo on 18/8/22.
//

import MetalKit
import SLA
import SimpleLogs

public class Material : NSCopying
{
    init(pipeline pso: Pipeline)
    {
        pipeline = pso
        params   = nil
        textures = []
        samplers = []
    }

    public func copy(with zone: NSZone? = nil) -> Any
    {
        let newMaterial = Material(pipeline: self.pipeline)
        newMaterial.textures = self.textures
        newMaterial.samplers = self.samplers
        newMaterial.params   = self.params
        return newMaterial
    }

    func getVertexShader()   -> MTLFunction? { pipeline.descriptor.vertexFunction }
    func getFragmentShader() -> MTLFunction? { pipeline.descriptor.fragmentFunction }

    func swapTexture(idx: Int, newTexture: Texture)
    {
        if idx >= self.textures.count
        {
            SimpleLogs.ERROR("Index is out of bounds.")
            return
        }

        self.textures[idx] = newTexture
    }

    let pipeline: Pipeline
    var params:   MaterialParams?
    var textures: [Texture]
    var samplers: [MTLSamplerState]
}

struct MaterialParams
{
    var tint:               Vector3
    var roughness:          Float
    var metallic:           Float

    private let padding:    Vector3
}
