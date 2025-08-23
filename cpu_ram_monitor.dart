import 'dart:io';
import 'dart:ffi';
import 'dart:async';
import 'package:ffi/ffi.dart'; // Import the ffi package for calloc and using

// IMPORTANT: To make this code work, you must add the `ffi` package to your
// project's pubspec.yaml file.
//
// Add this line under `dependencies:`:
// ffi: ^2.0.0
//
// Then, run the command `dart pub get` in your terminal.

// FFI requires defining a Dart class that mirrors the native C struct.
// We must ensure the field order and data types match the native `struct sysinfo`
// on a 64-bit Linux system.
// A common definition is found in `<sys/sysinfo.h>`.
final class SysInfo extends Struct {
  @Int64()
  external int uptime;

  @Array(3)
  external Array<Uint64> loads; // `unsigned long` is 64-bit on x86_64

  @Uint64()
  external int totalram;
  @Uint64()
  external int freeram;
  @Uint64()
  external int sharedram;
  @Uint64()
  external int bufferram;

  @Uint64()
  external int totalswap;
  @Uint64()
  external int freeswap;

  @Uint16()
  external int procs;
  @Uint16()
  external int pad; // Padding to ensure correct alignment

  @Uint64()
  external int totalhigh;
  @Uint64()
  external int freehigh;

  @Uint32() // `unsigned int` is 32-bit on x86_64
  external int mem_unit;
}

// Function to clear the console screen using ANSI escape codes.
void clearScreen() {
  stdout.write('\x1B[2J\x1B[H');
}

// Dart function to get system info using FFI.
// This function will call the native 'sysinfo' function from the C library.
int getSystemInfo(Pointer<SysInfo> info) {
  try {
    // Use the FFI to load the native C library (e.g., libc.so.6 on Linux).
    // DynamicLibrary.process() loads the currently running executable's symbols,
    // which is often simpler than opening a specific library file.
    final libc = DynamicLibrary.process();

    // Look up the native 'sysinfo' function from the loaded library.
    final sysinfoNative = libc.lookupFunction<
        Int32 Function(Pointer<SysInfo>),
        int Function(Pointer<SysInfo>)>('sysinfo');

    // Call the native function and return its result.
    return sysinfoNative(info);
  } catch (e) {
    print('Error loading sysinfo: $e');
    return -1;
  }
}

// Main function to run the real-time monitor.
void main() async {
  print('Starting real-time system monitor with FFI...');
  
  // Check if we're on a supported platform
  if (!Platform.isLinux) {
    print('This monitor currently only supports Linux systems.');
    return;
  }
  
  await Future.delayed(Duration(seconds: 2));
  
  // The main loop to update the display.
  Timer.periodic(Duration(seconds: 1), (timer) {
    clearScreen();
    
    // Allocate a buffer to store the result from the C function.
    // We use a `using` block for automatic memory management.
    using((arena) {
      final sysinfo = arena<SysInfo>();
      
      try {
        // Call our Dart FFI function to populate the struct.
        final result = getSystemInfo(sysinfo);
        
        if (result != 0) {
          print('Failed to get system information');
          return;
        }
        
        // Extract system information from the populated struct.
        // `mem_unit` is in bytes, so we need to convert to a human-readable format.
        final unit = sysinfo.ref.mem_unit;
        final totalRamBytes = sysinfo.ref.totalram * unit;
        final freeRamBytes = sysinfo.ref.freeram * unit;
        final usedRamBytes = totalRamBytes - freeRamBytes;
        final totalRamGB = totalRamBytes / (1024 * 1024 * 1024);
        final usedRamGB = usedRamBytes / (1024 * 1024 * 1024);
        final freeRamGB = freeRamBytes / (1024 * 1024 * 1024);
        
        // CPU load is represented as a fixed-point integer; we convert it to a double.
        // Load averages are stored as fixed-point with scale of 1<<16
        final cpuLoad1Min = sysinfo.ref.loads[0] / (1 << 16);
        final cpuLoad5Min = sysinfo.ref.loads[1] / (1 << 16);
        final cpuLoad15Min = sysinfo.ref.loads[2] / (1 << 16);
        
        // Calculate uptime
        final uptimeSeconds = sysinfo.ref.uptime;
        final days = uptimeSeconds ~/ 86400;
        final hours = (uptimeSeconds % 86400) ~/ 3600;
        final minutes = (uptimeSeconds % 3600) ~/ 60;
        
        // Print the formatted output.
        print('-----------------------------------------');
        print('      REAL-TIME SYSTEM MONITOR (FFI)     ');
        print('-----------------------------------------');
        print('Uptime: ${days}d ${hours}h ${minutes}m');
        print('Processes: ${sysinfo.ref.procs}');
        print('-----------------------------------------');
        print('CPU Load Averages:');
        print('  1 min:  ${cpuLoad1Min.toStringAsFixed(2)}');
        print('  5 min:  ${cpuLoad5Min.toStringAsFixed(2)}');
        print('  15 min: ${cpuLoad15Min.toStringAsFixed(2)}');
        print('-----------------------------------------');
        print('RAM Usage:');
        print('  Total: ${totalRamGB.toStringAsFixed(2)} GB');
        print('  Used:  ${usedRamGB.toStringAsFixed(2)} GB');
        print('  Free:  ${freeRamGB.toStringAsFixed(2)} GB');
        print('  Usage: ${(usedRamGB / totalRamGB * 100).toStringAsFixed(1)}%');
        print('-----------------------------------------');
        print('Press Ctrl+C to exit');
        
      } catch (e) {
        print('Error reading system information: $e');
      }
    });
  });
}

