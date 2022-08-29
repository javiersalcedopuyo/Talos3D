//
//  Texture.swift
//  Talos3D
//
//  Created by Javier Salcedo on 20/8/22.
//

import Metal

public struct Texture : ShaderResource
{
    init(mtlTexture: MTLTexture)
    {
        self.resource = mtlTexture
        self.indexPerStage = [:]
    }

    func GetResource()  -> MTLResource  { self.resource }
    func GetIndexAtStage(_ stage: Stage) -> Int? { self.indexPerStage[stage] }

    mutating func SetIndex(_ idx: Int, stage: Stage) { self.indexPerStage[stage] = idx }

    private let resource:       MTLTexture
    private var indexPerStage:  [Stage: Int]
}
