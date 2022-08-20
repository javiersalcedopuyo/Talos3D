//
//  Renderable.swift
//  Talos3D
//
//  Created by Javier Salcedo on 16/7/22.
//

import Metal
import MetalKit
import SLA

protocol Renderable : Positionable
{
    func getModelMatrix() -> Matrix4x4
    func getNormalMatrix() -> Matrix4x4
    func getWinding() -> MTLWinding
    func getMesh() -> MTKMesh
    func getVertexBuffer() -> MTLBuffer
    func getVertexDescriptor() -> MTLVertexDescriptor // TODO: Is this really necessary?

    func flipHandedness()
}
