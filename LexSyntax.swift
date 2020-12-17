import UIKit

enum Token: String, CustomStringConvertible {
    var description: String {
        self.rawValue
    }
    
    case keyword = "KEYWORD"
    case id = "ID"
    case num = "NUM"
    case operation = "OPERATOR"
    case string = "STRING"
    case space = "SPACE"
    
    func getRegex() -> String {
        switch self {
        case .keyword:
            return #"\b(alter table|drop column)\b"#
        case .id:
            return #"[A-Za-z][A-Za-z0-9\._]*"#
        case .num:
            return #"[0-9]+"#
        case .string:
            return #"'[^']*'"#
        case .operation:
            return #"[=\(\)\*,]"#
        case .space:
            return #"\s+"#
        }
    }
    
    
    
    static let cases: [Token] = [.keyword, .id, .num, .operation, .string, .space]
}
public extension String {
    func paddedToWidth(_ width: Int) -> String {
        let length = self.count
        guard length < width else {
            return self
        }

        let spaces = Array<Character>.init(repeating: " ", count: width - length)
        return self + spaces
    }
}
struct Symbol: CustomStringConvertible {
    var token: Token
    var lex: String
    var start: Int
    var length: Int {
        lex.count
    }
    
    var description: String {
        "\("\(token)".paddedToWidth(10)) \(lex.paddedToWidth(20)) \(String(start).paddedToWidth(8))\(String(length).paddedToWidth(8))"
    }
}

func getTokenFromString<T: StringProtocol>(_ str: T) -> (Token, T.SubSequence)? {
    for token in Token.cases {
        
        if let range = str.range(of: "^" + token.getRegex(), options: [.regularExpression, .caseInsensitive]) {
            let str = str[range]
            return (token, str)
        }
    }
    return nil
}

func getAllTokens<T: StringProtocol>(string: T, position: Int = 0, result: inout [Symbol]) {
    guard let token = getTokenFromString(string) else {
        return
    }
    var newPosition = position
    switch token.0 {
    case .space:
        break
    default:
        newPosition += token.1.utf16.count
        let symbol = Symbol(token: token.0, lex: String(token.1), start: position)
        result.append(symbol)
    }
    let substring = string[string.index(string.startIndex, offsetBy: token.1.utf16.count)...]
    
    getAllTokens(string: substring, position: newPosition, result: &result)
}

func getTokens(_ string: String) -> [Symbol] {
    var results = [Symbol]()
    getAllTokens(string: string, result: &results)
    return results
}

func printTable(_ tokens: [Symbol]) {
    print("\("Токен".paddedToWidth(10)) \("Лексема".paddedToWidth(20)) \("Начало".paddedToWidth(8))\("Длина".paddedToWidth(8))")
    for lex in tokens {
        print(lex)
    }
}

func toPdaInput(symbols: [Symbol]) -> String {
    return symbols.map { symbol -> Input in
        if symbol.token == .keyword {
            switch symbol.lex {
            case "ALTER TABLE":
                return .alterTable
            case "DROP COLUMN":
                return .dropColumn
            default: fatalError()
            }
        }
        if symbol.token == .id {
            return .id
        }
        fatalError()
    }.reduce(into: "", { $0 += $1.rawValue })
}

enum Input: String, Hashable {
    case alterTable = "<ALTER TABLE>"
    case dropColumn = "<DROP COLUMN>"
    case id = "<id>"
    case dollar = "$"
}

enum PdaState: CustomStringConvertible, Hashable {
    var description: String {
        switch self {
        case .S: return "<S>"
        case .ALT: return "<ALT>"
        case .EMP: return "<EMP>"
        }
    }
    
    // States
    case S
    case ALT
    case EMP
}

struct PdaStateInput: Hashable {
    var ps: PdaState
    var inp: Input
    init(_ ps: PdaState, _ inp: Input) {
        self.ps = ps
        self.inp = inp
    }
}

enum StateSymbol: CustomStringConvertible {
    case terminal(Input)
    case state(PdaState)
    case empty
    
    var description: String {
        switch self {
        case let .terminal(s): return s.rawValue
        case let .state(state): return "\(state)"
        case .empty: return ""
        }
    }
}

let mTable: [PdaStateInput: [StateSymbol]] = [
    .init(.S, .alterTable): [.terminal(.alterTable), .terminal(.id), .terminal(.dropColumn), .terminal(.id)],
    .init(.ALT, .dollar): [.empty],
    .init(.EMP, .id): [.empty]
]


struct StringError: Error, LocalizedError {
    var message: String
    var errorDescription: String? { message }
}
class Pda {
    private var stack = [StateSymbol]()
    private var currentString: String
    private var currentSymb: String? {
        if let second = currentString.firstIndex(of: ">") {
            return String(currentString[...second])
        }
        return nil
    }
    
    private func translate(_ state: PdaState) throws -> [StateSymbol] {
        guard let curr = currentSymb else { throw StringError(message: "CurrentSymbol is nil: \(currentSymb)")}
        
        guard let input = Input(rawValue: curr),
              let symbols = mTable[.init(state, input)] else { throw StringError(message: "No match \(state) to \(curr)") }
        return symbols
    }
    
    init(_ string: String) {
        self.currentString = string
    }
    
    func analyze() throws {
        stack.append(.terminal(.dollar))
        stack.append(.state(.S))
        log()
        try recursive()
    }
        
    private func recursive() throws {
        guard !currentString.isEmpty else { return }
        guard let popped = stack.popLast() else { return }
        switch popped {
        case let .state(state):
            var symbols: [StateSymbol] = (try translate(state)).reversed()
            stack.append(contentsOf: symbols)
            log()
        case let .terminal(terminal):
            guard Input(rawValue: String(currentSymb!))! == terminal else { throw StringError(message: "Should be \(terminal) got \(currentSymb)") }
            currentString = String(currentString[currentString.index(currentString.startIndex, offsetBy: currentSymb!.count)...])
            log()
        case .empty: break
        }
        try recursive()
    }
    
    private func log() {
        print("\("\(stack.reduce(into: "") { $0 += "\($1)" })".paddedToWidth(20)) \t \(currentString)")
    }
}

func go(realString: String) {
    print(realString)
    print("-------------------------------------")
    let tokens = getTokens(realString)
    printTable(tokens)
    print("-------------------------------------")
    let pdaInp = toPdaInput(symbols: tokens)
    print(pdaInp)
    print("-------------------------------------")
    let pda = Pda(pdaInp)
    do {
        try pda.analyze()
    } catch {
        print(error.localizedDescription)
    }
}

let realString1 = """
ALTER TABLE Table1 DROP COLUMN Email;
"""

go(realString: realString1)
