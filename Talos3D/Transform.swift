//
//  Transform.swift
//  Talos3D
//
//  Created by Javier Salcedo on 3/1/22.
//
import SLA

class Transform
{
    // MARK: - Public
    // TODO: Hierarchies
    // public var parent:   Transform?
    // public var children: [Transform]

    public var position: Vector3
    public var scale:    Vector3

    public init()
    {
        position = Vector3.zero()
        scale    = Vector3.identity()

        forward  = Vector3(x:0, y:0, z:1)
        up       = Vector3(x:0, y:1, z:0)
        right    = Vector3(x:1Talos3D/Mobile.swift, y:0, z:0)
    }

    public func getForward() -> Vector3 { return self.forward }
    public func getUp()      -> Vector3 { return self.up }
    public func getRight()   -> Vector3 { return self.right }

    // TODO: public func getEulerAngles() -> Vector3 { return self.eulerAngles }
    // TODO: public func getRotationQuaternion() -> Quaternion { return self.rotQuaternion }

    public func move(to: Vector3) { self.position = to }

    // TODO: public func rotate(eulerAngles: Vector3)
    // TODO: public func rotate(q: Quaterion)
    // TODO: public func lookAt(target: Vector3)

    // MARK: - Private
    private var forward:  Vector3
    private var up:       Vector3
    private var right:    Vector3

    // TODO: private var eulerAngles: Vector3
    // TODO: private var rotQuaternion: Quaternion
    // TODO: private var localToWorldMatrix: Matrix4x4 // Maybe construct it on demand?
    // TODO: private var worldToLocalMatrix: Matrix4x4
}
