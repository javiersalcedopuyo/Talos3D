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
    func getScale() -> Vector3
    func setScale(_ newScale: Vector3)
    func scale(by factor: Float)

    func getModelMatrix() -> Matrix4x4
    func getNormalMatrix() -> Matrix4x4
    func getWinding() -> MTLWinding
    func getMesh() -> MTKMesh
    func getVertexBuffer() -> MTLBuffer // TODO: Return a Buffer instead?

    func getMaterial() -> Material
    func setMaterial(_ material: Material)

    func flipHandedness()
}
