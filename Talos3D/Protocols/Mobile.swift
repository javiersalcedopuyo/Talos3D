//
//  Mobile.swift
//  Talos3D
//
//  Created by Javier Salcedo on 3/1/22.
//

import SLA

// Objects that can move around the 3D world
protocol Mobile: Positionable
{
    var moveSpeed:   Vector3 {get set}
    var rotateSpeed: Float {get set}

    mutating func move(direction: Vector3)
    mutating func rotate(eulerAngles: Vector3)
    // TODO: mutating func rotate(quaternion: Quaternion)
}
