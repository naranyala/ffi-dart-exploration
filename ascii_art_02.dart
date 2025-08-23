import 'dart:async';
import 'dart:io';

void main() async {
  const screenWidth = 60;
  const screenHeight = 15;
  const delay = Duration(milliseconds: 80);
  
  var ballX = 5;
  var ballY = 5;
  var velocityX = 1;
  var velocityY = 1;
  
  // Different ball characters for animation effect
  const ballFrames = ['●', '◉', '○'];
  var frameIndex = 0;
  
  while (true) {
    _clearScreen();
    
    // Create the playing field
    for (int y = 0; y < screenHeight; y++) {
      String line = '';
      for (int x = 0; x < screenWidth; x++) {
        if (y == 0 || y == screenHeight - 1) {
          // Top and bottom borders
          line += '-';
        } else if (x == 0 || x == screenWidth - 1) {
          // Left and right borders  
          line += '|';
        } else if (x == ballX && y == ballY) {
          // Ball position
          line += ballFrames[frameIndex];
        } else {
          line += ' ';
        }
      }
      print(line);
    }
    
    await Future.delayed(delay);
    
    // Update ball position
    ballX += velocityX;
    ballY += velocityY;
    
    // Bounce off walls
    if (ballX <= 1 || ballX >= screenWidth - 2) {
      velocityX *= -1;
    }
    if (ballY <= 1 || ballY >= screenHeight - 2) {
      velocityY *= -1;
    }
    
    // Animate ball appearance
    frameIndex = (frameIndex + 1) % ballFrames.length;
  }
}

void _clearScreen() {
  stdout.write('\x1B[2J\x1B[H');
}
