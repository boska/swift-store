import Foundation
import SwiftStore
import Rainbow

// Terminal control codes
enum TerminalControl {
    static let up = "\u{001B}[A"
    static let down = "\u{001B}[B"
    static let right = "\u{001B}[C"
    static let left = "\u{001B}[D"
    static let clear = "\u{001B}[2J\u{001B}[H"
    static let clearLine = "\u{001B}[2K"
    static let hideCursor = "\u{001B}[?25l"
    static let showCursor = "\u{001B}[?25h"
}

// Global function for terminal cleanup
@_cdecl("cleanup_terminal")
func cleanupTerminal() {
    // Reset terminal to normal mode
    var term = termios()
    tcgetattr(STDIN_FILENO, &term)
    term.c_lflag |= UInt32(ECHO | ICANON)
    tcsetattr(STDIN_FILENO, TCSAFLUSH, &term)
    print("\u{001B}[?25h") // Show cursor
    fflush(stdout)
}

// Terminal raw mode handling
final class TerminalConfig {
    private var originalTermios: termios
    
    init() {
        originalTermios = termios()
        tcgetattr(STDIN_FILENO, &originalTermios)
    }
    
    func enableRawMode() {
        var raw = originalTermios
        raw.c_lflag &= ~UInt32(ECHO | ICANON)
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw)
        print(TerminalControl.hideCursor, terminator: "")
        fflush(stdout)
    }
    
    func disableRawMode() {
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &originalTermios)
        print(TerminalControl.showCursor, terminator: "")
        print() // Add a newline
        fflush(stdout)
    }
    
    deinit {
        disableRawMode()
    }
}

// Demo options for the main menu
enum DemoOption: String, CaseIterable {
    case todoList = "TodoList"
    case animationDemo = "Animation Demo"
    case exit = "Exit"
}

// Helper function to read a single character
func readChar() -> UInt8? {
    var input: UInt8 = 0
    let count = read(STDIN_FILENO, &input, 1)
    return count == 1 ? input : nil
}

// Helper function to display the main menu
func displayMainMenu(options: [DemoOption], selectedIndex: Int) {
    print(TerminalControl.clear, terminator: "")
    print("🚀 Example CLI Demo Selector".blue.bold)
    print("Use arrow keys to navigate and Enter to select\n".green)
    
    print("💼 Available Demos:".blue.bold)
    for (index, option) in options.enumerated() {
        if index == selectedIndex {
            print(" ▶️  ".green + option.rawValue.white.bold)
        } else {
            print("    " + option.rawValue)
        }
    }
}

// Main program loop
func runMainMenu() async {
    let terminalConfig = TerminalConfig()
    terminalConfig.enableRawMode()
    
    defer {
        terminalConfig.disableRawMode()
    }
    
    print(TerminalControl.hideCursor, terminator: "")
    
    let options = DemoOption.allCases
    var selectedIndex = 0
    var running = true
    
    mainLoop: while running {
        displayMainMenu(options: options, selectedIndex: selectedIndex)
        
        guard let char = readChar() else { continue }
        
        switch char {
        case 27:
            // Handle arrow keys (escape sequences)
            guard let _ = readChar() else { continue } // Skip [
            guard let arrow = readChar() else { continue }
            switch arrow {
            case 65: // Up arrow
                selectedIndex = (selectedIndex - 1 + options.count) % options.count
            case 66: // Down arrow
                selectedIndex = (selectedIndex + 1) % options.count
            default:
                break
            }
            
        case 10, 13: // Enter key (both \n and \r)
            let selectedOption = options[selectedIndex]
            
            switch selectedOption {
            case .todoList:
                // Temporarily restore normal terminal mode for the TodoDemo
                terminalConfig.disableRawMode()
                
                // Run the TodoDemo
                let todoDemo = TodoDemo()
                await todoDemo.run()
                
                // Restore raw mode for main menu
                terminalConfig.enableRawMode()
                
            case .animationDemo:
                // Temporarily restore normal terminal mode for the AnimationDemo
                terminalConfig.disableRawMode()
                
                // Run the AnimationDemo
                let animationDemo = AnimationDemo()
                animationDemo.run()
                
                // Restore raw mode for main menu
                terminalConfig.enableRawMode()
                
            case .exit:
                running = false
                print(TerminalControl.showCursor, terminator: "")
                break mainLoop
            }
            
        default:
            break
        }
    }
}

// Start the main menu
await runMainMenu()
