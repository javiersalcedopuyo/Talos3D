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

    init(mtlBuffer: MTLBuffer, label: String? = nil)
    {
        self.resource   = mtlBuffer
        self.indexPerStage = [:]

        if let l = label { self.setLabel(l) }
    }

    func getResource()                      -> MTLResource  { self.resource }
    func getIndexAtStage(_ stage: Stage)    -> Int?         { self.indexPerStage[stage] }
    func getLabel()                         -> String?      { self.resource.label }

    mutating func setIndex(_ idx: Int, stage: Stage)    { self.indexPerStage[stage] = idx }
    mutating func setLabel(_ label: String)             { self.resource.label = label }

    private let resource:       MTLBuffer
    private var indexPerStage:  [Stage: Int]
}
