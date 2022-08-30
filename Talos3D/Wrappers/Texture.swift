//
//  Texture.swift
//  Talos3D
//
//  Created by Javier Salcedo on 20/8/22.
//

import Metal

public struct Texture : ShaderResource
{
    init(mtlTexture: MTLTexture, label: String? = nil)
    {
        self.resource = mtlTexture
        self.indexPerStage = [:]

        if let l = label { self.setLabel(l) }
    }

    func getResource()                      -> MTLResource  { self.resource }
    func getIndexAtStage(_ stage: Stage)    -> Int?         { self.indexPerStage[stage] }
    func getLabel()                         -> String?      { self.resource.label }

    mutating func setIndex(_ idx: Int, stage: Stage)    { self.indexPerStage[stage] = idx }
    mutating func setLabel(_ label: String)             { self.resource.label = label }

    private let resource:       MTLTexture
    private var indexPerStage:  [Stage: Int]
}
