//
//  Buffer.swift
//  Talos3D
//
//  Created by Javier Salcedo on 20/8/22.
//

import Metal

public struct Buffer : ShaderResource
{
    init(mtlBuffer: MTLBuffer, shaderStage: Stage, index idx: Int)
    {
        self.resource   = mtlBuffer
        self.stage      = shaderStage
        self.index      = idx
    }

    func GetResource()  -> MTLResource  { resource }
    func GetStage()     -> Stage        { stage }
    func GetIndex()     -> Int          { index }

    private let resource:   MTLBuffer
    private let stage:      Stage
    private let index:      Int
}
