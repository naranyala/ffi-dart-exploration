// zig_bindings.dart
import 'dart:ffi';
import 'dart:io';

final dylib = DynamicLibrary.open(
  Platform.isWindows ? './lib_zig/libmain.dll' :
  Platform.isMacOS   ? './lib_zig/libmain.dylib' :
                       './lib_zig/libmain.so',
);

import 'dart:ffi';
import 'dart:io';

// Resolve library name per platform
DynamicLibrary _openLib() {
  if (Platform.isMacOS) return DynamicLibrary.open('./lib_zig/libmain.dylib');
  if (Platform.isLinux) return DynamicLibrary.open('./lib_zig/libmain.so');
  if (Platform.isWindows) return DynamicLibrary.open('./lib_zig/libmain.dll');
  throw UnsupportedError('Unsupported platform');
}

final dylib = _openLib();

// C signatures
typedef c_add = Int32 Function(Int32, Int32);
typedef c_greet = Pointer<Utf8> Function();

// Dart signatures
typedef dart_add = int Function(int, int);
typedef dart_greet = Pointer<Utf8> Function();

// Lookups
final add = dylib.lookupFunction<c_add, dart_add>('add');
final greet = dylib.lookupFunction<c_greet, dart_greet>('greet');

