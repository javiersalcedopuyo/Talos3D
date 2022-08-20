//
//  Texture.swift
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

struct Texture
{
    let resource:   MTLTexture
    var stage:      Stage
    var index:      Int
}
