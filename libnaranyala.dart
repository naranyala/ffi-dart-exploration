import 'dart:ffi' as ffi;
import 'dart:io' show Platform;

ffi.DynamicLibrary _openLibrary() {
  // if (Platform.isMacOS) return ffi.DynamicLibrary.open('libnative_add.dylib');
  if (Platform.isLinux) return ffi.DynamicLibrary.open('./lib_rust/target/release/libnaranyala.so');
  // if (Platform.isWindows) return ffi.DynamicLibrary.open('native_add.dll');
  throw UnsupportedError('Unsupported platform');
}

final _lib = _openLibrary();

typedef CAddFunc = ffi.Int32 Function(ffi.Int32, ffi.Int32);
typedef DartAddFunc = int Function(int, int);

typedef CHelloFunc = void Function();
typedef DartHelloFunc = void Function();

final addIntegers = _lib
    .lookup<ffi.NativeFunction<CAddFunc>>('add_integers')
    .asFunction<DartAddFunc>();

final sayHello = _lib
    .lookup<ffi.NativeFunction<CHelloFunc>>('say_hello');

