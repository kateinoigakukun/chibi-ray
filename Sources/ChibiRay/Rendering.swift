#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(WASILibc)
import WASILibc
#endif

struct Ray {
    var origin: Point
    var direction: Vector3

    static func createPrime(x: Int, y: Int, scene: borrowing Scene) -> Ray {
        let fovAdjustment = tan((scene.fov * .pi / 180.0) / 2.0)
        let aspectRatio = Double(scene.width) / Double(scene.height)
        let sensorX = (((Double(x) + 0.5) / Double(scene.width)) * 2.0 - 1.0) * aspectRatio * fovAdjustment
        let sensorY = (1.0 - ((Double(y) + 0.5) / Double(scene.height)) * 2.0) * fovAdjustment
        return Ray(
            origin: .zero,
            direction: Vector3(
                x: sensorX,
                y: sensorY,
                z: -1.0
            ).normalize()
        )
    }

    static func createReflection(
        normal: Vector3, incident: Vector3,
        intersection: Point, bias: Double
    ) -> Ray {
        Ray(
            origin: intersection + (normal * bias),
            direction: incident - (2.0 * incident.dot(normal) * normal)
        )
    }

    static func createTransmission(
        normal: Vector3,
        incident: Vector3,
        intersection: Point,
        bias: Double,
        index: Float
    ) -> Ray? {
        var refN = normal
        var etaT = Double(index)
        var etaI = 1.0
        var iDotN = incident.dot(normal)
        if iDotN < 0.0 {
            iDotN = -iDotN
        } else {
            refN = Vector3.zero - normal
            etaI = etaT
            etaT = 1.0
        }
        let eta = etaI / etaT
        let k = 1.0 - (eta * eta) * (1.0 - iDotN * iDotN)
        guard k >= 0.0 else { return nil }
        return Ray(
            origin: intersection + (refN * -bias),
            direction: (incident + iDotN * refN) * eta - refN * k.squareRoot()
        )
    }
}

struct TextureCoords {
    var x, y: Float
}

protocol Intersectable {
    func intersect(ray: Ray) -> Double?

    func surfaceNormal(hitPoint: Point) -> Vector3
    func textureCoords(hitPoint: Point) -> TextureCoords
}

extension Sphere: Intersectable {
    func intersect(ray: Ray) -> Double? {
        // Create a line segment between the ray origin and the center of the sphere
        let l: Vector3 = self.center - ray.origin
        // Use l as a hypotenuse and find the length of the adjacent side
        let adj = l.dot(ray.direction)
        let d2 = l.dot(l) - (adj * adj)
        let radius2 = self.radius * self.radius
        guard d2 < radius2 else { return nil }
        let thc = (radius2 - d2).squareRoot()
        let t0 = adj - thc
        let t1 = adj + thc

        if t0 < 0.0, t1 < 0.0 {
            return nil
        } else if t0 < 0.0 {
            return t1
        } else if t1 < 0.0 {
            return t0
        } else {
            let distance = t0 < t1 ? t0 : t1
            return distance
        }
    }

    func surfaceNormal(hitPoint: Point) -> Vector3 {
        (hitPoint - self.center).normalize()
    }

    func textureCoords(hitPoint: Point) -> TextureCoords {
        let hitVec = hitPoint - self.center
        return TextureCoords(
            x: (1.0 + Float(atan2(hitVec.z, hitVec.x)) / .pi),
            y: Float(acos(hitVec.y / self.radius)) / .pi
        )
    }
}

extension Plane: Intersectable {
    func intersect(ray: Ray) -> Double? {
        let denom = normal.dot(ray.direction)
        guard denom > 1e-6 else { return nil }
        let v = origin - ray.origin
        let distance = v.dot(normal) / denom
        guard distance > 0.0 else { return nil }
        return distance
    }

    func surfaceNormal(hitPoint: Point) -> Vector3 {
        Vector3.zero - normal
    }

    func textureCoords(hitPoint: Point) -> TextureCoords {
        var xAxis = normal.cross(Vector3(x: 0.0, y: 0.0, z: 1.0))
        if xAxis.length == 0.0 {
            xAxis = normal.cross(Vector3(x: 0.0, y: 1.0, z: 0.0))
        }
        let yAxis = normal.cross(xAxis)
        let hitVec = hitPoint - origin
        return TextureCoords(x: Float(hitVec.dot(xAxis)), y: Float(hitVec.dot(yAxis)))
    }
}

extension Element: Intersectable {
    func intersect(ray: Ray) -> Double? {
        switch self {
        case .sphere(let sphere): return sphere.intersect(ray: ray)
        case .plane(let plane): return plane.intersect(ray: ray)
        }
    }

    func surfaceNormal(hitPoint: Point) -> Vector3 {
        switch self {
        case .sphere(let sphere): return sphere.surfaceNormal(hitPoint: hitPoint)
        case .plane(let plane): return plane.surfaceNormal(hitPoint: hitPoint)
        }
    }

    func textureCoords(hitPoint: Point) -> TextureCoords {
        switch self {
        case .sphere(let sphere): return sphere.textureCoords(hitPoint: hitPoint)
        case .plane(let plane): return plane.textureCoords(hitPoint: hitPoint)
        }
    }
}

func shadeDiffuse(
    scene: borrowing Scene,
    element: borrowing Element,
    hitPoint: Point,
    surfaceNormal: Vector3
) -> Color {
    var color = Color.black
    for light in scene.lights {
        let directionToLight = light.directionFrom(hitPoint: hitPoint)

        let shadowRay = Ray(
            origin: hitPoint + surfaceNormal * scene.shadowBias,
            direction: directionToLight
        )
        let shadowIntersection = scene.trace(ray: shadowRay)
        let inLight = shadowIntersection.map {
            $0.distance > light.distance(hitPoint: hitPoint)
        } ?? true
        let lightIntensity = inLight ? light.intensity(hitPoint: hitPoint) : 0.0
        let material = element.material
        let lightPower = max(Float(surfaceNormal.dot(directionToLight)), 0.0) * lightIntensity
        let lightReflected = material.albedo / .pi
        let lightColor = light.color * lightPower * lightReflected
        color = color + (material.color * lightColor)
    }
    return color.clamp()
}

func getColor(scene: borrowing Scene, ray: Ray, intersection: Intersection, depth: Int) -> Color {
    let hit = ray.origin + (ray.direction * intersection.distance)
    let element = scene.elements[intersection.elementIndex]
    let normal = element.surfaceNormal(hitPoint: hit)

    let material = element.material

    switch material.surface {
    case .diffuse:
        return shadeDiffuse(scene: scene, element: element, hitPoint: hit, surfaceNormal: normal)
    case .reflective(let reflectivity):
        var color = shadeDiffuse(scene: scene, element: element, hitPoint: hit, surfaceNormal: normal)
        let reflectionRay = Ray.createReflection(
            normal: normal, incident: ray.direction,
            intersection: hit, bias: scene.shadowBias
        )
        color = color * (1.0 - reflectivity)
        color = color + (castRay(scene: scene, ray: reflectionRay, depth: depth + 1) * reflectivity)
        return color
    case .refractive(let index, let transparency):
        var refractionColor = Color.black
        let kr = Float(fresnel(incident: ray.direction, normal: normal, index: index))
        let surfaceColor = material.color

        if kr < 1.0 {
            let transmissionRay = Ray.createTransmission(
                normal: normal,
                incident: ray.direction, intersection: hit,
                bias: scene.shadowBias, index: index
            )!
            refractionColor = castRay(scene: scene, ray: transmissionRay, depth: depth + 1)
        }
        let reflectionRay = Ray.createReflection(normal: normal, incident: ray.direction, intersection: hit, bias: scene.shadowBias)
        let reflectionColor = castRay(scene: scene, ray: reflectionRay, depth: depth + 1)
        var color = reflectionColor * kr + refractionColor * (1.0 - kr)
        color = color * transparency * surfaceColor
        return color
    }
}

func fresnel(incident: Vector3, normal: Vector3, index: Float) -> Double {
    let iDotN = incident.dot(normal)
    var etaI = Double(1.0)
    var etaT = Double(index)
    if iDotN > 0.0 {
        etaI = etaT
        etaT = 1.0
    }
    let sinT = etaI / etaT * max(1.0 - iDotN * iDotN, 0).squareRoot()
    guard sinT <= 1.0 else { return 1.0 }
    let cosT = max(1.0 - sinT * sinT, 0).squareRoot()
    let cosI = abs(cosT)
    let rs = ((etaT * cosI) - (etaI * cosT)) / ((etaT * cosI) + (etaI * cosT))
    let rp = ((etaI * cosI) - (etaT * cosT)) / ((etaI * cosI) + (etaT * cosT))
    return (rs * rs + rp * rp) / 2.0
}

func castRay(scene: borrowing Scene, ray: Ray, depth: Int) -> Color {
    guard depth < scene.maxRecursionDepth else { return .black }
    guard let intersection = scene.trace(ray: ray) else { return .black }
    return getColor(scene: scene, ray: ray, intersection: intersection, depth: depth)
}
