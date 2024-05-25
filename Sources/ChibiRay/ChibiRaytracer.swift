public func render(scene: borrowing Scene) -> ImageBuffer {
    var image = ImageBuffer(width: scene.width, height: scene.height)
    for x in 0..<scene.width {
        for y in 0..<scene.height {
            let ray = Ray.createPrime(x: x, y: y, scene: scene)
            let color = castRay(scene: scene, ray: ray, depth: 0)
            image[x, y] = color
        }
    }
    return image
}
