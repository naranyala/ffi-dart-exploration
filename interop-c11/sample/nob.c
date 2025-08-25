#define NOB_IMPLEMENTATION
#include "nob.h"

int main(int argc, char **argv) {
    if (!nob_mkdir_if_not_exists("build")) return 1;
    Nob_Cmd cmd = {0};
    nob_cmd_append(&cmd, "cc");
    nob_cmd_append(&cmd, "-Wall", "-Wextra", "-std=c11");
    nob_cmd_append(&cmd, "-Isrc");
    nob_cmd_append(&cmd, "src/main.c");
    nob_cmd_append(&cmd, "-o", "build/app");
    if (!nob_cmd_run_sync(cmd)) return 1;
    nob_log(NOB_INFO, "Build complete: %s", "build/app");
    return 0;
}
