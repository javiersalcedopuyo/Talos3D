//
//  Model.swift
//  Talos3D
//
//  Created by Javier Salcedo on 30/12/21.
//

import MetalKit
import SimpleLogs
import SLA

let POSITION = VertexAttributeIndices.POSITION.rawValue
let COLOR    = VertexAttributeIndices.COLOR.rawValue
let NORMAL   = VertexAttributeIndices.NORMAL.rawValue
let TEXCOORD = VertexAttributeIndices.TEXCOORD.rawValue

// TODO: Agregation of Renderables?
public class Model : Renderable
{
    // MARK: - Public Methods
    init(device: MTLDevice, url: URL, material mat: Material)
    {
        self.material = mat

        let vertexDesc = self.material.pipeline.descriptor.vertexDescriptor
        if vertexDesc == nil
        {
            SimpleLogs.WARNING("Material with no vertex descriptor, model's default will be used instead.")
        }

        mMeshes = Self.loadMeshes(device: device,
                                  url: url,
                                  vertexDescriptor: vertexDesc ?? Self.getNewVertexDescriptor())
        mWinding   = .clockwise
        mTransform = Transform()

        self.getVertexBuffer().label = "Vertex Buffer"
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

    public func getNormalMatrix() -> Matrix4x4
    {
        let model = self.getModelMatrix()
                        .get3x3()

        let normal = model.inverse()?.transposed() ?? model

        return Matrix4x4(from3x3: normal)
    }

    static func getNewVertexDescriptor() -> MTLVertexDescriptor
    {
        let desc = MTLVertexDescriptor()
        // Position
        desc.attributes[POSITION].format      = .float3
        desc.attributes[POSITION].bufferIndex = VERTEX_BUFFER_INDEX
        desc.attributes[POSITION].offset      = 0
        // Color
        desc.attributes[COLOR].format         = .float3
        desc.attributes[COLOR].bufferIndex    = VERTEX_BUFFER_INDEX
        desc.attributes[COLOR].offset         = MemoryLayout<SIMD3<Float>>.stride
        // Normals
        desc.attributes[NORMAL].format        = .float3
        desc.attributes[NORMAL].bufferIndex   = VERTEX_BUFFER_INDEX
        desc.attributes[NORMAL].offset        = MemoryLayout<SIMD3<Float>>.stride
        // UVs
        desc.attributes[TEXCOORD].format      = .float2
        desc.attributes[TEXCOORD].bufferIndex = VERTEX_BUFFER_INDEX
        desc.attributes[TEXCOORD].offset      = MemoryLayout<SIMD3<Float>>.stride * 3

        desc.layouts[0].stride         = MemoryLayout<SIMD3<Float>>.stride * 3 +
                                         MemoryLayout<SIMD2<Float>>.stride

        return desc
    }

    public func move(to position: Vector3)      { mTransform.move(to: position) }

    public func rotate(localEulerAngles : Vector3)
    {
        mTransform.rotate(localEulerAngles: localEulerAngles)
    }

    public func rotateAround(localAxis: Axis, radians: Float)
    {
        mTransform.rotateAround(localAxis: localAxis, radians: radians)
    }

    public func rotateAround(worldAxis: Axis, radians: Float)
    {
        mTransform.rotateAround(worldAxis: worldAxis, radians: radians)
    }

    public func lookAt(_ target: Vector3)       { mTransform.lookAt(target) }
    public func getPosition() -> Vector3        { mTransform.position }
    public func getRotation() -> Vector3        { mTransform.getEulerAngles() }

    public func scale(by factor: Float)         { mTransform.scale(by: factor) }
    public func setScale(_ newScale: Vector3)   { mTransform.setScale(newScale) }
    public func getScale() -> Vector3           { mTransform.scale }

    public func getMaterial() -> Material       { self.material }
    public func setMaterial(_ m: Material)    { self.material = m }

    // MARK: - Private Functions

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
        let attributePosition = desc.attributes[POSITION] as! MDLVertexAttribute
        attributePosition.name = MDLVertexAttributePosition
        desc.attributes[POSITION] = attributePosition

        let attributeColor = desc.attributes[COLOR] as! MDLVertexAttribute
        attributeColor.name = MDLVertexAttributeColor
        desc.attributes[COLOR] = attributeColor

        let attributeNormal = desc.attributes[NORMAL] as! MDLVertexAttribute
        attributeNormal.name = MDLVertexAttributeNormal
        desc.attributes[NORMAL] = attributeNormal

        let attributeUVs = desc.attributes[TEXCOORD] as! MDLVertexAttribute
        attributeUVs.name = MDLVertexAttributeTextureCoordinate
        desc.attributes[TEXCOORD] = attributeUVs
    }

    // MARK: - Private Members
    private var mTransform:         Transform
    private let mMeshes:            [MTKMesh]
    private var mWinding:           MTLWinding
    private var material:           Material
}
