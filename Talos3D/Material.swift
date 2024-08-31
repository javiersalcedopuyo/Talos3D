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
    init(pipeline pso: PipelineID, label name: String = "")
    {
        self.label      = name
        self.pipelineID = pso
        self.params     = MaterialParams()
        self.textures   = []
        self.samplers   = []
    }

    public func copy(with zone: NSZone? = nil) -> Any
    {
        let newMaterial = Material(pipeline: self.pipelineID)
        newMaterial.textures = self.textures
        newMaterial.samplers = self.samplers
        newMaterial.params   = self.params
        return newMaterial
    }

    // TODO: Rethink this
    func swapTexture(idx: Int, newTexture: TextureHandle)
    {
        if idx >= self.textures.count
        {
            SimpleLogs.ERROR("Index is out of bounds.")
            return
        }

        self.textures[idx] = newTexture
    }

    let pipelineID: PipelineID
    var params:   MaterialParams
    var textures: [TextureHandle]
    var samplers: [MTLSamplerState]
    var label:     String
}

struct MaterialParams
{
    static public   var packedSize: Int     { return 8 * MemoryLayout<Float>.size }

    private(set)    var tint                = Vector3.one

    private(set)    var roughness:  Float   = 1.0
    private(set)    var metallic:   Float   = 0.0

    private         let padding             = Vector3.zero

    /// Sets a new tint
    /// - Parameters:
    ///     - t: New tint. All channels must be in the [0,1] range
    mutating public func setTint(_ t: Vector3)
    {
        assert(t.r() >= 0.0 && t.r() <= 1.0)
        assert(t.g() >= 0.0 && t.g() <= 1.0)
        assert(t.b() >= 0.0 && t.b() <= 1.0)
        self.tint = t
    }

    /// Sets a new roughness
    /// - Parameters:
    ///     - r: New roughness. Must be in the (0,1] range
    mutating public func setRoughness(_ r: Float)
    {
        assert(r > 0.0 && r <= 1.0)
        self.roughness = r
    }

    /// Sets a new metallic coefficient
    /// - Parameters:
    ///     - m: New metallic coefficient. Must be in the (0,1] range
    mutating public func setMetallic(_ m: Float)
    {
        assert(m > 0.0 && m <= 1.0)
        self.metallic = m
    }

    /// Gets the parameters as a packed array of Floats
    /// - Returns:
    ///     - data: An array containing the parameters' data, without the SIMD padding
    public func getPackedData() -> [Float]
    {
        var data = [Float](repeating: 0.0, count: Self.packedSize / MemoryLayout<Float>.size)
        data[0] = self.tint.x
        data[1] = self.tint.y
        data[2] = self.tint.z

        data[3] = self.roughness

        data[4] = self.metallic

        return data
    }
}
