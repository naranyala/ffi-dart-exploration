#include <arpa/inet.h>
#include <ncurses.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

typedef struct {
  char proto[5];
  char laddr[64];
  char raddr[64];
  char country[8];
  char asn[16];
  int latency;
  char state[8];
} Conn;

void hex_to_ip_port(const char *hex_ip, const char *hex_port, char *ip_str,
                    int *port) {
  unsigned int ip;
  sscanf(hex_ip, "%x", &ip);
  struct in_addr in;
  in.s_addr = htonl(ip);
  strcpy(ip_str, inet_ntoa(in));

  unsigned int p;
  sscanf(hex_port, "%x", &p);
  *port = p;
}

void enrich_data(Conn *c) {
  // Simple country detection based on IP patterns
  if (strncmp(c->raddr, "127.", 4) == 0 || strcmp(c->raddr, "0.0.0.0") == 0) {
    strcpy(c->country, "LOCAL");
  } else if (strncmp(c->raddr, "10.", 3) == 0 ||
             strncmp(c->raddr, "192.168.", 8) == 0 ||
             strncmp(c->raddr, "172.", 4) == 0) {
    strcpy(c->country, "PRIVATE");
  } else {
    strcpy(c->country, "EXTERNAL");
  }

  strcpy(c->asn, "N/A");
  c->latency = -1;
}

int load_connections(const char *path, const char *proto, Conn *list, int max) {
  FILE *fp = fopen(path, "r");
  if (!fp) {
    return 0;
  }

  char line[512];
  fgets(line, sizeof(line), fp); // skip header
  int count = 0;

  while (fgets(line, sizeof(line), fp) && count < max) {
    char local_hex[64] = {0}, local_port[8] = {0};
    char rem_hex[64] = {0}, rem_port[8] = {0};
    char state[8] = {0};

    int ret = sscanf(
        line,
        "%*d: %63[0-9A-Fa-f]:%7[0-9A-Fa-f] %63[0-9A-Fa-f]:%7[0-9A-Fa-f] %7s",
        local_hex, local_port, rem_hex, rem_port, state);

    if (ret < 5) {
      continue;
    }

    // Skip if any hex field is empty
    if (strlen(local_hex) == 0 || strlen(local_port) == 0 ||
        strlen(rem_hex) == 0 || strlen(rem_port) == 0) {
      continue;
    }

    char lip[64] = {0}, rip[64] = {0};
    int lport = 0, rport = 0;

    hex_to_ip_port(local_hex, local_port, lip, &lport);
    hex_to_ip_port(rem_hex, rem_port, rip, &rport);

    // Skip invalid addresses
    if (strcmp(lip, "0.0.0.0") == 0 && strcmp(rip, "0.0.0.0") == 0) {
      continue;
    }

    snprintf(list[count].proto, sizeof(list[count].proto), "%s", proto);
    snprintf(list[count].laddr, sizeof(list[count].laddr), "%s:%d", lip, lport);
    snprintf(list[count].raddr, sizeof(list[count].raddr), "%s:%d", rip, rport);
    snprintf(list[count].state, sizeof(list[count].state), "%s", state);

    enrich_data(&list[count]);
    count++;
  }

  fclose(fp);
  return count;
}

int main() {
  // Initialize ncurses
  initscr();
  cbreak();
  noecho();
  curs_set(0);
  keypad(stdscr, TRUE);

  int row, col;
  getmaxyx(stdscr, row, col);

  Conn list[1024] = {0};
  int offset = 0;
  int ch;

  while (1) {
    int count = 0;
    count +=
        load_connections("/proc/net/tcp", "TCP", list + count, 1024 - count);
    count +=
        load_connections("/proc/net/udp", "UDP", list + count, 1024 - count);

    clear();

    // Header
    mvprintw(0, 0,
             "Proto | Local Address         | Remote Address        | Country "
             "| State");
    mvhline(1, 0, '-', col);

    // Display connections
    int display_count = 0;
    for (int i = 0; i < count && display_count < row - 3; i++) {
      if (i >= offset) {
        mvprintw(display_count + 2, 0, "%-5s | %-21s | %-21s | %-7s | %-5s",
                 list[i].proto, list[i].laddr, list[i].raddr, list[i].country,
                 list[i].state);
        display_count++;
      }
    }

    // Footer with navigation info
    mvhline(row - 2, 0, '-', col);
    if (count > 0) {
      mvprintw(row - 1, 0,
               "Connections: %d | Position: %d-%d | ↑↓: Scroll | q: Quit",
               count, offset + 1, offset + display_count);
    } else {
      mvprintw(row - 1, 0, "No connections found | q: Quit");
    }

    refresh();

    // Handle input
    timeout(1000); // Refresh every second
    ch = getch();

    if (ch == KEY_DOWN && offset < count - 1) {
      offset++;
    } else if (ch == KEY_UP && offset > 0) {
      offset--;
    } else if (ch == KEY_NPAGE) { // Page down
      offset += (row - 3);
      if (offset > count - 1)
        offset = count - 1;
    } else if (ch == KEY_PPAGE) { // Page up
      offset -= (row - 3);
      if (offset < 0)
        offset = 0;
    } else if (ch == 'q' || ch == 'Q') {
      break;
    }
  }

  endwin();
  return 0;
}
