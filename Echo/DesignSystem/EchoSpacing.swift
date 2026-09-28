import CoreGraphics

// MARK: - Echo spacing scale

enum EchoSpacing {
    static let xxs:  CGFloat =  4
    static let xs:   CGFloat =  8
    static let sm:   CGFloat = 12
    static let md:   CGFloat = 16
    static let lg:   CGFloat = 24
    static let xl:   CGFloat = 32
    static let xxl:  CGFloat = 48
    static let xxxl: CGFloat = 64

    enum Corner {
        static let sm:   CGFloat =  8
        static let md:   CGFloat = 12
        static let lg:   CGFloat = 16
        static let xl:   CGFloat = 20
        static let xxl:  CGFloat = 28
        static let full: CGFloat = 999
    }

    enum Shadow {
        static let softRadius:  CGFloat = 12
        static let softY:       CGFloat =  4
        static let softOpacity: Double  =  0.12
    }
}
