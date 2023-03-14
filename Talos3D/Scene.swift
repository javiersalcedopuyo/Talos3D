//
//  Scene.swift
//  Talos3D
//
//  Created by Javier Salcedo on 29/8/22.
//

import Metal

class Scene
{
    // MARK: - Public
    // TODO: init?(fromFile: String)
    @discardableResult
    func add(camera: Camera) -> Self
    {
        self.cameras.append(camera)
        return self
    }

    @discardableResult
    func add(light: LightSource) -> Self
    {
        self.lights.append(light)
        return self
    }

    @discardableResult
    func add(object: Renderable) -> Self
    {
        self.objects.append(object)
        return self
    }

    @discardableResult
    func set(skybox quad: Renderable) -> Self
    {
        self.skybox = quad
        return self
    }

    var mainCamera: Camera { self.cameras[0] }

    // MARK: - Private
    private(set) var cameras: [Camera]      = []
    private(set) var lights:  [LightSource] = []
    private(set) var objects: [Renderable]  = []
    private(set) var skybox:  Renderable?   = nil
    // TODO: private func makeBuffers(device: MTLDevice)
    // TODO: private var buffers: [String: MTLBuffer]
}
