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
    func getResource() -> MTLResource
    func getIndexAtStage(_ stage: Stage) -> Int?
    func getLabel() -> String?

    mutating func setIndex(_ idx: Int, stage: Stage)
    mutating func setLabel(_ label: String)
}
