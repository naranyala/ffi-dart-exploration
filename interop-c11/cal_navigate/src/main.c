#define _POSIX_C_SOURCE 200809L

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/select.h>
#include <termios.h>
#include <time.h>
#include <unistd.h>

// For ncurses-style simplicity without linking ncurses
#define HIDE_CURSOR "\x1b[?25l"
#define SHOW_CURSOR "\x1b[?25h"
#define CLEAR_SCREEN "\x1b[2J"
#define MOVE_HOME "\x1b[H"
#define RESET_ATTRIB "\x1b[0m"
#define REVERSE_VIDEO "\x1b[7m"

// Days and months
const char *weekday_names[] = {"Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"};
const char *month_names[] = {"January",   "February", "March",    "April",
                             "May",       "June",     "July",     "August",
                             "September", "October",  "November", "December"};

// Date structure
typedef struct {
  int year;
  int month; // 1-12
  int day;   // 1-31
} Date;

// Function declarations
Date today(void);
void add_days(Date *d, int days);
void add_months(Date *d, int months);
int get_weekday(Date d);
int is_leap_year(int year);
int days_in_month(int year, int month);
void render(Date current_month_start, Date selected);
void enable_raw_mode(void);
void disable_raw_mode(void);
int kbhit(void);
int read_key(void);

// Global for raw mode
static struct termios orig_termios;

// === Date Functions ===

Date today(void) {
  time_t t = time(NULL);
  struct tm *tm = localtime(&t);
  return (Date){
      .year = tm->tm_year + 1900, .month = tm->tm_mon + 1, .day = tm->tm_mday};
}

int is_leap_year(int year) {
  return (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
}

int days_in_month(int year, int month) {
  switch (month) {
  case 1:
  case 3:
  case 5:
  case 7:
  case 8:
  case 10:
  case 12:
    return 31;
  case 4:
  case 6:
  case 9:
  case 11:
    return 30;
  case 2:
    return is_leap_year(year) ? 29 : 28;
  default:
    return 30;
  }
}

int get_weekday(Date d) {
  // Zeller's congruence (Sunday = 0)
  int month = d.month;
  int year = d.year;
  if (month < 3) {
    month += 12;
    year--;
  }
  int k = year % 100;
  int j = year / 100;
  int h = (d.day + (13 * (month + 1)) / 5 + k + k / 4 + j / 4 - 2 * j) % 7;
  return (h + 7) % 7; // Normalize
}

void add_days(Date *d, int days) {
  while (days > 0) {
    int limit = days_in_month(d->year, d->month);
    if (d->day + days <= limit) {
      d->day += days;
      days = 0;
    } else {
      days -= (limit - d->day + 1);
      d->day = 1;
      if (d->month == 12) {
        d->month = 1;
        d->year++;
      } else {
        d->month++;
      }
    }
  }
  while (days < 0) {
    if (d->day + days > 0) {
      d->day += days;
      days = 0;
    } else {
      days += d->day;
      if (d->month == 1) {
        d->month = 12;
        d->year--;
      } else {
        d->month--;
      }
      d->day = days_in_month(d->year, d->month);
    }
  }
}

void add_months(Date *d, int months) {
  int m = d->month - 1 + months;
  while (m < 0) {
    m += 12;
    d->year--;
  }
  d->year += m / 12;
  d->month = (m % 12) + 1;

  int dim = days_in_month(d->year, d->month);
  if (d->day > dim)
    d->day = dim;
}

// === Terminal I/O ===

void enable_raw_mode() {
  struct termios raw = orig_termios;
  raw.c_lflag &= ~(ECHO | ICANON); // Disable echo and canonical mode
  raw.c_cc[VMIN] = 1;
  raw.c_cc[VTIME] = 0;
  tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw);
}

void disable_raw_mode() {
  tcsetattr(STDIN_FILENO, TCSAFLUSH, &orig_termios);
  printf(SHOW_CURSOR);
  fflush(stdout);
}

// Check if a key was pressed
int kbhit() {
  fd_set set;
  struct timeval timeout;
  FD_ZERO(&set);
  FD_SET(STDIN_FILENO, &set);
  timeout.tv_sec = 0;
  timeout.tv_usec = 0;
  return select(STDIN_FILENO + 1, &set, NULL, NULL, &timeout) == 1;
}

// Read one byte (or escape sequence)
int read_key() {
  if (!kbhit())
    return 0;

  char c;
  if (read(STDIN_FILENO, &c, 1) != 1)
    return 0;

  if (c == '\x1b') {
    char seq[2];
    if (read(STDIN_FILENO, &seq[0], 1) != 1)
      return 0;
    if (seq[0] == '[') {
      if (read(STDIN_FILENO, &seq[1], 1) != 1)
        return 0;
      switch (seq[1]) {
      case 'A':
        return 'k';
      case 'B':
        return 'j';
      case 'C':
        return 'l';
      case 'D':
        return 'h';
      }
    }
    return 0; // Unknown escape
  }
  return c;
}

// === Rendering ===

void render(Date current_month_start, Date selected) {
  int year = current_month_start.year;
  int month = current_month_start.month;
  int first_day = get_weekday((Date){year, month, 1});
  int dim = days_in_month(year, month);

  printf(CLEAR_SCREEN MOVE_HOME);

  // Title
  printf("         %s %d\n", month_names[month - 1], year);
  printf("Su Mo Tu We Th Fr Sa\n");

  // Spaces for first week
  for (int i = 0; i < first_day; i++)
    printf("   ");

  for (int d = 1; d <= dim; d++) {
    int is_selected =
        (selected.year == year && selected.month == month && selected.day == d);
    if (is_selected)
      printf(REVERSE_VIDEO);
    printf("%2d", d);
    if (is_selected)
      printf(RESET_ATTRIB);

    if (d < dim) {
      if ((first_day + d) % 7 == 0)
        printf("\n");
      else
        printf(" ");
    }
  }
  printf("\n");

  // Legend
  printf("hjkl/arrows: nav  t: today  q: quit\n");
}

// === Main ===

int main() {
  // Save original terminal settings
  if (tcgetattr(STDIN_FILENO, &orig_termios) == -1) {
    perror("tcgetattr");
    return 1;
  }

  atexit(disable_raw_mode);
  enable_raw_mode();
  printf(HIDE_CURSOR);

  Date today_date = today();
  Date selected = today_date;
  Date current_month = {selected.year, selected.month, 1};

  while (1) {
    render(current_month, selected);

    int key;
    while ((key = read_key()) == 0) {
      struct timespec ts = {.tv_sec = 0,
                            .tv_nsec = 10000000}; // 10 milliseconds
      nanosleep(&ts, NULL);
    }

    switch (key) {
    case 'q':
      return 0;
    case 't':
      selected = today_date;
      current_month = (Date){selected.year, selected.month, 1};
      break;
    case 'h':
      add_days(&selected, -1);
      break;
    case 'l':
      add_days(&selected, +1);
      break;
    case 'k':
      add_days(&selected, -7);
      break;
    case 'j':
      add_days(&selected, +7);
      break;
    }
    current_month = (Date){selected.year, selected.month, 1};
  }

  return 0;
}
