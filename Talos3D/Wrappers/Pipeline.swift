//
//  PSO.swift
//  Talos3D
//
//  Created by Javier Salcedo on 18/8/22.
//

import Metal

class Pipeline
{
    init?(desc:     MTLRenderPipelineDescriptor,
          device:   MTLDevice,
          type t:   PassType)
    {
        do
        {
            descriptor = desc
            state = try device.makeRenderPipelineState(descriptor: desc)
            type = t
        }
        catch
        {
            print(error)
            return nil
        }
    }

    let state:      MTLRenderPipelineState
    let descriptor: MTLRenderPipelineDescriptor
    let type:       PassType
}

enum PassType
{
    case Shadows
    case GBuffer
    case ForwardLighting
    case DeferredComposite
    case ScreenSpace
}
