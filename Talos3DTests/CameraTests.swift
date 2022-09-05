//
//  CameraTests.swift
//  Talos3DTests
//
//  Created by Javier Salcedo on 5/9/22.
//

import XCTest
import SLA
@testable import Talos3D

class CameraTests: XCTestCase
{
    var cam: Camera!

    override func setUp()
    {
        self.cam = Camera()
        self.cam.moveSpeed = 1
    }

    func testLookAtForward()
    {
        let pos = Vector3(x: 0, y: 1, z: 2)
        self.cam.move(to: pos)
        self.cam.lookAt(Vector3.zero())
        XCTAssertEqual(self.cam.transform.getForward(), -pos.normalized())
    }

    func testLocalToWorldMatrix()
    {
        self.cam.move(to: Vector3(x: 0, y: 1, z: 2))
        self.cam.lookAt(Vector3.zero())

        let localForward = Vector4(x: 0, y: 0, z: 1, w: 0)
        let worldForward = (self.cam.transform.getLocalToWorldMatrix() * localForward)
                            .xyz()
                            .normalized()
        for i in 0..<3
        {
            XCTAssertEqual(worldForward[i],
                           self.cam.transform.getForward()[i],
                           accuracy: 0.0002)
        }
    }

    func testMoveInLocalDirection()
    {
        let pos = Vector3(x: 0, y: 1, z: 2)
        self.cam.move(to: pos)
        self.cam.lookAt(Vector3.zero())

        let distance = pos.norm()
        let localForward = Vector4(x: 0, y: 0, z: distance, w: 0)
        self.cam.move(localDirection: localForward.xyz())

        let newPos = self.cam.getPosition()
        for i in 0..<3
        {
            XCTAssertEqual(newPos[i], 0, accuracy: 0.0002)
        }
    }
}
