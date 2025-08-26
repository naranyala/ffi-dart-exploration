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
  char state[8];
} Conn;

void hex_to_ip_port(const char *hex_ip, const char *hex_port, char *ip_str,
                    int *port) {
  unsigned int ip;
  sscanf(hex_ip, "%X", &ip);
  struct in_addr in;
  in.s_addr = htonl(ip);
  strcpy(ip_str, inet_ntoa(in));

  unsigned int p;
  sscanf(hex_port, "%X", &p);
  *port = p;
}

int load_connections(const char *path, const char *proto, Conn *list, int max) {
  FILE *fp = fopen(path, "r");
  if (!fp)
    return 0;

  char line[512];
  fgets(line, sizeof(line), fp); // skip header
  int count = 0;

  while (fgets(line, sizeof(line), fp) && count < max) {
    char local_hex[64], local_port[8];
    char rem_hex[64], rem_port[8];
    char state[8];
    sscanf(line, "%*d: %64[0-9A-F]:%8[0-9A-F] %64[0-9A-F]:%8[0-9A-F] %2s",
           local_hex, local_port, rem_hex, rem_port, state);

    char lip[64], rip[64];
    int lport, rport;
    hex_to_ip_port(local_hex, local_port, lip, &lport);
    hex_to_ip_port(rem_hex, rem_port, rip, &rport);

    snprintf(list[count].proto, sizeof(list[count].proto), "%s", proto);
    snprintf(list[count].laddr, sizeof(list[count].laddr), "%s:%d", lip, lport);
    snprintf(list[count].raddr, sizeof(list[count].raddr), "%s:%d", rip, rport);
    snprintf(list[count].state, sizeof(list[count].state), "%s", state);
    count++;
  }

  fclose(fp);
  return count;
}

int main() {
  initscr();
  cbreak();
  noecho();
  curs_set(0);
  keypad(stdscr, TRUE);

  int row, col;
  getmaxyx(stdscr, row, col);

  Conn list[1024];
  int offset = 0;
  int ch;

  while (1) {
    int count = 0;
    count +=
        load_connections("/proc/net/tcp", "TCP", list + count, 1024 - count);
    count +=
        load_connections("/proc/net/udp", "UDP", list + count, 1024 - count);

    clear();
    mvprintw(0, 0,
             "Proto | Local Address         | Remote Address        | St");
    mvhline(1, 0, '-', col);

    for (int i = 0; i + offset < count && i + 2 < row; i++) {
      mvprintw(i + 2, 0, "%-5s | %-21s | %-21s | %-2s", list[i + offset].proto,
               list[i + offset].laddr, list[i + offset].raddr,
               list[i + offset].state);
    }

    refresh();

    // Handle keyboard
    timeout(500); // refresh every 500ms
    ch = getch();
    if (ch == KEY_DOWN && offset + row - 2 < count)
      offset++;
    if (ch == KEY_UP && offset > 0)
      offset--;
    if (ch == 'q')
      break; // quit on 'q'
  }

  endwin();
  return 0;
}
