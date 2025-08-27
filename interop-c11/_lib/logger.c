// logger.c — General Logger Utility in C11
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

// ===== Log Levels =====
typedef enum { LOG_DEBUG, LOG_INFO, LOG_WARN, LOG_ERROR } LogLevel;

static const char *LOG_LEVEL_NAMES[] = {"DEBUG", "INFO", "WARN", "ERROR"};

// ===== Logger Interface =====
typedef struct Logger {
  void (*log)(struct Logger *self, LogLevel level, const char *fmt,
              va_list args);
  void (*close)(struct Logger *self);
  void *impl; // implementation-specific data
} Logger;

// ===== Console Logger =====
typedef struct {
  FILE *stream;
} ConsoleLoggerImpl;

static void console_log(Logger *self, LogLevel level, const char *fmt,
                        va_list args) {
  ConsoleLoggerImpl *impl = self->impl;
  time_t now = time(NULL);
  struct tm *t = localtime(&now);
  fprintf(impl->stream, "%02d:%02d:%02d [%s] ", t->tm_hour, t->tm_min,
          t->tm_sec, LOG_LEVEL_NAMES[level]);
  vfprintf(impl->stream, fmt, args);
  fprintf(impl->stream, "\n");
}

static void console_close(Logger *self) {
  (void)self; // nothing to free
}

Logger make_console_logger(FILE *stream) {
  static ConsoleLoggerImpl impl;
  impl.stream = stream;
  Logger logger = {console_log, console_close, &impl};
  return logger;
}

// ===== File Logger =====
typedef struct {
  FILE *fp;
} FileLoggerImpl;

static void file_log(Logger *self, LogLevel level, const char *fmt,
                     va_list args) {
  FileLoggerImpl *impl = self->impl;
  time_t now = time(NULL);
  struct tm *t = localtime(&now);
  fprintf(impl->fp, "%02d:%02d:%02d [%s] ", t->tm_hour, t->tm_min, t->tm_sec,
          LOG_LEVEL_NAMES[level]);
  vfprintf(impl->fp, fmt, args);
  fprintf(impl->fp, "\n");
  fflush(impl->fp);
}

static void file_close(Logger *self) {
  FileLoggerImpl *impl = self->impl;
  if (impl->fp)
    fclose(impl->fp);
}

Logger make_file_logger(const char *filename) {
  static FileLoggerImpl impl;
  impl.fp = fopen(filename, "a");
  if (!impl.fp) {
    perror("Failed to open log file");
    exit(EXIT_FAILURE);
  }
  Logger logger = {file_log, file_close, &impl};
  return logger;
}

// ===== Multi Logger (fan-out) =====
typedef struct {
  Logger *targets;
  size_t count;
} MultiLoggerImpl;

static void multi_log(Logger *self, LogLevel level, const char *fmt,
                      va_list args) {
  MultiLoggerImpl *impl = self->impl;
  for (size_t i = 0; i < impl->count; i++) {
    va_list copy;
    va_copy(copy, args);
    impl->targets[i].log(&impl->targets[i], level, fmt, copy);
    va_end(copy);
  }
}

static void multi_close(Logger *self) {
  MultiLoggerImpl *impl = self->impl;
  for (size_t i = 0; i < impl->count; i++) {
    impl->targets[i].close(&impl->targets[i]);
  }
}

Logger make_multi_logger(Logger *targets, size_t count) {
  static MultiLoggerImpl impl;
  impl.targets = targets;
  impl.count = count;
  Logger logger = {multi_log, multi_close, &impl};
  return logger;
}

// ===== Public Logging API =====
static LogLevel CURRENT_LEVEL = LOG_DEBUG;

void log_set_level(LogLevel level) { CURRENT_LEVEL = level; }

void log_message(Logger *logger, LogLevel level, const char *fmt, ...) {
  if (level < CURRENT_LEVEL)
    return;
  va_list args;
  va_start(args, fmt);
  logger->log(logger, level, fmt, args);
  va_end(args);
}

// ===== Example Usage =====
#ifdef LOGGER_MAIN
int main(void) {
  Logger console = make_console_logger(stdout);
  Logger file = make_file_logger("app.log");

  Logger targets[] = {console, file};
  Logger multi = make_multi_logger(targets, 2);

  log_set_level(LOG_DEBUG);

  log_message(&multi, LOG_INFO, "Application started");
  log_message(&multi, LOG_DEBUG, "Debugging value: %d", 42);
  log_message(&multi, LOG_WARN, "Low disk space");
  log_message(&multi, LOG_ERROR, "Fatal error: %s", "Out of memory");

  multi.close(&multi);
  return 0;
}
#endif
