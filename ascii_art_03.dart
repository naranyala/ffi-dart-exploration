import 'dart:async';
import 'dart:io';
import 'dart:math';

void main() async {
  const screenWidth = 70;
  const screenHeight = 20;
  const delay = Duration(milliseconds: 150);
  const maxDrops = 25;
  
  final random = Random();
  final rainDrops = <RainDrop>[];
  
  // Rain characters for variation
  const rainChars = ['|', '¦', '│', '!'];
  
  while (true) {
    _clearScreen();
    
    // Add new raindrops randomly
    if (rainDrops.length < maxDrops && random.nextDouble() < 0.7) {
      rainDrops.add(RainDrop(
        x: random.nextInt(screenWidth),
        y: 0,
        char: rainChars[random.nextInt(rainChars.length)],
        speed: 1 + random.nextInt(2), // Some drops fall faster
      ));
    }
    
    // Create screen buffer
    final screen = List.generate(
      screenHeight, 
      (_) => List.filled(screenWidth, ' ')
    );
    
    // Draw ground puddles
    for (int x = 0; x < screenWidth; x++) {
      if (random.nextDouble() < 0.3) {
        screen[screenHeight - 1][x] = '~';
      }
    }
    
    // Draw raindrops
    for (var drop in rainDrops) {
      if (drop.y >= 0 && drop.y < screenHeight - 1) {
        screen[drop.y][drop.x] = drop.char;
      }
    }
    
    // Print screen
    for (var row in screen) {
      print(row.join(''));
    }
    
    // Add some atmosphere at the bottom
    print('═' * screenWidth);
    print('  💧 Heavy rain falling... Press Ctrl+C to stop 💧');
    
    await Future.delayed(delay);
    
    // Update raindrop positions
    for (int i = rainDrops.length - 1; i >= 0; i--) {
      rainDrops[i].y += rainDrops[i].speed;
      
      // Remove drops that hit the ground
      if (rainDrops[i].y >= screenHeight - 1) {
        rainDrops.removeAt(i);
      }
    }
  }
}

class RainDrop {
  int x;
  int y;
  String char;
  int speed;
  
  RainDrop({
    required this.x,
    required this.y,
    required this.char,
    required this.speed,
  });
}

void _clearScreen() {
  stdout.write('\x1B[2J\x1B[H');
}
