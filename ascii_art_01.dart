import 'dart:async';
import 'dart:io';

void main() async {
  // Define frames of your animation
  final frames = [
    r'''
   (\_/)
   ( •_•)
   / >🍪
    ''',
    r'''
   (\_/)
   ( •_•)
   🍪< \
    ''',
    r'''
   (\_/)
   ( •_•)
   / >🍪
    '''
  ];

  const frameDelay = Duration(milliseconds: 300);

  // Loop forever
  var i = 0;
  while (true) {
    _clearScreen();
    print(frames[i]);
    await Future.delayed(frameDelay);
    i = (i + 1) % frames.length;
  }
}

// Clears the terminal screen
void _clearScreen() {
  if (Platform.isWindows) {
    // Windows terminal clear
    stdout.write('\x1B[2J\x1B[0;0H');
  } else {
    // ANSI escape code for clear + move cursor to top-left
    stdout.write('\x1B[2J\x1B[H');
  }
}

