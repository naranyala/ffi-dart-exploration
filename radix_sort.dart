import 'dart:io';
import 'dart:math';

void main(List<String> arguments) {
  List<int> numbers;

  if (arguments.isEmpty) {
    // Built-in demo sample
    numbers = [170, 45, 75, 90, 802, 24, 2, 66];
    stdout.writeln('No CLI arguments provided. Using demo sample: $numbers');
  } else {
    try {
      numbers = arguments.map(int.parse).toList();
    } catch (e) {
      stderr.writeln('Error: All arguments must be integers.');
      exit(1);
    }
  }

  stdout.writeln('Original list: $numbers');

  radixSort(numbers);

  stdout.writeln('Sorted list:   $numbers');
}

void radixSort(List<int> list) {
  if (list.isEmpty) return;

  int maxNumber = list.reduce(max);
  int exp = 1; // 1, 10, 100, ...

  while (maxNumber ~/ exp > 0) {
    _countingSortByDigit(list, exp);
    exp *= 10;
  }
}

void _countingSortByDigit(List<int> list, int exp) {
  int n = list.length;
  List<int> output = List.filled(n, 0);
  List<int> count = List.filled(10, 0);

  // Count occurrences of each digit
  for (int i = 0; i < n; i++) {
    int digit = (list[i] ~/ exp) % 10;
    count[digit]++;
  }

  // Convert count to prefix sum for stable sort
  for (int i = 1; i < 10; i++) {
    count[i] += count[i - 1];
  }

  // Build output array (stable)
  for (int i = n - 1; i >= 0; i--) {
    int digit = (list[i] ~/ exp) % 10;
    output[count[digit] - 1] = list[i];
    count[digit]--;
  }

  // Copy back to original list
  for (int i = 0; i < n; i++) {
    list[i] = output[i];
  }
}

