//
//  Light.swift
//  Talos3D
//
//  Created by Javier Salcedo on 20/2/22.
//

import SLA

protocol LightSource : Positionable
{
    var transform:  Transform   {get}
    var color:      Vector4     {get set} // TODO: use uint8s? Vector3? Pack the intensity in the alpha?
    var intensity:  Float       {get set}

    func getBufferData() -> [Float]
    func getBufferSize() -> Int
}

class DirectionalLight : LightSource
{
    var transform: Transform
    var color: Vector4
    var intensity: Float

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
    public func move(to: Vector3)            { self.transform.move(to: to) }
    public func rotate(eulerAngles: Vector3) { self.transform.rotate(eulerAngles: eulerAngles) }
    public func lookAt(_ target: Vector3)    { self.transform.lookAt(target) }
}

// TODO: class PointLight
// TODO: class SpotLight
// TODO: class AreaLight
