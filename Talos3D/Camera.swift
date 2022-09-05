//
//  Camera.swift
//  Talos3D
//
//  Created by Javier Salcedo on 3/1/22.
//
import SLA
import SimpleLogs

class Camera: Mobile
{
    // MARK: - public
    public var moveSpeed:   Float
    public var rotateSpeed: Float

    public init()
    {
        moveSpeed   = 0.01
        rotateSpeed = 0.1

        fovy        = SLA.deg2rad(45.0)
        aspectRatio = 1.0
        near        = 0.1
        far         = 1000.0

        transform = Transform()

        view       = Matrix4x4.identity()
        projection = Matrix4x4.identity()

        self.updateView()
        self.updateProjection()
    }

    public func getView()       -> Matrix4x4    { self.view }
    public func getProjection() -> Matrix4x4    { self.projection }
    public func getPosition()   -> Vector3      { self.transform.position }
    public func getRotation()   -> Vector3      { self.transform.getEulerAngles() }

    public func move(localDirection: Vector3)
    {
        let worldDirection = self.transform.getLocalToWorldMatrix() * Vector4(localDirection, 0)
        self.transform.position += worldDirection.xyz() * self.moveSpeed
        self.updateView()
    }

    public func move(to newPos: Vector3) { self.transform.move(to: newPos); self.updateView() }

    public func lookAt(_ target: Vector3)
    {
        self.transform.lookAt(target)
        self.updateView()
    }

    public func rotate(eulerAngles: Vector3)
    {
        self.transform.rotate(eulerAngles: eulerAngles)
        self.updateView()
    }

    public func updateAspectRatio(_ a: Float)   { self.aspectRatio = a; self.updateProjection() }
    public func updateFOVY(_ f: Float)          { self.fovy = f;        self.updateProjection() }
    public func updateNear(_ n: Float)          { self.near = n;        self.updateProjection() }
    public func updateFar(_ f: Float)           { self.far = f;         self.updateProjection() }

    // MARK: - private
    internal var transform:  Transform

    private var fovy:        Float
    private var aspectRatio: Float
    private var near:        Float
    private var far:         Float

    private var view:       Matrix4x4
    private var projection: Matrix4x4

    private func updateView()
    {
        let t = self.transform
        self.view = Matrix4x4.lookAtLH(eye:    t.position,
                                       target: t.position + t.getForward(),
                                       upAxis: t.getUp())
    }

    private func updateProjection()
    {
        self.projection = Matrix4x4.perspectiveLH(fovy: self.fovy,
                                                  aspectRatio: self.aspectRatio,
                                                  near: self.near,
                                                  far: self.far)
    }
}
