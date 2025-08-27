// fileio.h
#ifndef FILEIO_H
#define FILEIO_H

#include <errno.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Result type inspired by Kotlin's Result<T>
typedef struct {
  void *value;
  char *error;
  bool is_success;
} Result;

// File operations result
typedef Result FileResult;

// File reading options
typedef struct {
  bool trim_whitespace;
  bool ignore_empty_lines;
  char *encoding;
} ReadOptions;

// Default read options
#define DEFAULT_READ_OPTIONS                                                   \
  {.trim_whitespace = false, .ignore_empty_lines = false, .encoding = "UTF-8"}

// Function prototypes
FileResult read_file(const char *filename);
FileResult read_file_with_options(const char *filename, ReadOptions options);
FileResult read_lines(const char *filename);
FileResult read_lines_with_options(const char *filename, ReadOptions options);

bool write_file(const char *filename, const char *content);
bool append_file(const char *filename, const char *content);

bool file_exists(const char *filename);
bool is_directory(const char *path);
long file_size(const char *filename);

void free_result(Result result);
char *result_to_string(Result result);

// Utility macros for cleaner usage
#define SUCCESS(value)                                                         \
  ((Result){.value = value, .error = NULL, .is_success = true})
#define FAILURE(error_msg)                                                     \
  ((Result){.value = NULL, .error = error_msg, .is_success = false})

#define RESULT_GET(value_type, result) ((value_type)(result).value)
#define RESULT_ON_SUCCESS(result, block)                                       \
  if ((result).is_success) {                                                   \
    block;                                                                     \
  }
#define RESULT_ON_FAILURE(result, block)                                       \
  if (!(result).is_success) {                                                  \
    block;                                                                     \
  }

#endif
