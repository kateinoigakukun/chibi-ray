public struct Color: Equatable {
    public var red, green, blue: Float

    public static var black: Color {
        Color(red: 0.0, green: 0.0, blue: 0.0)
    }

    public init(red: Float, green: Float, blue: Float) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    func clamp() -> Color {
        Color(
            red: max(min(red, 1.0), 0.0),
            green: max(min(green, 1.0), 0.0),
            blue: max(min(blue, 1.0), 0.0)
        )
    }

    static func * (lhs: Color, rhs: Float) -> Color {
        Color(red: lhs.red * rhs, green: lhs.green * rhs, blue: lhs.blue * rhs)
    }
    static func * (lhs: Color, rhs: Color) -> Color {
        Color(red: lhs.red * rhs.red, green: lhs.green * rhs.green, blue: lhs.blue * rhs.blue)
    }
    static func + (lhs: Color, rhs: Color) -> Color {
        Color(red: lhs.red + rhs.red, green: lhs.green + rhs.green, blue: lhs.blue + rhs.blue)
    }
}

public enum SurfaceType {
    case diffuse
    case reflective(reflectivity: Float)
    case refractive(index: Float, transparency: Float)
}

public struct Material {
    var color: Color
    var albedo: Float
    var surface: SurfaceType

    public init(color: Color, albedo: Float, surface: SurfaceType) {
        self.color = color
        self.albedo = albedo
        self.surface = surface
    }
}

public struct Sphere {
    var center: Point
    var radius: Double
    var material: Material

    public init(center: Point, radius: Double, material: Material) {
        self.center = center
        self.radius = radius
        self.material = material
    }
}

public struct Plane {
    var origin: Point
    var normal: Vector3
    var material: Material

    public init(origin: Point, normal: Vector3, material: Material) {
        self.origin = origin
        self.normal = normal
        self.material = material
    }
}

public enum Element {
    case sphere(Sphere)
    case plane(Plane)

    var material: Material {
        switch self {
        case .sphere(let sphere): return sphere.material
        case .plane(let plane): return plane.material
        }
    }
}

struct Intersection {
    var distance: Double
    var elementIndex: Int
}

public struct DirectionalLight {
    var direction: Vector3
    var color: Color
    var intensity: Float

    public init(direction: Vector3, color: Color, intensity: Float) {
        self.direction = direction
        self.color = color
        self.intensity = intensity
    }
}

public struct SphericalLight {
    var position: Point
    var color: Color
    var intensity: Float

    public init(position: Point, color: Color, intensity: Float) {
        self.position = position
        self.color = color
        self.intensity = intensity
    }
}

public enum Light {
    case directional(DirectionalLight)
    case spherical(SphericalLight)

    func directionFrom(hitPoint: Point) -> Vector3 {
        switch self {
        case .directional(let directionalLight):
            return Vector3.zero - directionalLight.direction
        case .spherical(let sphericalLight):
            return (sphericalLight.position - hitPoint).normalize()
        }
    }

    func intensity(hitPoint: Point) -> Float {
        switch self {
        case .directional(let directionalLight):
            return directionalLight.intensity
        case .spherical(let sphericalLight):
            let r2 = Float((sphericalLight.position - hitPoint).norm)
            return sphericalLight.intensity / (4.0 * .pi * r2)
        }
    }

    func distance(hitPoint: Point) -> Double {
        switch self {
        case .directional: return .infinity
        case .spherical(let sphericalLight):
            return (sphericalLight.position - hitPoint).length
        }
    }

    var color: Color {
        switch self {
        case .directional(let directionalLight):
            return directionalLight.color
        case .spherical(let sphericalLight):
            return sphericalLight.color
        }
    }
}

public struct Scene {
    public var width: Int
    public var height: Int
    public var fov: Double
    public var elements: [Element]
    public var lights: [Light]

    public var shadowBias: Double
    public var maxRecursionDepth: Int

    public init(
        width: Int, height: Int, fov: Double, elements: [Element],
        lights: [Light],
        shadowBias: Double, maxRecursionDepth: Int
    ) {
        self.width = width
        self.height = height
        self.fov = fov
        self.elements = elements
        self.lights = lights
        self.shadowBias = shadowBias
        self.maxRecursionDepth = maxRecursionDepth
    }

    func trace(ray: Ray) -> Intersection? {
        let intersections = self.elements.enumerated().compactMap { index, element in
            element.intersect(ray: ray).map {
                Intersection(distance: $0, elementIndex: index)
            }
        }
        return intersections.min {
            $0.distance < $1.distance
        }
    }
}
