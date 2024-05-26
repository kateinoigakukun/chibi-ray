public struct ImageBuffer {
    public let width, height: Int
    public private(set) var data: [Color]

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        self.data = [Color].init(repeating: .black, count: width * height)
    }

    public subscript(x: Int, y: Int) -> Color {
        get {
            self.data[self.width * y + x]
        }
        set {
            self.data[self.width * y + x] = newValue
        }
    }
}
