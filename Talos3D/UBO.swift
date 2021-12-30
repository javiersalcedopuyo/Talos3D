//
//  UBO.swift
//  Talos3D
//
//  Created by Javier Salcedo on 30/12/21.
//

import SLA

struct UniformBufferObject
{
    public var model = Matrix4x4.identity()
    public var view  = Matrix4x4.identity()
    public var proj  = Matrix4x4.identity()

    func asArray() -> [Float]
    {
        return model.asSingleArray() + view.asSingleArray() + proj.asSingleArray()
    }

    func size() -> Int
    {
        return model.size + view.size + proj.size
    }
}
