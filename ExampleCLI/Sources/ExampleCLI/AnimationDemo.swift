import Foundation
import Rainbow

class AnimationDemo {
    private let terminal = TerminalConfig()
    private var isRunning = false
    private var frameCount = 0
    private var lastFPSUpdate = Date()
    private var currentFPS: Double = 0
    
    // Animation frames for a simple spinner
    private let spinnerFrames = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
    private var currentFrame = 0
    
    // Screen dimensions
    private var width = 80
    private var height = 24
    
    // Animation objects
    private struct AnimatedObject {
        var x: Double
        var y: Double
        var xVelocity: Double
        var yVelocity: Double
        var character: String
        var color: (String) -> String
    }
    
    private var objects: [AnimatedObject] = []
    
    init() {
        // Create some animated objects
        let colors: [(String) -> String] = [
            { $0.red },
            { $0.green },
            { $0.blue },
            { $0.yellow },
            { $0.magenta },
            { $0.cyan }
        ]
        
        for _ in 0..<10 {
            let x = Double.random(in: 0..<Double(width))
            let y = Double.random(in: 0..<Double(height))
            let xVel = Double.random(in: -1.0...1.0)
            let yVel = Double.random(in: -1.0...1.0)
            let char = ["●", "■", "★", "✦", "◆"].randomElement() ?? "●"
            let color = colors.randomElement()!
            
            objects.append(AnimatedObject(
                x: x,
                y: y,
                xVelocity: xVel,
                yVelocity: yVel,
                character: char,
                color: color
            ))
        }
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
        
        // Get terminal size if possible
        if let (w, h) = getTerminalSize() {
            width = w
            height = h - 3 // Reserve space for stats
        }
        
        isRunning = true
        lastFPSUpdate = Date()
        
        // Create a separate thread for handling keyboard input
        let inputThread = Thread {
            while self.isRunning {
                if let char = self.readChar() {
                    if char == 113 { // 'q' key
                        self.isRunning = false
                        break
                    }
                }
                Thread.sleep(forTimeInterval: 0.01)
            }
        }
        inputThread.start()
        
        // Main animation loop
        while isRunning {
            renderFrame()
            frameCount += 1
            
            // Update FPS counter every second
            let now = Date()
            let elapsed = now.timeIntervalSince(lastFPSUpdate)
            if elapsed >= 1.0 {
                currentFPS = Double(frameCount) / elapsed
                frameCount = 0
                lastFPSUpdate = now
            }
            
            // Aim for 60 FPS (16.67ms per frame)
            Thread.sleep(forTimeInterval: 0.0167)
        }
    }
    
    private func renderFrame() {
        // Clear screen
        print(TerminalControl.clear, terminator: "")
        
        // Create a buffer for the screen
        var buffer = Array(repeating: Array(repeating: " ", count: width), count: height)
        
        // Update object positions
        for i in 0..<objects.count {
            // Update position
            objects[i].x += objects[i].xVelocity
            objects[i].y += objects[i].yVelocity
            
            // Bounce off walls
            if objects[i].x < 0 {
                objects[i].x = 0
                objects[i].xVelocity = -objects[i].xVelocity
            } else if objects[i].x >= Double(width) {
                objects[i].x = Double(width - 1)
                objects[i].xVelocity = -objects[i].xVelocity
            }
            
            if objects[i].y < 0 {
                objects[i].y = 0
                objects[i].yVelocity = -objects[i].yVelocity
            } else if objects[i].y >= Double(height) {
                objects[i].y = Double(height - 1)
                objects[i].yVelocity = -objects[i].yVelocity
            }
            
            // Draw to buffer
            let x = Int(objects[i].x)
            let y = Int(objects[i].y)
            if x >= 0 && x < width && y >= 0 && y < height {
                buffer[y][x] = objects[i].character
            }
        }
        
        // Render buffer to screen
        for y in 0..<height {
            for x in 0..<width {
                let char = buffer[y][x]
                if char != " " {
                    // Find which object is at this position
                    for obj in objects {
                        if Int(obj.x) == x && Int(obj.y) == y {
                            print(obj.color(char), terminator: "")
                            break
                        }
                    }
                } else {
                    print(char, terminator: "")
                }
            }
            print()
        }
        
        // Show stats
        print("─".repeated(width).dim)
        print("FPS: \(String(format: "%.2f", currentFPS)) | Objects: \(objects.count) | Press 'q' to quit".bold)
        
        // Update spinner
        currentFrame = (currentFrame + 1) % spinnerFrames.count
        
        // Flush output
        fflush(stdout)
    }
    
    private func readChar() -> UInt8? {
        var input: UInt8 = 0
        let count = read(STDIN_FILENO, &input, 1)
        return count == 1 ? input : nil
    }
    
    private func getTerminalSize() -> (Int, Int)? {
        var size = winsize()
        if ioctl(STDOUT_FILENO, UInt(TIOCGWINSZ), &size) == 0 {
            return (Int(size.ws_col), Int(size.ws_row))
        }
        return nil
    }
}

// Extension to repeat a string
extension String {
    func repeated(_ count: Int) -> String {
        return String(repeating: self, count: count)
    }
}
