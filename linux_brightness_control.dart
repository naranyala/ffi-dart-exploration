// main.dart

import 'dart:io';

/// @file main.dart
/// @brief A command-line interface application for controlling screen brightness on Linux.
///
/// This application attempts to use 'brightnessctl' first, and falls back to 'xrandr'
/// if the former is not available. It's designed to be simple and easy to use.
///
/// @author Gemini
/// @date 2025-08-22

/// @brief Runs a command with the given arguments and returns the result.
///
/// @param executable The name of the executable to run.
/// @param arguments A list of string arguments for the executable.
/// @param isSilent A boolean to suppress output for simple checks.
/// @return A `ProcessResult` object.
/// @note This function is synchronous and will block until the process completes.
ProcessResult runCommand(String executable, List<String> arguments, {bool isSilent = false}) {
  try {
    if (!isSilent) {
      print('\n> Running command: $executable ${arguments.join(' ')}\n');
    }
    return Process.runSync(executable, arguments);
  } catch (e) {
    if (!isSilent) {
      print('Error: Could not execute command "$executable". Does it exist in your PATH?');
    }
    return ProcessResult(-1, 2, '', 'Command not found.');
  }
}

/// @brief Checks if a specific command-line executable exists.
///
/// @param executable The name of the executable.
/// @return `true` if the executable exists and is runnable, `false` otherwise.
bool checkExecutable(String executable) {
  final result = runCommand('which', [executable], isSilent: true);
  return result.exitCode == 0;
}

/// @brief Gets the primary display device name using brightnessctl.
///
/// @return The device name as a String, or `null` if not found.
String? getBrightnessctlDevice() {
  final result = runCommand('brightnessctl', ['-l']);
  if (result.exitCode != 0) {
    return null;
  }
  
  // The output of `brightnessctl -l` is often the first device.
  final lines = (result.stdout as String).trim().split('\n');
  if (lines.isEmpty) {
    print('Error: No brightness devices found with brightnessctl.');
    return null;
  }

  // The first device listed is typically the main one.
  final firstDeviceMatch = RegExp(r"Device '(.+?)'").firstMatch(lines.first);
  return firstDeviceMatch?.group(1);
}

/// @brief Gets the active display output name using xrandr.
///
/// @return The display name (e.g., 'eDP-1', 'HDMI-1'), or `null` if not found.
String? getXrandrDisplay() {
  final result = runCommand('xrandr', ['-q']);
  if (result.exitCode != 0) {
    return null;
  }

  final lines = (result.stdout as String).trim().split('\n');
  for (final line in lines) {
    // Look for a line containing "connected" to find an active display.
    if (line.contains(' connected')) {
      final parts = line.split(' ');
      if (parts.isNotEmpty) {
        return parts.first;
      }
    }
  }
  return null;
}

/// @brief Sets the brightness using the brightnessctl utility.
///
/// @param device The device name to control.
/// @param value The desired brightness value (e.g., "50%", "100").
void setBrightnessctl(String device, String value) {
  final result = runCommand('brightnessctl', ['-d', device, 'set', value]);
  if (result.exitCode == 0) {
    print('\nSuccessfully set brightness to $value on device $device.');
  } else {
    print('\nFailed to set brightness with brightnessctl.');
    print('Error: ${result.stderr}');
  }
}

/// @brief Sets the brightness using the xrandr utility.
///
/// @param display The display name to control.
/// @param value The desired brightness value (e.g., "0.5", "1.0").
void setXrandrBrightness(String display, String value) {
  final result = runCommand('xrandr', ['--output', display, '--brightness', value]);
  if (result.exitCode == 0) {
    print('\nSuccessfully set brightness to $value on display $display.');
  } else {
    print('\nFailed to set brightness with xrandr.');
    print('Error: ${result.stderr}');
  }
}

/// @brief The main entry point of the application.
///
/// @param arguments A list of command-line arguments.
void main(List<String> arguments) async {
  if (arguments.length != 1) {
    print('Usage: dart run main.dart <value>');
    print('  <value> can be a percentage (e.g., "50%") or an absolute value (e.g., "100").');
    print('  When using xrandr, the value should be between 0.0 and 1.0 (e.g., "0.5").');
    exit(1);
  }

  final brightnessValue = arguments[0];
  
  // Attempt to use `brightnessctl` first.
  if (checkExecutable('brightnessctl')) {
    final device = getBrightnessctlDevice();
    if (device != null) {
      setBrightnessctl(device, brightnessValue);
    } else {
      print('Could not find a valid brightnessctl device.');
      print('Falling back to xrandr...');
      
      final display = getXrandrDisplay();
      if (display != null) {
        setXrandrBrightness(display, brightnessValue);
      } else {
        print('Could not find a valid xrandr display to set brightness.');
        exit(1);
      }
    }
  } 
  // If brightnessctl is not available, try `xrandr` as a fallback.
  else if (checkExecutable('xrandr')) {
    final display = getXrandrDisplay();
    if (display != null) {
      setXrandrBrightness(display, brightnessValue);
    } else {
      print('Could not find a valid xrandr display to set brightness.');
      exit(1);
    }
  } 
  // If neither is available, inform the user.
  else {
    print('Error: Neither `brightnessctl` nor `xrandr` was found in your system.');
    print('Please install one of these utilities to control brightness from the command line.');
    exit(1);
  }
}

