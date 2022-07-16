//
//  Renderable.swift
//  Talos3D
//
//  Created by Javier Salcedo on 16/7/22.
//

import Metal
import MetalKit
import SLA

// TODO: Inherit from Positionable
protocol Renderable
{
    func getModelMatrix() -> Matrix4x4
    func getWinding() -> MTLWinding
    func getMesh() -> MTKMesh
    func getVertexBuffer() -> MTLBuffer
    func getVertexDescriptor() -> MTLVertexDescriptor

    func flipHandedness()
}
