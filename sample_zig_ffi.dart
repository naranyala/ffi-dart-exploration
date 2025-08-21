import 'zig_bindings.dart';

void main() {
  print('3 + 4 = ${add(3, 4)}');

  final msgPtr = greet();
  final msg = msgPtr.toDartString(); // from package:ffi/ffi.dart
  print(msg);
}

