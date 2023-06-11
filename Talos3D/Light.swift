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
    var projection:     Matrix4x4?  {get set}

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
    var projection: Matrix4x4?  = nil

    public init(direction: Vector3,
                color: Vector4,
                intensity: Float,
                castsShadows: Bool)
    {
        self.color = color
        self.intensity = intensity

        if castsShadows
        {
            // TODO: Make this configurable
            self.projection = Matrix4x4.orthographicLH(width: 2,
                                                       height: 2,
                                                       near: 0.1,
                                                       far: 100) // TODO: Use the range instead
        }

        self.lookAt(direction)
    }

    public func getBufferData() -> [Float]
    {
        var data = [Float](repeating: 0.0, count: 8)
        data[0] = self.getDirection().x
        data[1] = self.getDirection().y
        data[2] = self.getDirection().z
        data[3] = 0 // Padding

        // Pre-multiply the intensity with the color to save bandwidth
        let preMultipliedColor = self.color * self.intensity
        data[4] = preMultipliedColor.r()
        data[5] = preMultipliedColor.g()
        data[6] = preMultipliedColor.b()
        data[7] = preMultipliedColor.a()

        return data
    }

    public func getBufferSize() -> Int
    {
        return MemoryLayout<Vector4>.size * 2
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

    public func getPosition()  -> Vector3 { self.transform.position }
    public func getRotation()  -> Vector3 { self.transform.getEulerAngles() }
    public func getDirection() -> Vector3 { self.transform.getForward() }

    public func getView() -> Matrix4x4
    {
        if self.isViewDirty { self.updateView() }
        return self.view
    }

    // MARK: - Private
    private func updateView()
    {
        let t = self.transform
        t.move(to: -t.getForward()) // TODO: Scale this with the range
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
