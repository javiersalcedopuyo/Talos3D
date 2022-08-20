//
//  Texture.swift
//  Talos3D
//
//  Created by Javier Salcedo on 20/8/22.
//

import Metal

public struct Texture : ShaderResource
{
    init(mtlTexture: MTLTexture, shaderStage: Stage, index idx: Int)
    {
        self.resource   = mtlTexture
        self.stage      = shaderStage
        self.index      = idx
    }

    func GetResource()  -> MTLResource  { resource }
    func GetStage()     -> Stage        { stage }
    func GetIndex()     -> Int          { index }

    private let resource:   MTLTexture
    private let stage:      Stage
    private let index:      Int
}
