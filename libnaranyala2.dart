import 'dart:ffi' as ffi;
import 'dart:io' show Platform;

// DynamicLibrary loader
ffi.DynamicLibrary _openLib() {
  // if (Platform.isMacOS) return ffi.DynamicLibrary.open('libnative_add.dylib');
  if (Platform.isLinux) return ffi.DynamicLibrary.open('./lib_rust/target/release/libnaranyala.so');
  // if (Platform.isWindows) return ffi.DynamicLibrary.open('native_add.dll');
  throw UnsupportedError('This platform is not supported.');
}

final ffi.DynamicLibrary _lib = _openLib();

// Common typedefs
typedef CBinaryOp    = ffi.Int32 Function(ffi.Int32, ffi.Int32);
typedef DartBinaryOp = int Function(int, int);

// Lookup each function
final DartBinaryOp add       = _lib.lookup<ffi.NativeFunction<CBinaryOp>>('add_integers').asFunction();
final DartBinaryOp subtract  = _lib.lookup<ffi.NativeFunction<CBinaryOp>>('subtract_integers').asFunction();
final DartBinaryOp multiply  = _lib.lookup<ffi.NativeFunction<CBinaryOp>>('multiply_integers').asFunction();
final DartBinaryOp divide    = _lib.lookup<ffi.NativeFunction<CBinaryOp>>('divide_integers').asFunction();

