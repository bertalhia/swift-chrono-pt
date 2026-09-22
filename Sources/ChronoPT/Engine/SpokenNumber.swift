import Foundation

/// Spelled-out numbers, the ones people use for dates and times: "quinze",
/// "vinte e três". A compound is a ten and a unit joined by "e".
enum SpokenNumber {
    static func value(_ text: some StringProtocol) -> Int? {
        if let number = Int(text) { return number }
        let parts = text.split(separator: " e ").map { String($0) }
        switch parts.count {
        case 1:
            return units[parts[0]] ?? teens[parts[0]] ?? tens[parts[0]]
        case 2:
            guard let ten = tens[parts[0]], let unit = units[parts[1]] else { return nil }
            return ten + unit
        default:
            return nil
        }
    }

    private static let units: [String: Int] = [
        "um": 1, "uma": 1, "dois": 2, "duas": 2, "tres": 3, "quatro": 4, "cinco": 5,
        "seis": 6, "sete": 7, "oito": 8, "nove": 9
    ]

    private static let teens: [String: Int] = [
        "dez": 10, "onze": 11, "doze": 12, "treze": 13, "catorze": 14, "quatorze": 14, "quinze": 15,
        "dezesseis": 16, "dezessete": 17, "dezoito": 18, "dezenove": 19
    ]

    private static let tens: [String: Int] = ["vinte": 20, "trinta": 30, "quarenta": 40, "cinquenta": 50]
}
