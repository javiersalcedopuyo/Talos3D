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
    var moveSpeed:   Float {get set}
    var rotateSpeed: Float {get set}

    mutating func move(localDirection: Vector3)
}
