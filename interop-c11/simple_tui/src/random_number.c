#include <stdio.h>
#include <stdlib.h>
#include <time.h>

// Function to generate a random integer in a specified range
int generateRandomNumber(int min, int max) {
  // A better way to get a random number in a range is to use:
  // (rand() % (max - min + 1)) + min
  return (rand() % (max - min + 1)) + min;
}

int main() {
  // Seed the random number generator using the current time.
  // This should only be called once at the start of your program.
  srand(time(NULL));

  int min = 1;
  int max = 100;
  int count = 5;

  printf("Generating %d random numbers between %d and %d:\n", count, min, max);

  for (int i = 0; i < count; i++) {
    int randomNumber = generateRandomNumber(min, max);
    printf("%d\n", randomNumber);
  }

  return 0;
}
