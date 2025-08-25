#define NOB_IMPLEMENTATION
#include "nob.h"

int main(int argc, char **argv) {
    NOB_GO_REBUILD_URSELF(argc, argv);

    // 1️⃣ Ensure "build" directory exists
    if (!nob_mkdir_if_not_exists("build")) {
        nob_log(NOB_ERROR, "Failed to create build directory");
        return 1;
    }

    // 2️⃣ Prepare compile command
    Nob_Cmd cmd = {0};
    nob_cmd_append(&cmd,
        "cc",
        "-Wall", "-Wextra", "-std=c11",
        "-Iinclude",
        "src/main.c", "src/other.c",
        "-o", "build/main"
    );

    // 3️⃣ Run the command
    if (!nob_cmd_run_sync(cmd)) return 1;

    nob_log(NOB_INFO, "Build complete: build/main");
    return 0;
}

