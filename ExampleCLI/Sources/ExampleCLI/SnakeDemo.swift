import Foundation
import Rainbow

class SnakeDemo {
    private let terminal = TerminalConfig()
    private var isRunning = false
    private var lastUpdateTime = Date()
    private var score = 0
    private var highScore = 0
    
    // Game speed (lower = faster)
    private var gameSpeed: TimeInterval = 0.08
    
    // Screen dimensions
    private var width = 20  // Classic Nokia 3310 Snake had a small grid
    private var height = 15
    
    // Snake properties
    private var snakeBody: [(x: Int, y: Int)] = []
    private var direction: Direction = .right
    private var nextDirection: Direction = .right
    
    // Food position
    private var foodPosition: (x: Int, y: Int) = (0, 0)
    
    // Direction enum
    private enum Direction {
        case up, down, left, right
    }
    
    init() {
        resetGame()
    }
    
    private func resetGame() {
        // Initialize snake in the middle
        snakeBody = [(width / 2, height / 2)]
        direction = .right
        nextDirection = .right
        score = 0
        
        // Place initial food
        placeFood()
    }
    
    private func placeFood() {
        var newPosition: (x: Int, y: Int)
        
        repeat {
            newPosition = (Int.random(in: 0..<width), Int.random(in: 0..<height))
        } while snakeBody.contains(where: { $0.x == newPosition.x && $0.y == newPosition.y })
        
        foodPosition = newPosition
    }
    
    func run() {
        terminal.enableRawMode()
        defer {
            terminal.disableRawMode()
        }
        
        print(TerminalControl.hideCursor, terminator: "")
        defer {
            print(TerminalControl.showCursor, terminator: "")
        }
        
        isRunning = true
        lastUpdateTime = Date()
        
        // Create a separate thread for handling keyboard input
        let inputThread = Thread {
            while self.isRunning {
                if let char = self.readChar() {
                    switch char {
                    case 113: // 'q' key
                        self.isRunning = false
                    case 119, 65: // 'w' or up arrow
                        if self.direction != .down {
                            self.nextDirection = .up
                        }
                    case 115, 66: // 's' or down arrow
                        if self.direction != .up {
                            self.nextDirection = .down
                        }
                    case 97, 68: // 'a' or left arrow
                        if self.direction != .right {
                            self.nextDirection = .left
                        }
                    case 100, 67: // 'd' or right arrow
                        if self.direction != .left {
                            self.nextDirection = .right
                        }
                    case 114: // 'r' key - restart
                        self.resetGame()
                    default:
                        break
                    }
                }
                Thread.sleep(forTimeInterval: 0.01)
            }
        }
        inputThread.start()
        
        // Main game loop
        while isRunning {
            let now = Date()
            let elapsed = now.timeIntervalSince(lastUpdateTime)
            
            if elapsed >= gameSpeed {
                updateGame()
                renderFrame()
                lastUpdateTime = now
            }
            
            // Small sleep to prevent CPU hogging
            Thread.sleep(forTimeInterval: 0.01)
        }
    }
    
    private func updateGame() {
        // Update direction
        direction = nextDirection
        
        // Calculate new head position
        var newHead = snakeBody.first!
        
        switch direction {
        case .up:
            newHead.y -= 1
        case .down:
            newHead.y += 1
        case .left:
            newHead.x -= 1
        case .right:
            newHead.x += 1
        }
        
        // Check for wrap around (Nokia 3310 style)
        if newHead.x < 0 {
            newHead.x = width - 1
        } else if newHead.x >= width {
            newHead.x = 0
        }
        
        if newHead.y < 0 {
            newHead.y = height - 1
        } else if newHead.y >= height {
            newHead.y = 0
        }
        
        // Check for collision with self
        if snakeBody.contains(where: { $0.x == newHead.x && $0.y == newHead.y }) {
            // Game over
            if score > highScore {
                highScore = score
            }
            resetGame()
            return
        }
        
        // Add new head
        snakeBody.insert(newHead, at: 0)
        
        // Check if food was eaten
        if newHead.x == foodPosition.x && newHead.y == foodPosition.y {
            // Increase score
            score += 1
            
            // Place new food
            placeFood()
            
            // Speed up the game more aggressively
            if gameSpeed > 0.03 {
                gameSpeed *= 0.95
            }
        } else {
            // Remove tail if no food was eaten
            snakeBody.removeLast()
        }
    }
    
    private func renderFrame() {
        // Clear screen
        print(TerminalControl.clear, terminator: "")
        
        // Create a buffer for the screen
        var buffer = Array(repeating: Array(repeating: " ", count: width * 2 + 2), count: height + 2)
        
        // Draw border
        for x in 0..<width * 2 + 2 {
            buffer[0][x] = "─"
            buffer[height + 1][x] = "─"
        }
        
        for y in 0..<height + 2 {
            buffer[y][0] = "│"
            buffer[y][width * 2 + 1] = "│"
        }
        
        // Draw corners
        buffer[0][0] = "┌"
        buffer[0][width * 2 + 1] = "┐"
        buffer[height + 1][0] = "└"
        buffer[height + 1][width * 2 + 1] = "┘"
        
        // Draw snake
        for (index, segment) in snakeBody.enumerated() {
            let x = segment.x * 2 + 1
            let y = segment.y + 1
            
            if x >= 1 && x < width * 2 + 1 && y >= 1 && y < height + 1 {
                if index == 0 {
                    // Snake head
                    buffer[y][x] = "◉"
                } else {
                    // Snake body
                    buffer[y][x] = "●"
                }
            }
        }
        
        // Draw food
        let foodX = foodPosition.x * 2 + 1
        let foodY = foodPosition.y + 1
        if foodX >= 1 && foodX < width * 2 + 1 && foodY >= 1 && foodY < height + 1 {
            buffer[foodY][foodX] = "★"
        }
        
        // Render buffer to screen
        for y in 0..<height + 2 {
            for x in 0..<width * 2 + 2 {
                let char = buffer[y][x]
                
                if snakeBody.contains(where: { $0.x * 2 + 1 == x && $0.y + 1 == y }) {
                    if snakeBody.first?.x == (x - 1) / 2 && snakeBody.first?.y == y - 1 {
                        // Head is green
                        print(char.green, terminator: "")
                    } else {
                        // Body is blue
                        print(char.blue, terminator: "")
                    }
                } else if foodPosition.x * 2 + 1 == x && foodPosition.y + 1 == y {
                    // Food is red
                    print(char.red, terminator: "")
                } else {
                    // Border is white
                    print(char.white, terminator: "")
                }
            }
            print()
        }
        
        // Show stats
        print("─".repeated(width * 2 + 2).dim)
        print("Score: \(score) | High Score: \(highScore) | Controls: ↑↓←→ or WASD | R: Restart | Q: Quit".bold)
        
        // Flush output
        fflush(stdout)
    }
    
    private func readChar() -> UInt8? {
        var input: UInt8 = 0
        let count = read(STDIN_FILENO, &input, 1)
        return count == 1 ? input : nil
    }
}

// Using the repeated extension defined in AnimationDemo.swift
