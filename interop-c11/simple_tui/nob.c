#define NOB_IMPLEMENTATION
#include "nob.h"

int main(int argc, char **argv) {
  // Ensure build directory exists
  if (!nob_mkdir_if_not_exists("build")) {
    nob_log(NOB_ERROR, "Failed to create build directory");
    return 1;
  }

  Nob_Cmd cmd = {0};

  // Output binary inside build/
  const char *output = "build/tui_app";

  nob_cmd_append(&cmd, "cc");
  nob_cmd_append(&cmd, "-Wall", "-Wextra", "-std=c11");
  nob_cmd_append(&cmd, "-Isrc");
  nob_cmd_append(&cmd, "src/main.c");
  nob_cmd_append(&cmd, "-o", output);
  nob_cmd_append(&cmd, "-lncurses");

  if (!nob_cmd_run_sync(cmd))
    return 1;

  nob_log(NOB_INFO, "Build complete: %s", output);
  return 0;
}
