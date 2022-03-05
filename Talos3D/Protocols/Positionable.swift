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
    var transform: Transform {get}

    func move(to: Vector3)
    func rotate(eulerAngles: Vector3)
    // TODO: func lookAt(target: Vector3)
}
