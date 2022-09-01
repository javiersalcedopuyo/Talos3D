//
//  Scene.swift
//  Talos3D
//
//  Created by Javier Salcedo on 29/8/22.
//

import Metal
import SLA
import SimpleLogs

class SceneBuilder
{
    // MARK: - Public
    @discardableResult
    func add(camera: Camera) -> SceneBuilder
    {
        self.cameras.append(camera)
        return self
    }

    @discardableResult
    func add(light: LightSource) -> SceneBuilder
    {
        self.lights.append(light)
        return self
    }

    @discardableResult
    func add(object: Renderable) -> SceneBuilder
    {
        self.objects.append(object)
        return self
    }

    func build(device: MTLDevice) -> Scene
    {
        let result = Scene(cameras: self.cameras,
                           lights:  self.lights,
                           objects: self.objects)
        reset()
        return result
    }

    // MARK: - Private
    private func reset()
    {
        cameras = []
        lights  = []
        objects = []
    }

    private var cameras:    [Camera]        = []
    private var lights:     [LightSource]   = []
    private var objects:    [Renderable]    = []
}

class Scene
{
    // MARK: - Public
    // TODO: init?(fromFile: String)
    var mainCamera: Camera { self.cameras[0] }

    private(set) var cameras: [Camera]
    private(set) var lights:  [LightSource]
    private(set) var objects: [Renderable]

    // MARK: - Private
    fileprivate init(cameras: [Camera],
                     lights: [LightSource],
                     objects: [Renderable])
    {
        self.cameras = cameras
        self.lights  = lights
        self.objects = objects
    }

    // TODO: private func makeBuffers(device: MTLDevice)
    // TODO: private var buffers: [String: MTLBuffer]
}
