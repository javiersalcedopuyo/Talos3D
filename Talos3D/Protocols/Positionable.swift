//
//  Positionable.swift
//  Talos3D
//
//  Created by Javier Salcedo on 1/1/22.
//

import SLA

// Objects that can be placed in the 3D world
protocol Positionable
{
    func move(to: Vector3)
    func rotate(localEulerAngles: Vector3)
    func lookAt(_ target: Vector3)

    func getPosition() -> Vector3
    func getRotation() -> Vector3
}
