//
//  Model.swift
//  Talos3D
//
//  Created by Javier Salcedo on 30/12/21.
//

import MetalKit
import SimpleLogs
import SLA

// TODO: Agregation of Renderables?
public class Model : Renderable
{
    // MARK: - Public Methods
    init(device: MTLDevice, url: URL)
    {
        mVertexDescriptor = Self.getNewVertexDescriptor()
        mMeshes = Self.loadMeshes(device: device,
                                  url: url,
                                  vertexDescriptor: mVertexDescriptor)
        mWinding   = .clockwise
        mTransform = Transform()
    }

    public func flipHandedness()
    {
        switch mWinding
        {
            case .clockwise:
                mWinding = .counterClockwise
            case .counterClockwise:
                mWinding = .clockwise
            default:
                SimpleLogs.ERROR("This shouldn't be possible")
                break
        }
    }

    public func getWinding()            -> MTLWinding           { mWinding }
    public func getMesh()               -> MTKMesh              { mMeshes[0] }
    public func getVertexDescriptor()   -> MTLVertexDescriptor  { mVertexDescriptor }
    public func getVertexBuffer()       -> MTLBuffer            { self.getMesh()
                                                                      .vertexBuffers[0]
                                                                      .buffer }
    public func getModelMatrix() -> Matrix4x4
    {
        var modelMat = mTransform.getLocalToWorldMatrix()
        if mWinding == .counterClockwise
        {
            var mirror = Matrix4x4.identity()
            mirror.set(col: 2, row: 2, val: -1)

            modelMat = modelMat * mirror
        }
        return modelMat
    }

    public func move(to position: Vector3)      { mTransform.move(to: position) }
    public func rotate(eulerAngles: Vector3)    { mTransform.rotate(eulerAngles: eulerAngles) }
    public func lookAt(_ target: Vector3)       { mTransform.lookAt(target) }
    public func getPosition() -> Vector3        { mTransform.position }
    public func getRotation() -> Vector3        { mTransform.getEulerAngles() }

    // MARK: - Private Functions
    static private func getNewVertexDescriptor() -> MTLVertexDescriptor
    {
        let desc = MTLVertexDescriptor()
        // Position
        desc.attributes[0].format      = .float3
        desc.attributes[0].bufferIndex = VERTEX_BUFFER_INDEX
        desc.attributes[0].offset      = 0
        // Color
        desc.attributes[1].format      = .float3
        desc.attributes[1].bufferIndex = VERTEX_BUFFER_INDEX
        desc.attributes[1].offset      = MemoryLayout<SIMD3<Float>>.stride
        // Normals
        desc.attributes[2].format      = .float3
        desc.attributes[2].bufferIndex = VERTEX_BUFFER_INDEX
        desc.attributes[2].offset      = MemoryLayout<SIMD3<Float>>.stride
        // UVs
        desc.attributes[3].format      = .float2
        desc.attributes[3].bufferIndex = VERTEX_BUFFER_INDEX
        desc.attributes[3].offset      = MemoryLayout<SIMD3<Float>>.stride * 3

        desc.layouts[0].stride         = MemoryLayout<SIMD3<Float>>.stride * 3 +
                                         MemoryLayout<SIMD2<Float>>.stride

        return desc
    }

    static private func loadMeshes(device: MTLDevice,
                                   url: URL,
                                   vertexDescriptor metalVertexDescriptor: MTLVertexDescriptor)
    -> [MTKMesh]
    {
        let asset = loadAsset(device: device,
                              url: url,
                              vertexDescriptor: metalVertexDescriptor)
        do
        {
            let (_, meshes) = try MTKMesh.newMeshes(asset: asset, device: device)
            return meshes
        }
        catch
        {
            SimpleLogs.ERROR("Couldn't load meshes from model " + url.path)
            return []
        }
    }

    static private func loadAsset(device: MTLDevice,
                                  url: URL,
                                  vertexDescriptor metalVertexDescriptor: MTLVertexDescriptor)
    -> MDLAsset
    {
        var modelVertexDescriptor = MTKModelIOVertexDescriptorFromMetal(metalVertexDescriptor)
        Self.nameDescriptorAttributes(&modelVertexDescriptor)

        let bufferAllocator = MTKMeshBufferAllocator(device: device)

        return MDLAsset(url: url,
                        vertexDescriptor: modelVertexDescriptor,
                        bufferAllocator: bufferAllocator)
    }

    static private func nameDescriptorAttributes(_ desc: inout MDLVertexDescriptor)
    {
        let attributePosition = desc.attributes[0] as! MDLVertexAttribute
        attributePosition.name = MDLVertexAttributePosition
        desc.attributes[0] = attributePosition

        let attributeColor = desc.attributes[1] as! MDLVertexAttribute
        attributeColor.name = MDLVertexAttributeColor
        desc.attributes[1] = attributeColor

        let attributeNormal = desc.attributes[2] as! MDLVertexAttribute
        attributeNormal.name = MDLVertexAttributeNormal
        desc.attributes[2] = attributeNormal

        let attributeUVs = desc.attributes[3] as! MDLVertexAttribute
        attributeUVs.name = MDLVertexAttributeTextureCoordinate
        desc.attributes[3] = attributeUVs
    }

    // MARK: - Private Members
    private var mTransform:         Transform
    private let mVertexDescriptor:  MTLVertexDescriptor
    private let mMeshes:            [MTKMesh]
    private var mWinding:           MTLWinding
}
