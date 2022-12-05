//
//  Light.swift
//  Talos3D
//
//  Created by Javier Salcedo on 20/2/22.
//

import SLA

protocol LightSource : Positionable
{
    var color:          Vector4     {get set} // TODO: use uint8s? Vector3? Pack the intensity in the alpha?
    var intensity:      Float       {get set}
    var castsShadows:   Bool        {get set}

    func getBufferData() -> [Float]
    func getBufferSize() -> Int
    func getView() -> Matrix4x4
}

class DirectionalLight : LightSource
{
    // MARK: - Public
    var transform: Transform    = Transform.init()
    var color: Vector4          = Vector4.one
    var intensity: Float        = 1.0
    var castsShadows: Bool      = true

    public init()
    {
        self.transform = Transform.init()
        self.color = Vector4.one
        self.intensity = 1.0
    }

    public init(direction: Vector3,
                color: Vector4,
                intensity: Float)
    {
        self.transform = Transform.init()
        self.color = color
        self.intensity = intensity

        self.lookAt(direction)
    }

    public func getBufferData() -> [Float]
    {
        // TODO: Refactor this ugly mess
        var data = [Float](repeating: 0.0, count: 8)
        data[0] = self.transform.getForward().x
        data[1] = self.transform.getForward().y
        data[2] = self.transform.getForward().z

        data[3] = self.intensity

        data[4] = self.color.r()
        data[5] = self.color.g()
        data[6] = self.color.b()
        data[7] = self.color.a()
        return data
    }

    public func getBufferSize() -> Int
    {
        return MemoryLayout<Float>.size * 8
    }

    // MARK: Positionable methods
    public func move(to: Vector3)
    {
        self.isViewDirty = true
        self.transform.move(to: to)
    }

    public func rotate(localEulerAngles: Vector3)
    {
        self.isViewDirty = true
        self.transform.rotate(localEulerAngles: localEulerAngles)
    }

    public func rotateAround(localAxis: Axis, radians: Float)
    {
        self.isViewDirty = true
        self.transform.rotateAround(localAxis: localAxis, radians: radians)
    }

    public func rotateAround(worldAxis: Axis, radians: Float)
    {
        self.isViewDirty = true
        self.transform.rotateAround(worldAxis: worldAxis, radians: radians)
    }

    public func lookAt(_ target: Vector3)
    {
        self.isViewDirty = true
        self.transform.lookAt(target)
    }

    public func getPosition() -> Vector3 { self.transform.position }
    public func getRotation() -> Vector3 { self.transform.getEulerAngles() }

    public func getView() -> Matrix4x4
    {
        if self.isViewDirty { self.updateView() }
        return self.view
    }

    // MARK: - Private
    private func updateView()
    {
        let t = self.transform
        self.view = Matrix4x4.lookAtLH(eye:    t.position,
                                       target: t.position + t.getForward(),
                                       upAxis: Vector3(x: 0, y: 1, z: 0))
        self.isViewDirty = false
    }

    private var isViewDirty         = true
    private var view                = Matrix4x4.identity()
}

// TODO: class PointLight
// TODO: class SpotLight
// TODO: class AreaLight
