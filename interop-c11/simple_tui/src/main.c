// src/main.c
#include <ncurses.h>
#include <string.h>

#define TAB_COUNT 3
const char *tab_names[TAB_COUNT] = {"Home", "Settings", "About"};
int current_tab = 0;

void draw_tabs() {
  attron(A_BOLD);
  int x = 0;
  for (int i = 0; i < TAB_COUNT; i++) {
    if (i == current_tab) {
      attron(A_REVERSE);
    }
    mvprintw(0, x, " %s ", tab_names[i]);
    attroff(A_REVERSE);
    x += strlen(tab_names[i]) + 3;
  }
  attroff(A_BOLD);
  mvhline(1, 0, '-', x);
}

void draw_content() {
  for (int i = 2; i < LINES; i++) {
    mvprintw(i, 0, "%*s", COLS, ""); // Clear line
  }

  switch (current_tab) {
  case 0:
    mvprintw(3, 5, "Welcome to the Home tab!");
    mvprintw(5, 5, "Press TAB to switch tabs, 'q' to quit.");
    break;
  case 1:
    mvprintw(3, 5, "Settings tab:");
    mvprintw(5, 5, "Adjust your preferences here.");
    break;
  case 2:
    mvprintw(3, 5, "About tab:");
    mvprintw(5, 5, "Simple TUI with ncurses and nob.h");
    mvprintw(6, 5, "Press LEFT/RIGHT or TAB to navigate.");
    break;
  }
}

int main() {
  initscr();
  cbreak();
  noecho();
  keypad(stdscr, TRUE);

  // Draw initial screen
  clear();
  draw_tabs();
  draw_content();
  refresh();

  int ch;
  while ((ch = getch()) != 'q') {
    switch (ch) {
    case '\t': // Tab
    case KEY_RIGHT:
      current_tab = (current_tab + 1) % TAB_COUNT;
      break;
    case KEY_LEFT:
      current_tab = (current_tab - 1 + TAB_COUNT) % TAB_COUNT;
      break;
    }

    clear();
    draw_tabs();
    draw_content();
    refresh();
  }

  endwin();
  return 0;
}
