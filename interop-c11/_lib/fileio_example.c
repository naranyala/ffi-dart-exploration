#include "fileio.h"
#include <stdio.h>
#include <stdlib.h>

int main() {
  char *data = file_read_text("input.txt");
  if (data) {
    printf("File content: %s\n", data);
    free(data);
  } else {
    printf("Failed to read file.\n");
  }

  if (file_write_text("output.txt", "Hello Kotlin-inspired C11!") == 0) {
    printf("File written successfully.\n");
  } else {
    printf("Failed to write file.\n");
  }

  return 0;
}
