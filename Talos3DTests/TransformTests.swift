//
//  TransformTests.swift
//  Talos3DTests
//
//  Created by Javier Salcedo on 5/9/22.
//

import XCTest
import SLA
@testable import Talos3D

class TransformTests: XCTestCase
{
    func testRotateAlongXAxis()
    {
        let t1 = Transform()
        let t2 = Transform()
        let rotation = Vector3(x: 90, y: 0, z: 0)
        t1.rotate(eulerAngles: rotation)

        XCTAssertEqual(t1.getRight(), t2.getRight())
        XCTAssertEqual(t1.getUp().dot(t2.getUp()), 0, accuracy: 0.0002)
        XCTAssertEqual(t1.getForward().dot(t2.getForward()), 0, accuracy: 0.0002)
    }

    func testRotateAlongYAxis()
    {
        let t1 = Transform()
        let t2 = Transform()
        let rotation = Vector3(x: 0, y: 90, z: 0)
        t1.rotate(eulerAngles: rotation)

        XCTAssertEqual(t1.getUp(), t2.getUp())
        XCTAssertEqual(t1.getForward().dot(t2.getForward()), 0, accuracy: 0.0002)
        XCTAssertEqual(t1.getRight().dot(t2.getRight()), 0, accuracy: 0.0002)
    }

    func testRotateAlongZAxis()
    {
        let t1 = Transform()
        let t2 = Transform()
        let rotation = Vector3(x: 0, y: 0, z: 90)
        t1.rotate(eulerAngles: rotation)

        XCTAssertEqual(t1.getForward(), t2.getForward())
        XCTAssertEqual(t1.getUp().dot(t2.getUp()), 0, accuracy: 0.0002)
        XCTAssertEqual(t1.getRight().dot(t2.getRight()), 0, accuracy: 0.0002)
    }

    func testRotateAlongXAxisRepeatedly()
    {
        let t1 = Transform()
        let t2 = Transform()
        let rotation = Vector3(x: 45, y: 0, z: 0)
        t1.rotate(eulerAngles: rotation)
        t1.rotate(eulerAngles: rotation)

        XCTAssertEqual(t1.getRight(), t2.getRight())
        XCTAssertEqual(t1.getUp().dot(t2.getUp()), 0, accuracy: 0.0002)
        XCTAssertEqual(t1.getForward().dot(t2.getForward()), 0, accuracy: 0.0002)
    }

    func testRotateAlongYAxisRepeatedly()
    {
        let t1 = Transform()
        let t2 = Transform()
        let rotation = Vector3(x: 0, y: 45, z: 0)
        t1.rotate(eulerAngles: rotation)
        t1.rotate(eulerAngles: rotation)

        XCTAssertEqual(t1.getUp(), t2.getUp())
        XCTAssertEqual(t1.getForward().dot(t2.getForward()), 0, accuracy: 0.0002)
        XCTAssertEqual(t1.getRight().dot(t2.getRight()), 0, accuracy: 0.0002)
    }

    func testRotateAlongZAxisRepeatedly()
    {
        let t1 = Transform()
        let t2 = Transform()
        let rotation = Vector3(x: 0, y: 0, z: 45)
        t1.rotate(eulerAngles: rotation)
        t1.rotate(eulerAngles: rotation)

        XCTAssertEqual(t1.getForward(), t2.getForward())
        XCTAssertEqual(t1.getUp().dot(t2.getUp()), 0, accuracy: 0.0002)
        XCTAssertEqual(t1.getRight().dot(t2.getRight()), 0, accuracy: 0.0002)
    }

    func testRotateAlongXThenY()
    {

    }
}
