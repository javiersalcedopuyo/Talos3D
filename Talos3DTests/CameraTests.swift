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

    func testLookAt()
    {
        let pos = Vector3(x: 0, y: 1, z: 2)
        self.cam.lookAt(pos)

        let forward = self.cam.transform.getForward()
        XCTAssertEqual(forward.dot(pos.normalized()), 1, accuracy: SLA.FLOAT_EPSILON)
    }

    func testLookAtForward()
    {
        let pos = Vector3(x: 0, y: 1, z: 2)
        self.cam.move(to: pos)
        self.cam.lookAt(Vector3.zero())

        let forward = self.cam.transform.getForward()
        XCTAssertEqual(forward.dot(pos.normalized()), -1, accuracy: SLA.FLOAT_EPSILON)
    }

    func testLookUp()
    {
        let pos = Vector3(x: 0, y: 1, z: 0)
        self.cam.lookAt(pos)

        let forward = self.cam.transform.getForward()
        XCTAssertEqual(forward.dot(pos), 1, accuracy: SLA.FLOAT_EPSILON)
    }

    func testLocalToWorldMatrix()
    {
        self.cam.move(to: Vector3(x: 0, y: 1, z: 2))
        self.cam.lookAt(Vector3.zero())

        let localForward = Vector4(x: 0, y: 0, z: 1, w: 0)
        let worldForward = (self.cam.transform.getLocalToWorldMatrix() * localForward)
                            .xyz()
                            .normalized()

        let forward = self.cam.transform.getForward()
        XCTAssertEqual(worldForward.dot(forward), 1, accuracy: SLA.FLOAT_EPSILON)
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
