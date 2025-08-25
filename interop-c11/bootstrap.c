// gcc bootstrap.c -o bootstrap && ./bootstrap --project-path ./sample

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

static void download_nob_h(const char *dest) {
  if (file_exists(dest)) {
    printf("nob.h already exists, skipping download.\n");
    return;
  }
  char cmd[2048];
  printf("Downloading nob.h...\n");
  snprintf(
      cmd, sizeof(cmd),
      "curl -fsSL https://raw.githubusercontent.com/tsoding/nob.h/master/nob.h "
      "-o \"%s\"",
      dest);
  if (system(cmd) != 0) {
    snprintf(
        cmd, sizeof(cmd),
        "wget -q https://raw.githubusercontent.com/tsoding/nob.h/master/nob.h "
        "-O \"%s\"",
        dest);
    if (system(cmd) != 0) {
      fprintf(stderr, "Failed to download nob.h (curl/wget not found?)\n");
    }
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

  // Create src/ and build/ inside project
  char src_path[1024], build_path[1024], nobh_path[1024], nobc_path[1024],
      mainc_path[1024];
  snprintf(src_path, sizeof(src_path), "%s/src", project_path);
  snprintf(build_path, sizeof(build_path), "%s/build", project_path);
  snprintf(nobh_path, sizeof(nobh_path), "%s/nob.h", project_path);
  snprintf(nobc_path, sizeof(nobc_path), "%s/nob.c", project_path);
  snprintf(mainc_path, sizeof(mainc_path), "%s/src/main.c", project_path);

  if (!make_dir_recursive(src_path))
    return 1;
  if (!make_dir_recursive(build_path))
    return 1;

  // Download nob.h
  download_nob_h(nobh_path);

  // Create starter main.c
  if (!file_exists(mainc_path)) {
    const char *starter_code = "#include <stdio.h>\n\n"
                               "int main(void) {\n"
                               "    printf(\"Hello, world!\\\\n\");\n"
                               "    return 0;\n"
                               "}\n";
    if (!write_file(mainc_path, starter_code))
      return 1;
  }

  // Create minimal nob.c
  if (!file_exists(nobc_path)) {
    char nob_code[2048];
    snprintf(nob_code, sizeof(nob_code),
             "#define NOB_IMPLEMENTATION\n"
             "#include \"nob.h\"\n\n"
             "int main(int argc, char **argv) {\n"
             "    if (!nob_mkdir_if_not_exists(\"build\")) return 1;\n"
             "    Nob_Cmd cmd = {0};\n"
             "    nob_cmd_append(&cmd, \"cc\");\n"
             "    nob_cmd_append(&cmd, \"-Wall\", \"-Wextra\", \"-std=c11\");\n"
             "    nob_cmd_append(&cmd, \"-Isrc\");\n"
             "    nob_cmd_append(&cmd, \"src/main.c\");\n"
             "    nob_cmd_append(&cmd, \"-o\", \"build/app\");\n"
             "    if (!nob_cmd_run_sync(cmd)) return 1;\n"
             "    nob_log(NOB_INFO, \"Build complete: %%s\", \"build/app\");\n"
             "    return 0;\n"
             "}\n");
    if (!write_file(nobc_path, nob_code))
      return 1;
  }

  printf("Bootstrap complete at: %s\n", project_path);
  printf("Next steps:\n");
  printf("  cd %s\n", project_path);
  printf("  cc nob.c -o nob\n");
  printf("  ./nob\n");
  printf("  ./build/app\n");
  return 0;
}
