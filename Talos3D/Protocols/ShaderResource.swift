//
//  ShaderResource.swift
//  Talos3D
//
//  Created by Javier Salcedo on 20/8/22.
//

import Metal

enum Stage
{
    case Vertex
    case Fragment
    case Compute
}

protocol ShaderResource
{
    func GetResource() -> MTLResource
    func GetIndexAtStage(_ stage: Stage) -> Int?
    mutating func SetIndex(_ idx: Int, stage: Stage)
}
