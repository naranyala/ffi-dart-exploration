// netmon.c - Network Monitor in C11
// Compile with: gcc -std=c11 -o netmon netmon.c

#define _POSIX_C_SOURCE 200809L // For strtok_r, strsignal
#include <arpa/inet.h>
#include <ctype.h>
#include <netinet/in.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <time.h>
#include <unistd.h>

// Configuration
#define MAX_LINE 1024
#define MAX_CMD 512
#define MAX_PROC_NAME 64
#define MAX_CMDLINE 256
#define MAX_PID_STR 16
#define MAX_INTERVAL 3600
#define DEFAULT_INTERVAL 3
#define MAX_CONNECTIONS 4096

// Data structure for a connection
typedef struct {
  char proto[MAX_PROC_NAME];
  char state[MAX_PROC_NAME];
  char local[MAX_PROC_NAME];
  char remote[MAX_PROC_NAME];
  int pid;
  int has_pid;
  char process[MAX_PROC_NAME];
  char cmd[MAX_CMDLINE];
  char cpu[16];
  char mem[16];
} NetConn;

// Global flag for signal handling
volatile sig_atomic_t shutdown_flag = 0;

// Function declarations
void handle_sigint(int sig);
void clear_screen(void);
void print_json(NetConn *conns, int count);
void print_table_with_header(NetConn *conns, int count, time_t timestamp);
int collect_connections(NetConn *conns);
int get_process_details(int pid, char *name, char *cmd, char *cpu, char *mem);
void truncate_str(char *dst, const char *src, int max_len);
int parse_args(int argc, char *argv[], int *json_mode, int *watch,
               int *interval);

// Signal handler for graceful shutdown
void handle_sigint(int sig) {
  shutdown_flag = 1;
  (void)sig;
}

// ANSI clear screen and move cursor to top-left
void clear_screen(void) { printf("\x1B[2J\x1B[0;0H"); }

// Truncate string and add "..."
void truncate_str(char *dst, const char *src, int max_len) {
  if (strlen(src) <= max_len) {
    strcpy(dst, src);
  } else {
    memcpy(dst, src, max_len - 3);
    dst[max_len - 3] = '\0';
    strcat(dst, "...");
  }
}

// Parse command-line arguments
int parse_args(int argc, char *argv[], int *json_mode, int *watch,
               int *interval) {
  *json_mode = 0;
  *watch = 0;
  *interval = DEFAULT_INTERVAL;

  for (int i = 1; i < argc; i++) {
    if (strcmp(argv[i], "--json") == 0) {
      *json_mode = 1;
    } else if (strcmp(argv[i], "--watch") == 0) {
      *watch = 1;
    } else if (strcmp(argv[i], "--interval") == 0) {
      if (i + 1 < argc) {
        int val = atoi(argv[i + 1]);
        if (val > 0 && val <= MAX_INTERVAL) {
          *interval = val;
        }
        i++;
      }
    }
  }

  return 0;
}

// Run ps to get process details
int get_process_details(int pid, char *name, char *cmd, char *cpu, char *mem) {
  char cmd_line[MAX_CMD];
  snprintf(cmd_line, sizeof(cmd_line),
           "ps -p %d -o comm=,cmd=,%%cpu=,%%mem= 2>/dev/null", pid);

  FILE *fp = popen(cmd_line, "r");
  if (!fp)
    return -1;

  char line[MAX_LINE];
  if (fgets(line, sizeof(line), fp)) {
    pclose(fp);

    // Trim newline
    line[strcspn(line, "\n")] = 0;
    if (strlen(line) == 0)
      return -1;

    // Tokenize the line
    char *saveptr;
    char temp_line[MAX_LINE];
    strncpy(temp_line, line, sizeof(temp_line) - 1);
    temp_line[sizeof(temp_line) - 1] = '\0';

    // First token: process name
    char *tok = strtok_r(temp_line, " \t", &saveptr);
    if (!tok)
      return -1;

    strncpy(name, tok, MAX_PROC_NAME - 1);
    name[MAX_PROC_NAME - 1] = '\0';

    // The rest of the line contains cmd, cpu, mem
    char *remaining = line + strlen(tok);
    while (*remaining == ' ' || *remaining == '\t')
      remaining++;

    // Find the last two numbers (cpu and mem)
    char *last_space = strrchr(remaining, ' ');
    if (!last_space)
      return -1;

    char *prev_space = last_space;
    while (prev_space > remaining && *prev_space == ' ')
      prev_space--;
    while (prev_space > remaining && *prev_space != ' ')
      prev_space--;

    if (prev_space <= remaining)
      return -1;

    // Extract CPU and MEM
    char *cpu_start = prev_space + 1;
    while (*cpu_start == ' ')
      cpu_start++;

    char *mem_start = last_space + 1;
    while (*mem_start == ' ')
      mem_start++;

    // Copy CPU and MEM
    strncpy(cpu, cpu_start, sizeof(cpu) - 1);
    cpu[sizeof(cpu) - 1] = '\0';

    char *cpu_end = strchr(cpu, ' ');
    if (cpu_end)
      *cpu_end = '\0';

    strncpy(mem, mem_start, sizeof(mem) - 1);
    mem[sizeof(mem) - 1] = '\0';

    // Extract command (everything between process name and cpu)
    *prev_space = '\0';
    strncpy(cmd, remaining, MAX_CMDLINE - 1);
    cmd[MAX_CMDLINE - 1] = '\0';

    return 0;
  }

  pclose(fp);
  return -1;
}

// Collect all connections using `ss -tupa`
int collect_connections(NetConn *conns) {
  FILE *fp = popen("ss -tupa 2>/dev/null", "r");
  if (!fp) {
    fprintf(stderr, "Failed to run 'ss'\n");
    return -1;
  }

  char line[MAX_LINE];
  int idx = 0;

  // Skip header
  if (fgets(line, sizeof(line), fp) == NULL) {
    pclose(fp);
    return 0;
  }

  while (fgets(line, sizeof(line), fp) && idx < MAX_CONNECTIONS) {
    char *saveptr;
    char temp_line[MAX_LINE];
    strncpy(temp_line, line, sizeof(temp_line) - 1);
    temp_line[sizeof(temp_line) - 1] = '\0';

    char *parts[20];
    int part_count = 0;
    char *tok = strtok_r(temp_line, " \t\n", &saveptr);
    while (tok && part_count < 20) {
      parts[part_count++] = tok;
      tok = strtok_r(NULL, " \t\n", &saveptr);
    }

    if (part_count < 6)
      continue;

    NetConn *c = &conns[idx];
    strncpy(c->proto, parts[0], MAX_PROC_NAME - 1);
    c->proto[MAX_PROC_NAME - 1] = '\0';

    strncpy(c->state, parts[1], MAX_PROC_NAME - 1);
    c->state[MAX_PROC_NAME - 1] = '\0';

    strncpy(c->local, parts[4], MAX_PROC_NAME - 1);
    c->local[MAX_PROC_NAME - 1] = '\0';

    strncpy(c->remote, parts[5], MAX_PROC_NAME - 1);
    c->remote[MAX_PROC_NAME - 1] = '\0';

    c->has_pid = 0;
    strcpy(c->process, "-");
    strcpy(c->cmd, "-");
    strcpy(c->cpu, "-");
    strcpy(c->mem, "-");

    // Parse users section (parts from 6 onward)
    if (part_count > 6) {
      char users[MAX_LINE] = {0};
      for (int i = 6; i < part_count; i++) {
        if (strlen(users) + strlen(parts[i]) + 1 < MAX_LINE) {
          strcat(users, parts[i]);
          if (i < part_count - 1)
            strcat(users, " ");
        }
      }

      // Extract pid=XXXX
      char *pid_str = strstr(users, "pid=");
      if (pid_str) {
        pid_str += 4;
        char *end = pid_str;
        while (isdigit(*end))
          end++;
        char num[MAX_PID_STR];
        int len = end - pid_str;
        if (len > 0 && len < MAX_PID_STR) {
          memcpy(num, pid_str, len);
          num[len] = '\0';
          c->pid = atoi(num);
          c->has_pid = 1;

          // Get process details
          if (get_process_details(c->pid, c->process, c->cmd, c->cpu, c->mem) !=
              0) {
            strcpy(c->process, "???");
            strcpy(c->cmd, "???");
          }
        }
      }
    }

    idx++;
  }

  pclose(fp);
  return idx;
}

// Print JSON output
void print_json(NetConn *conns, int count) {
  printf("[\n");
  for (int i = 0; i < count; i++) {
    NetConn *c = &conns[i];
    printf("  {\n");
    printf("    \"proto\": \"%s\",\n", c->proto);
    printf("    \"state\": \"%s\",\n", c->state);
    printf("    \"local\": \"%s\",\n", c->local);
    printf("    \"remote\": \"%s\",\n", c->remote);
    if (c->has_pid) {
      printf("    \"pid\": %d,\n", c->pid);
      printf("    \"process\": \"%s\",\n", c->process);
      printf("    \"cmd\": \"%s\",\n", c->cmd);
      printf("    \"cpu\": \"%s\",\n", c->cpu);
      printf("    \"mem\": \"%s\"\n", c->mem);
    } else {
      printf("    \"pid\": null,\n");
      printf("    \"process\": null,\n");
      printf("    \"cmd\": null,\n");
      printf("    \"cpu\": null,\n");
      printf("    \"mem\": null\n");
    }
    printf("  }%s\n", i == count - 1 ? "" : ",");
  }
  printf("]\n");
}

// Print table with header
void print_table_with_header(NetConn *conns, int count, time_t timestamp) {
  struct tm *tm_info = localtime(&timestamp);
  char time_str[20];
  strftime(time_str, sizeof(time_str), "%Y-%m-%d %H:%M:%S", tm_info);

  int active = 0, listening = 0;
  for (int i = 0; i < count; i++) {
    if (strcmp(conns[i].state, "ESTAB") == 0)
      active++;
    if (strcmp(conns[i].state, "LISTEN") == 0)
      listening++;
  }

  printf("Last updated: %s\n", time_str);
  printf("Total connections: %d (%d active, %d listening)\n", count, active,
         listening);
  printf("%s\n", "-------------------------------------------------------------"
                 "-------------------");

  // Header
  printf("%-8s | %-5s | %-15s | %-8s | %-25s | %-25s | %-5s | %-5s\n", "Proto",
         "PID", "Process", "State", "Local", "Remote", "CPU%", "MEM%");
  printf("%s\n", "--------+-------+-----------------+----------+---------------"
                 "------------+---------------------------+-------+------");

  // Rows
  for (int i = 0; i < count; i++) {
    NetConn *c = &conns[i];
    char proc_trunc[16], local_trunc[26], remote_trunc[26];
    truncate_str(proc_trunc, c->process, 15);
    truncate_str(local_trunc, c->local, 25);
    truncate_str(remote_trunc, c->remote, 25);

    char pid_str[6];
    if (c->has_pid) {
      snprintf(pid_str, sizeof(pid_str), "%d", c->pid);
    } else {
      strcpy(pid_str, "-");
    }

    printf("%-8s | %-5s | %-15s | %-8s | %-25s | %-25s | %-5s | %-5s\n",
           c->proto, pid_str, proc_trunc, c->state, local_trunc, remote_trunc,
           c->cpu, c->mem);
  }
}

// Main function
int main(int argc, char *argv[]) {
  int json_mode = 0;
  int watch = 0;
  int interval = DEFAULT_INTERVAL;

  parse_args(argc, argv, &json_mode, &watch, &interval);

  signal(SIGINT, handle_sigint);

  NetConn connections[MAX_CONNECTIONS];
  int count;

  if (watch) {
    clear_screen();
    if (!json_mode) {
      printf("Network Monitor - Press Ctrl+C to exit\n");
      printf("Update interval: %ds\n\n", interval);
    }

    // Initial run
    count = collect_connections(connections);
    if (count < 0) {
      fprintf(stderr, "Failed to collect connections.\n");
      return 1;
    }

    if (json_mode) {
      print_json(connections, count);
    } else {
      print_table_with_header(connections, count, time(NULL));
    }

    // Watch loop
    while (!shutdown_flag) {
      sleep(interval);
      if (shutdown_flag)
        break;

      clear_screen();
      count = collect_connections(connections);
      if (count < 0)
        continue;

      if (json_mode) {
        print_json(connections, count);
      } else {
        printf("Network Monitor - Press Ctrl+C to exit\n");
        printf("Update interval: %ds\n\n", interval);
        print_table_with_header(connections, count, time(NULL));
      }
    }

    printf("\n\nShutting down gracefully...\n");
  } else {
    count = collect_connections(connections);
    if (count < 0) {
      fprintf(stderr, "Failed to collect connections.\n");
      return 1;
    }

    if (json_mode) {
      print_json(connections, count);
    } else {
      print_table_with_header(connections, count, time(NULL));
    }
  }

  return 0;
}
