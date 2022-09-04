//
//  Transform.swift
//  Talos3D
//
//  Created by Javier Salcedo on 3/1/22.
//
import SLA
import SimpleLogs

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
        position    = Vector3.zero()
        scale       = Vector3.identity()
        eulerAngles = Vector3.zero()

        right    = Vector3(x:1, y:0, z:0)
        up       = Vector3(x:0, y:1, z:0)
        forward  = Vector3(x:0, y:0, z:1)
    }

    public func getForward() -> Vector3 { return self.forward }
    public func getUp()      -> Vector3 { return self.up }
    public func getRight()   -> Vector3 { return self.right }

    public func getLocalToWorldMatrix() -> Matrix4x4
    {
        let X = Vector4(self.right      * self.scale.x, 0)
        let Y = Vector4(self.up         * self.scale.y, 0)
        let Z = Vector4(self.forward    * self.scale.z, 0)
        let T = Vector4(self.position,                  1)

        return Matrix4x4(a: X, b: Y, c: Z, d: T)
    }

    // TODO: public func getWorldToLocaldMatrix() -> Matrix4x4

    public func getEulerAngles() -> Vector3 { return self.eulerAngles }
    // TODO: public func getRotationQuaternion() -> Quaternion { return self.rotQuaternion }

    public func move(to: Vector3) { self.position = to }

    public func setScale(_ newScale: Vector3)   { self.scale = newScale }
    public func scale(by factor: Float)         { self.scale *= factor }

    public func rotate(eulerAngles: Vector3)
    {
        // Tilt
        let rotX = Matrix3x3.makeRotation(radians: SLA.deg2rad(eulerAngles.x),
                                          axis:    self.right)
        // Pan
        let rotY = Matrix3x3.makeRotation(radians: SLA.deg2rad(eulerAngles.y),
                                          axis:    self.up)
        // Roll
        let rotZ = Matrix3x3.makeRotation(radians: SLA.deg2rad(eulerAngles.z),
                                          axis:    self.forward)

        // I'm using Z -> Y -> X to avoid gimball lock, since we are probably not rolling often
        let R = rotX * rotY * rotZ

        let worldUp = Vector3(x:0, y:1, z:0)

        self.forward = (R * self.forward).normalized() // Is it really necessary to normalize?
        self.right   = worldUp.cross(self.forward).normalized()
        self.up      = self.forward.cross( self.right )
    }
    // TODO: public func rotate(q: Quaterion)

    public func lookAt(_ target: Vector3)
    {
        if self.position == target
        {
            SimpleLogs.ERROR("Trying to look at our own position.")
            return
        }

        let viewVector = target - self.position

        if areParallel(viewVector, self.up)
        {
            SimpleLogs.ERROR("View direction can't be aligned to the UP vector.")
            return
        }

        self.forward = viewVector.normalized()
        self.right   = self.up.cross(self.forward).normalized()
        self.up      = self.forward.cross(self.right)
    }

    // MARK: - Private
    private var forward:  Vector3
    private var up:       Vector3
    private var right:    Vector3

    private var eulerAngles: Vector3
    // TODO: private var rotQuaternion: Quaternion
}
