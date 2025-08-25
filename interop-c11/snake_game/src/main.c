// snake.c - Minimal Snake Game using raylib (C11)
// Build (Linux/Mac): cc -std=c11 snake.c -o snake -lraylib -lm
// Build (Windows, MinGW): gcc -std=c11 snake.c -o snake.exe -lraylib -lopengl32
// -lgdi32 -lwinmm

#include "raylib.h"
#include <stdbool.h>
#include <stdlib.h>

#define CELL_SIZE 20
#define GRID_WIDTH 20
#define GRID_HEIGHT 20
#define FPS 10

typedef struct {
  int x, y;
} Vec2i;

typedef struct {
  Vec2i body[GRID_WIDTH * GRID_HEIGHT];
  int length;
  Vec2i dir;
} Snake;

static Snake snake;
static Vec2i food;
static bool gameOver = false;

static void ResetGame(void) {
  snake.length = 3;
  snake.body[0] = (Vec2i){GRID_WIDTH / 2, GRID_HEIGHT / 2};
  snake.body[1] = (Vec2i){GRID_WIDTH / 2 - 1, GRID_HEIGHT / 2};
  snake.body[2] = (Vec2i){GRID_WIDTH / 2 - 2, GRID_HEIGHT / 2};
  snake.dir = (Vec2i){1, 0};
  food.x = rand() % GRID_WIDTH;
  food.y = rand() % GRID_HEIGHT;
  gameOver = false;
}

static void UpdateGame(void) {
  // Input
  if (IsKeyPressed(KEY_UP) && snake.dir.y == 0)
    snake.dir = (Vec2i){0, -1};
  if (IsKeyPressed(KEY_DOWN) && snake.dir.y == 0)
    snake.dir = (Vec2i){0, 1};
  if (IsKeyPressed(KEY_LEFT) && snake.dir.x == 0)
    snake.dir = (Vec2i){-1, 0};
  if (IsKeyPressed(KEY_RIGHT) && snake.dir.x == 0)
    snake.dir = (Vec2i){1, 0};

  // Move body
  for (int i = snake.length - 1; i > 0; i--) {
    snake.body[i] = snake.body[i - 1];
  }
  snake.body[0].x += snake.dir.x;
  snake.body[0].y += snake.dir.y;

  // Wrap around edges (optional)
  if (snake.body[0].x < 0)
    snake.body[0].x = GRID_WIDTH - 1;
  if (snake.body[0].x >= GRID_WIDTH)
    snake.body[0].x = 0;
  if (snake.body[0].y < 0)
    snake.body[0].y = GRID_HEIGHT - 1;
  if (snake.body[0].y >= GRID_HEIGHT)
    snake.body[0].y = 0;

  // Check self collision
  for (int i = 1; i < snake.length; i++) {
    if (snake.body[0].x == snake.body[i].x &&
        snake.body[0].y == snake.body[i].y) {
      gameOver = true;
    }
  }

  // Check food collision
  if (snake.body[0].x == food.x && snake.body[0].y == food.y) {
    snake.length++;
    food.x = rand() % GRID_WIDTH;
    food.y = rand() % GRID_HEIGHT;
  }
}

static void DrawGame(void) {
  ClearBackground(BLACK);

  // Draw food
  DrawRectangle(food.x * CELL_SIZE, food.y * CELL_SIZE, CELL_SIZE, CELL_SIZE,
                RED);

  // Draw snake
  for (int i = 0; i < snake.length; i++) {
    DrawRectangle(snake.body[i].x * CELL_SIZE, snake.body[i].y * CELL_SIZE,
                  CELL_SIZE, CELL_SIZE, GREEN);
  }

  if (gameOver) {
    DrawText("GAME OVER - Press R to Restart", 20, GetScreenHeight() / 2 - 10,
             20, WHITE);
  }
}

int main(void) {
  InitWindow(GRID_WIDTH * CELL_SIZE, GRID_HEIGHT * CELL_SIZE,
             "Snake - raylib C11");
  SetTargetFPS(FPS);
  srand(GetTime());

  ResetGame();

  while (!WindowShouldClose()) {
    if (!gameOver) {
      UpdateGame();
    } else if (IsKeyPressed(KEY_R)) {
      ResetGame();
    }

    BeginDrawing();
    DrawGame();
    EndDrawing();
  }

  CloseWindow();
  return 0;
}
