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

    public func getForward() -> Vector3 { applyAccumulatedRotation(); return self.forward }
    public func getUp()      -> Vector3 { applyAccumulatedRotation(); return self.up }
    public func getRight()   -> Vector3 { applyAccumulatedRotation(); return self.right }

    public func getLocalToWorldMatrix() -> Matrix4x4
    {
        applyAccumulatedRotation()

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
        let worldUp = Vector3(x:0, y:1, z:0)

        // Tilt / Pitch
        let rotX = Quaternion.makeRotation(radians: SLA.deg2rad(eulerAngles.x),
                                           axis:    self.right)
        // Pan / Yaw
        // Use the world's UP to avoid unwanted rolling
        let rotY = Quaternion.makeRotation(radians: SLA.deg2rad(eulerAngles.y),
                                           axis:    worldUp)
        // Roll
        let rotZ = Quaternion.makeRotation(radians: SLA.deg2rad(eulerAngles.z),
                                           axis:    self.forward)
        // X -> Z -> Y
        let R = rotY * rotZ * rotX

        self.accumulatedRotation = R * self.accumulatedRotation
    }

    public func lookAt(_ target: Vector3)
    {
        if self.position == target
        {
            SimpleLogs.WARNING("Trying to look at our own position. Nothing will happen.")
            return
        }

        let viewVector = (target - self.position).normalized()

        let angle = acos(self.forward.dot(viewVector))
        let rotationAxis = areParallel(viewVector, self.forward)
                            ? self.up
                            : self.forward.cross(viewVector).normalized()

        let q = Quaternion.makeRotation(radians: angle, axis: rotationAxis)

        self.accumulatedRotation = q * self.accumulatedRotation
    }

    // MARK: - Private
    private func applyAccumulatedRotation()
    {
        if self.accumulatedRotation == Quaternion.identity() { return }

        let rotation = self.accumulatedRotation
        self.accumulatedRotation = Quaternion.identity()

        do
        {
            self.right      = try SLA.rotate(vector: self.right,    quaternion: rotation)
            self.up         = try SLA.rotate(vector: self.up,       quaternion: rotation)
            self.forward    = try SLA.rotate(vector: self.forward,  quaternion: rotation)
        }
        catch
        {
            SimpleLogs.WARNING("Failed to apply rotation. Reason: \(error)")
        }
    }

    private var forward:  Vector3
    private var up:       Vector3
    private var right:    Vector3

    private var eulerAngles: Vector3
    private var accumulatedRotation = Quaternion.identity()
    // TODO: private var rotQuaternion: Quaternion
}
