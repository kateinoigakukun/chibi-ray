public struct Point {
    var x, y, z: Double
    public init(x: Double, y: Double, z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }
}

extension Point {
    static var zero: Point {
        Point(x: 0, y: 0, z: 0)
    }

    static func - (lhs: Point, rhs: Point) -> Vector3 {
        Vector3(x: lhs.x - rhs.x, y: lhs.y - rhs.y, z: lhs.z - rhs.z)
    }

    static func + (lhs: Point, rhs: Vector3) -> Point {
        Point(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z)
    }
}
