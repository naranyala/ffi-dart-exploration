#define NOB_IMPLEMENTATION

#include "nob.h"

#define BUILD_FOLDER "build/"
#define SRC_FOLDER   "src/"

int main(int argc, char **argv)
{
    NOB_GO_REBUILD_URSELF(argc, argv);
    if (!nob_mkdir_if_not_exists(BUILD_FOLDER)) return 1;

    Nob_Cmd cmd = {0};

#if !defined(_MSC_VER)
    nob_cmd_append(&cmd, "cc", "-Wall", "-Wextra", "-o", BUILD_FOLDER"bluetooth_toggle", SRC_FOLDER"bluetooth_toggle.c");
#else
    nob_cmd_append(&cmd, "cl", "-I.", "-o", BUILD_FOLDER"bluetooth_toggle", SRC_FOLDER"bluetooth_toggle.c");
#endif // _MSC_VER

    if (!nob_cmd_run_sync(cmd)) return 1;
    cmd.count = 0;

    nob_cc(&cmd);
    nob_cc_flags(&cmd);
    nob_cc_output(&cmd, BUILD_FOLDER "bluetooth_toggle");
    nob_cc_inputs(&cmd, SRC_FOLDER "bluetooth_toggle.c");

    if (!nob_cmd_run_sync_and_reset(&cmd)) return 1;

    return 0;
}



