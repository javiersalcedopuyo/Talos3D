//
//  PSO.swift
//  Talos3D
//
//  Created by Javier Salcedo on 18/8/22.
//

import Metal

class Pipeline
{
    init?(desc: MTLRenderPipelineDescriptor, device: MTLDevice)
    {
        do
        {
            descriptor = desc
            state = try device.makeRenderPipelineState(descriptor: desc)
        }
        catch
        {
            print(error)
            return nil
        }
    }

    let state:      MTLRenderPipelineState
    let descriptor: MTLRenderPipelineDescriptor
}
