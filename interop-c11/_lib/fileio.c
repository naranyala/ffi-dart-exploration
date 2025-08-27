// fileio.c
#include "fileio.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

char *file_read_text(const char *path) {
  FILE *f = fopen(path, "rb");
  if (!f)
    return NULL;

  fseek(f, 0, SEEK_END);
  long len = ftell(f);
  rewind(f);

  char *buffer = malloc(len + 1);
  if (!buffer) {
    fclose(f);
    return NULL;
  }

  size_t read_len = fread(buffer, 1, len, f);
  buffer[read_len] = '\0';
  fclose(f);

  return buffer;
}

int file_write_text(const char *path, const char *text) {
  FILE *f = fopen(path, "wb");
  if (!f)
    return 1; // error

  size_t len = strlen(text);
  size_t written = fwrite(text, 1, len, f);
  fclose(f);

  return (written == len) ? 0 : 2; // 0 success, 2 partial write
}
