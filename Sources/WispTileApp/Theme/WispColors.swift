import SwiftUI

public struct WispColors {
    public static let accent = Color(red: 0.29, green: 0.18, blue: 0.77) // #4A2FC4
    public static let accentLight = Color(red: 0.48, green: 0.47, blue: 0.97) // #7B79F7
    
    // Backgrounds
    public static let canvas = Color(red: 0.96, green: 0.96, blue: 0.97) // #F5F5F7
    public static let cardBackground = Color.white
    public static let sidebarTop = Color(red: 0.925, green: 0.925, blue: 0.937) // #ECECEF
    public static let sidebarBottom = Color(red: 0.906, green: 0.906, blue: 0.922) // #E7E7EB
    
    // Borders
    public static let border = Color.black.opacity(0.08)
    public static let sidebarBorder = Color.black.opacity(0.10)
    public static let divider = Color.black.opacity(0.06)
    
    // Typography
    public static let textPrimary = Color(red: 0.114, green: 0.114, blue: 0.122) // #1D1D1F
    public static let textSecondary = Color(red: 0.431, green: 0.431, blue: 0.451) // #6E6E73
    public static let textTertiary = Color(red: 0.525, green: 0.525, blue: 0.545) // #86868B
    
    // Status
    public static let success = Color(red: 0.122, green: 0.478, blue: 0.239) // #1F7A3D
    public static let warning = Color(red: 0.85, green: 0.47, blue: 0.02) // #D97706
    public static let error = Color(red: 0.827, green: 0.184, blue: 0.184) // #D32F2F
    
    public static let statusSuccess = success
    public static let statusWarning = warning
    public static let statusError = error
    
    // Traffic Lights
    public static let trafficRed = Color(red: 1.0, green: 0.373, blue: 0.341) // #FF5F57
    public static let trafficYellow = Color(red: 0.996, green: 0.737, blue: 0.180) // #FEBC2E
    public static let trafficGreen = Color(red: 0.157, green: 0.784, blue: 0.251) // #28C840
}

public extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255.0,
            green: Double((hex >> 8) & 0xff) / 255.0,
            blue: Double(hex & 0xff) / 255.0,
            opacity: alpha
        )
    }
    
    init(hex: String, alpha: Double = 1.0) {
        let hexString = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hexString.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 74, 47, 196)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255.0,
            green: Double(g) / 255.0,
            blue: Double(b) / 255.0,
            opacity: alpha * (Double(a) / 255.0)
        )
    }
}
