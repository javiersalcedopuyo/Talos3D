//
//  Buffer.swift
//  Talos3D
//
//  Created by Javier Salcedo on 20/8/22.
//

import Metal

public struct Buffer : ShaderResource
{
    // TODO: init(device: MTLDevice, bytes: [Int], size: Int, options: MTLResourceOptions)

    init(mtlBuffer: MTLBuffer)
    {
        self.resource   = mtlBuffer
        self.indexPerStage = [:]
    }

    func GetResource()  -> MTLResource  { self.resource }
    func GetIndexAtStage(_ stage: Stage) -> Int? { self.indexPerStage[stage] }

    mutating func SetIndex(_ idx: Int, stage: Stage) { self.indexPerStage[stage] = idx }

    private let resource:       MTLBuffer
    private var indexPerStage:  [Stage: Int]
}
