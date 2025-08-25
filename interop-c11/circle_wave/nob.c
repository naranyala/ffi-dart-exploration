#define NOB_IMPLEMENTATION
#include "nob.h"
#include <stdio.h>
#include <string.h>

bool ends_with(const char *str, const char *suffix) {
  if (!str || !suffix)
    return false;
  size_t len_str = strlen(str);
  size_t len_suf = strlen(suffix);
  if (len_suf > len_str)
    return false;
  return strcmp(str + len_str - len_suf, suffix) == 0;
}

int main(int argc, char **argv) {
  const char *build_dir = "build";
  const char *src_dir = "src";
  const char *exe_path = "build/game";

  const char *raylib_include = "../raylib-5.5_linux_amd64/include";
  const char *raylib_lib = "../raylib-5.5_linux_amd64/lib";

  bool use_static = true; // toggle this flag for static/dynamic

  nob_mkdir_if_not_exists(build_dir);

  Nob_File_Paths sources = {0};
  nob_read_entire_dir(src_dir, &sources);

  Nob_Cmd cmd = {0};
  nob_cmd_append(&cmd, "cc");

  nob_cmd_append(&cmd, "-I");
  nob_cmd_append(&cmd, raylib_include);

  for (size_t i = 0; i < sources.count; ++i) {
    if (ends_with(sources.items[i], ".c")) {
      char full_path[512];
      snprintf(full_path, sizeof(full_path), "%s/%s", src_dir,
               sources.items[i]);
      nob_cmd_append(&cmd, full_path);
    }
  }

  nob_cmd_append(&cmd, "-o");
  nob_cmd_append(&cmd, exe_path);

  nob_cmd_append(&cmd, "-L");
  nob_cmd_append(&cmd, raylib_lib);

  if (use_static) {
    nob_cmd_append(&cmd, "-l:libraylib.a"); // static file in raylib/lib
  } else {
    nob_cmd_append(&cmd, "-lraylib"); // dynamic .so/.dylib/.dll
  }

  nob_cmd_append(&cmd, "-lm");
  nob_cmd_append(&cmd, "-ldl");
  nob_cmd_append(&cmd, "-lpthread");
  nob_cmd_append(&cmd, "-lGL");
  nob_cmd_append(&cmd, "-lX11");

  if (!nob_cmd_run_sync(cmd))
    return 1;

  return 0;
}
