//
//  Material.swift
//  Talos3D
//
//  Created by Javier Salcedo on 18/8/22.
//

import MetalKit
import SLA

public class Material
{
    init(pipeline pso: Pipeline)
    {
        pipeline = pso
        params   = nil
        textures = []
        samplers = []
    }

    func getVertexShader()   -> MTLFunction? { pipeline.descriptor.vertexFunction }
    func getFragmentShader() -> MTLFunction? { pipeline.descriptor.fragmentFunction }

    let pipeline: Pipeline
    var params:   MaterialParams?
    var textures: [Texture]
    var samplers: [MTLSamplerState]

}

struct MaterialParams
{
    var tint:       Vector3
    var roughness:  Float
    var metallic:   Float
}
