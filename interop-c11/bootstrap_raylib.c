#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

#ifdef _WIN32
#include <direct.h>
#define MKDIR(path) _mkdir(path)
#else
#include <unistd.h>
#define MKDIR(path) mkdir(path, 0755)
#endif

static int make_dir_recursive(const char *path) {
  char tmp[1024];
  snprintf(tmp, sizeof(tmp), "%s", path);
  size_t len = strlen(tmp);
  if (tmp[len - 1] == '/' || tmp[len - 1] == '\\')
    tmp[len - 1] = '\0';

  for (char *p = tmp + 1; *p; p++) {
    if (*p == '/' || *p == '\\') {
      *p = '\0';
      if (MKDIR(tmp) != 0 && errno != EEXIST) {
        perror("mkdir");
        return 0;
      }
      *p = '/';
    }
  }
  if (MKDIR(tmp) != 0 && errno != EEXIST) {
    perror("mkdir");
    return 0;
  }
  return 1;
}

static int file_exists(const char *path) {
  FILE *f = fopen(path, "r");
  if (f) {
    fclose(f);
    return 1;
  }
  return 0;
}

static int write_file(const char *path, const char *content) {
  FILE *f = fopen(path, "w");
  if (!f) {
    perror("fopen");
    return 0;
  }
  fwrite(content, 1, strlen(content), f);
  fclose(f);
  printf("Created file: %s\n", path);
  return 1;
}

static void download_file(const char *url, const char *dest) {
  char cmd[2048];
  snprintf(cmd, sizeof(cmd), "curl -fsSL \"%s\" -o \"%s\"", url, dest);
  if (system(cmd) != 0) {
    snprintf(cmd, sizeof(cmd), "wget -q \"%s\" -O \"%s\"", url, dest);
    if (system(cmd) != 0) {
      fprintf(stderr, "Failed to download %s\n", url);
    }
  }
}

static void download_nob_h(const char *dest) {
  if (file_exists(dest)) {
    printf("nob.h already exists, skipping download.\n");
    return;
  }
  printf("Downloading nob.h...\n");
  download_file("https://raw.githubusercontent.com/tsoding/nob.h/master/nob.h",
                dest);
}

static void download_raylib_linux(const char *dest_dir) {
  char tar_path[1024];
  snprintf(tar_path, sizeof(tar_path), "%s/raylib.tar.gz", dest_dir);
  printf("Downloading Raylib 5.5 Linux AMD64...\n");
  download_file("https://github.com/raysan5/raylib/releases/download/5.5/"
                "raylib-5.5_linux_amd64.tar.gz",
                tar_path);

  char cmd[2048];
  snprintf(cmd, sizeof(cmd), "tar -xzf \"%s\" -C \"%s\" && rm \"%s\"", tar_path,
           dest_dir, tar_path);
  if (system(cmd) != 0) {
    fprintf(stderr, "Failed to extract Raylib archive.\n");
  } else {
    printf("Raylib extracted to %s\n", dest_dir);
  }
}

int main(int argc, char **argv) {
  if (argc != 3 || strcmp(argv[1], "--project-path") != 0) {
    fprintf(stderr, "Usage: %s --project-path <path>\n", argv[0]);
    return 1;
  }

  const char *project_path = argv[2];

  // Create project root
  if (!make_dir_recursive(project_path))
    return 1;

  // Paths
  char src_path[1024], build_path[1024], nobh_path[1024], nobc_path[1024],
      mainc_path[1024];
  snprintf(src_path, sizeof(src_path), "%s/src", project_path);
  snprintf(build_path, sizeof(build_path), "%s/build", project_path);
  snprintf(nobh_path, sizeof(nobh_path), "%s/nob.h", project_path);
  snprintf(nobc_path, sizeof(nobc_path), "%s/nob.c", project_path);
  snprintf(mainc_path, sizeof(mainc_path), "%s/src/main.c", project_path);

  // Create dirs
  if (!make_dir_recursive(src_path))
    return 1;
  if (!make_dir_recursive(build_path))
    return 1;

  // Download nob.h
  download_nob_h(nobh_path);

  // Download Raylib binaries
  download_raylib_linux(project_path);

  // Starter Raylib main.c
  if (!file_exists(mainc_path)) {
    const char *starter_code =
        "#include \"raylib.h\"\n\n"
        "int main(void) {\n"
        "    InitWindow(800, 450, \"Raylib Starter\");\n"
        "    SetTargetFPS(60);\n"
        "    while (!WindowShouldClose()) {\n"
        "        BeginDrawing();\n"
        "        ClearBackground(RAYWHITE);\n"
        "        DrawText(\"Hello, Raylib!\", 350, 200, 20, LIGHTGRAY);\n"
        "        EndDrawing();\n"
        "    }\n"
        "    CloseWindow();\n"
        "    return 0;\n"
        "}\n";
    if (!write_file(mainc_path, starter_code))
      return 1;
  }

  // nob.c with Raylib build config (no nob_ends_with / nob_cmd_appendf)
  if (!file_exists(nobc_path)) {
    const char *nob_code =
        "#define NOB_IMPLEMENTATION\n"
        "#include \"nob.h\"\n"
        "#include <stdio.h>\n"
        "#include <string.h>\n"
        "\n"
        "bool ends_with(const char *str, const char *suffix) {\n"
        "  if (!str || !suffix)\n"
        "    return false;\n"
        "  size_t len_str = strlen(str);\n"
        "  size_t len_suf = strlen(suffix);\n"
        "  if (len_suf > len_str)\n"
        "    return false;\n"
        "  return strcmp(str + len_str - len_suf, suffix) == 0;\n"
        "}\n"
        "\n"
        "int main(int argc, char **argv) {\n"
        "  const char *build_dir = \"build\";\n"
        "  const char *src_dir = \"src\";\n"
        "  const char *exe_path = \"build/game\";\n"
        "\n"
        "  const char *raylib_include = \"raylib-5.5_linux_amd64/include\";\n"
        "  const char *raylib_lib = \"raylib-5.5_linux_amd64/lib\";\n"
        "\n"
        "  bool use_static = true; // toggle this flag for static/dynamic\n"
        "\n"
        "  nob_mkdir_if_not_exists(build_dir);\n"
        "\n"
        "  Nob_File_Paths sources = {0};\n"
        "  nob_read_entire_dir(src_dir, &sources);\n"
        "\n"
        "  Nob_Cmd cmd = {0};\n"
        "  nob_cmd_append(&cmd, \"cc\");\n"
        "\n"
        "  nob_cmd_append(&cmd, \"-I\");\n"
        "  nob_cmd_append(&cmd, raylib_include);\n"
        "\n"
        "  for (size_t i = 0; i < sources.count; ++i) {\n"
        "    if (ends_with(sources.items[i], \".c\")) {\n"
        "      char full_path[512];\n"
        "      snprintf(full_path, sizeof(full_path), \"%s/%s\", src_dir,\n"
        "               sources.items[i]);\n"
        "      nob_cmd_append(&cmd, full_path);\n"
        "    }\n"
        "  }\n"
        "\n"
        "  nob_cmd_append(&cmd, \"-o\");\n"
        "  nob_cmd_append(&cmd, exe_path);\n"
        "\n"
        "  nob_cmd_append(&cmd, \"-L\");\n"
        "  nob_cmd_append(&cmd, raylib_lib);\n"
        "\n"
        "  if (use_static) {\n"
        "    nob_cmd_append(&cmd, \"-l:libraylib.a\"); // static file in "
        "raylib/lib\n"
        "  } else {\n"
        "    nob_cmd_append(&cmd, \"-lraylib\"); // dynamic .so/.dylib/.dll \n"
        "  }\n"
        "\n"
        "  nob_cmd_append(&cmd, \"-lm\");\n"
        "  nob_cmd_append(&cmd, \"-ldl\");\n"
        "  nob_cmd_append(&cmd, \"-lpthread\");\n"
        "  nob_cmd_append(&cmd, \"-lGL\");\n"
        "  nob_cmd_append(&cmd, \"-lX11\");\n"
        "\n"
        "  if (!nob_cmd_run_sync(cmd))\n"
        "    return 1;\n"
        "\n"
        "  return 0;\n"
        "}\n";

    if (!write_file(nobc_path, nob_code))
      return 1;
  }

  printf("Raylib project bootstrap complete at: %s\n", project_path);
  printf("Next steps:\n");
  printf("  cd %s\n", project_path);
  printf("  cc nob.c -o nob\n");
  printf("  ./nob\n");
  printf("  ./build/game\n");
  return 0;
}
