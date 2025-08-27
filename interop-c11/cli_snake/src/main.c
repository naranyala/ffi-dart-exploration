#define OLIVEC_IMPLEMENTATION
#include "../olive.c/olive.c"

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

// Window and game constants
#define WINDOW_WIDTH 800
#define WINDOW_HEIGHT 600
#define GRID_SIZE 20
#define GRID_WIDTH (WINDOW_WIDTH / GRID_SIZE)
#define GRID_HEIGHT (WINDOW_HEIGHT / GRID_SIZE)
#define MAX_SNAKE_LENGTH 1000

// Direction constants
typedef enum { DIR_UP, DIR_DOWN, DIR_LEFT, DIR_RIGHT } Direction;

// Point structure
typedef struct {
  int x, y;
} Point;

// Game state
typedef struct {
  Point snake[MAX_SNAKE_LENGTH];
  int snake_length;
  Direction direction;
  Point food;
  int score;
  int game_over;
  int paused;
  double last_move_time;
  double move_interval;
} GameState;

// Global state
GameState game = {0};
Olivec_Canvas canvas = {0};

// Colors
#define COLOR_BACKGROUND 0xFF1a1a1a
#define COLOR_SNAKE_HEAD 0xFF00ff00
#define COLOR_SNAKE_BODY 0xFF00aa00
#define COLOR_FOOD 0xFFff0000
#define COLOR_GRID 0xFF333333
#define COLOR_TEXT 0xFFffffff

// Initialize the game
void init_game() {
  srand(time(NULL));

  // Initialize snake in the center
  game.snake[0].x = GRID_WIDTH / 2;
  game.snake[0].y = GRID_HEIGHT / 2;
  game.snake[1].x = game.snake[0].x - 1;
  game.snake[1].y = game.snake[0].y;
  game.snake[2].x = game.snake[0].x - 2;
  game.snake[2].y = game.snake[0].y;

  game.snake_length = 3;
  game.direction = DIR_RIGHT;
  game.score = 0;
  game.game_over = 0;
  game.paused = 0;
  game.last_move_time = 0;
  game.move_interval = 0.2; // 200ms between moves

  // Generate first food
  generate_food();
}

// Check if position is occupied by snake
int is_position_occupied(int x, int y) {
  for (int i = 0; i < game.snake_length; i++) {
    if (game.snake[i].x == x && game.snake[i].y == y) {
      return 1;
    }
  }
  return 0;
}

// Generate food at random position
void generate_food() {
  int attempts = 0;
  do {
    game.food.x = rand() % GRID_WIDTH;
    game.food.y = rand() % GRID_HEIGHT;
    attempts++;
  } while (is_position_occupied(game.food.x, game.food.y) && attempts < 100);
}

// Handle keyboard input
void handle_input() {
  // This is a placeholder - you'd integrate with your window system
  // For now, we'll simulate some basic input handling

  // Note: You'd need to integrate this with SDL2, GLFW, or similar
  // for actual keyboard input. This is just the game logic structure.
}

// Move the snake
void move_snake() {
  if (game.game_over || game.paused)
    return;

  // Calculate new head position
  Point new_head = game.snake[0];

  switch (game.direction) {
  case DIR_UP:
    new_head.y--;
    break;
  case DIR_DOWN:
    new_head.y++;
    break;
  case DIR_LEFT:
    new_head.x--;
    break;
  case DIR_RIGHT:
    new_head.x++;
    break;
  }

  // Handle wall collision (wrap around)
  if (new_head.x < 0)
    new_head.x = GRID_WIDTH - 1;
  if (new_head.x >= GRID_WIDTH)
    new_head.x = 0;
  if (new_head.y < 0)
    new_head.y = GRID_HEIGHT - 1;
  if (new_head.y >= GRID_HEIGHT)
    new_head.y = 0;

  // Check self collision
  for (int i = 0; i < game.snake_length; i++) {
    if (game.snake[i].x == new_head.x && game.snake[i].y == new_head.y) {
      game.game_over = 1;
      return;
    }
  }

  // Move body segments
  for (int i = game.snake_length - 1; i > 0; i--) {
    game.snake[i] = game.snake[i - 1];
  }

  // Set new head position
  game.snake[0] = new_head;

  // Check food collision
  if (game.snake[0].x == game.food.x && game.snake[0].y == game.food.y) {
    game.score += 10;
    if (game.snake_length < MAX_SNAKE_LENGTH) {
      game.snake_length++;
    }
    generate_food();

    // Increase speed slightly
    if (game.move_interval > 0.05) {
      game.move_interval -= 0.005;
    }
  }
}

// Update game logic
void update_game(double dt) {
  if (game.game_over)
    return;

  game.last_move_time += dt;
  if (game.last_move_time >= game.move_interval) {
    move_snake();
    game.last_move_time = 0;
  }
}

// Draw a grid cell
void draw_cell(int grid_x, int grid_y, uint32_t color) {
  int pixel_x = grid_x * GRID_SIZE;
  int pixel_y = grid_y * GRID_SIZE;

  olivec_rect(canvas, pixel_x, pixel_y, GRID_SIZE - 1, GRID_SIZE - 1, color);
}

// Draw grid lines
void draw_grid() {
  // Vertical lines
  for (int x = 0; x <= GRID_WIDTH; x++) {
    olivec_line(canvas, x * GRID_SIZE, 0, x * GRID_SIZE, WINDOW_HEIGHT,
                COLOR_GRID);
  }

  // Horizontal lines
  for (int y = 0; y <= GRID_HEIGHT; y++) {
    olivec_line(canvas, 0, y * GRID_SIZE, WINDOW_WIDTH, y * GRID_SIZE,
                COLOR_GRID);
  }
}

// Draw the snake
void draw_snake() {
  // Draw body
  for (int i = 1; i < game.snake_length; i++) {
    draw_cell(game.snake[i].x, game.snake[i].y, COLOR_SNAKE_BODY);
  }

  // Draw head (with eyes)
  draw_cell(game.snake[0].x, game.snake[0].y, COLOR_SNAKE_HEAD);

  // Draw simple eyes on the head
  int head_pixel_x = game.snake[0].x * GRID_SIZE;
  int head_pixel_y = game.snake[0].y * GRID_SIZE;
  int eye_size = 3;
  int eye_offset = 5;

  uint32_t eye_color = 0xFF000000; // Black eyes

  if (game.direction == DIR_RIGHT || game.direction == DIR_LEFT) {
    olivec_rect(canvas, head_pixel_x + eye_offset, head_pixel_y + eye_offset,
                eye_size, eye_size, eye_color);
    olivec_rect(canvas, head_pixel_x + eye_offset,
                head_pixel_y + GRID_SIZE - eye_offset - eye_size, eye_size,
                eye_size, eye_color);
  } else {
    olivec_rect(canvas, head_pixel_x + eye_offset, head_pixel_y + eye_offset,
                eye_size, eye_size, eye_color);
    olivec_rect(canvas, head_pixel_x + GRID_SIZE - eye_offset - eye_size,
                head_pixel_y + eye_offset, eye_size, eye_size, eye_color);
  }
}

// Draw the food with animation
void draw_food() {
  static double food_time = 0;
  food_time += 0.016; // Roughly 60 FPS

  // Pulsing food animation
  double pulse = (sin(food_time * 6) + 1) * 0.5; // 0 to 1
  int size_variation = (int)(pulse * 4);
  int offset = size_variation / 2;

  int food_pixel_x = game.food.x * GRID_SIZE + offset;
  int food_pixel_y = game.food.y * GRID_SIZE + offset;
  int food_size = GRID_SIZE - 1 - size_variation;

  olivec_rect(canvas, food_pixel_x, food_pixel_y, food_size, food_size,
              COLOR_FOOD);
}

// Simple text rendering (very basic - you might want to use a proper font)
void draw_text(int x, int y, const char *text, uint32_t color) {
  // This is a placeholder for text rendering
  // olive.c doesn't have built-in text rendering, so you'd need to either:
  // 1. Draw pixel fonts manually
  // 2. Use a bitmap font
  // 3. Integrate with a text rendering library

  // For now, we'll just draw a rectangle where text would be
  int text_len = 0;
  while (text[text_len])
    text_len++; // Calculate string length
  olivec_rect(canvas, x, y, text_len * 8, 16, color);
}

// Draw UI elements
void draw_ui() {
  char score_text[32];
  snprintf(score_text, sizeof(score_text), "Score: %d", game.score);
  draw_text(10, 10, score_text, COLOR_TEXT);

  char length_text[32];
  snprintf(length_text, sizeof(length_text), "Length: %d", game.snake_length);
  draw_text(10, 30, length_text, COLOR_TEXT);

  if (game.game_over) {
    draw_text(WINDOW_WIDTH / 2 - 50, WINDOW_HEIGHT / 2, "GAME OVER!",
              0xFFff0000);
    draw_text(WINDOW_WIDTH / 2 - 80, WINDOW_HEIGHT / 2 + 20,
              "Press R to restart", COLOR_TEXT);
  }

  if (game.paused) {
    draw_text(WINDOW_WIDTH / 2 - 30, WINDOW_HEIGHT / 2, "PAUSED", COLOR_TEXT);
  }
}

// Main render function
void render_game() {
  // Clear background
  olivec_fill(canvas, COLOR_BACKGROUND);

  // Draw grid (optional - can be disabled for cleaner look)
  // draw_grid();

  // Draw game elements
  draw_food();
  draw_snake();
  draw_ui();
}

// Save the current frame as PPM (for testing without window system)
void save_frame(const char *filename) {
  if (!olivec_save_to_ppm(canvas, filename)) {
    fprintf(stderr, "ERROR: could not save frame to %s\n", filename);
  }
}

// Example usage function
void simulate_game_frame() {
  // Simulate one frame of the game
  static int frame_count = 0;
  frame_count++;

  // Simulate input (in real implementation, this would come from window system)
  if (frame_count == 60)
    game.direction = DIR_DOWN; // Turn down after 1 second
  if (frame_count == 120)
    game.direction = DIR_LEFT; // Turn left after 2 seconds
  if (frame_count == 180)
    game.direction = DIR_UP; // Turn up after 3 seconds

  // Update game
  update_game(1.0 / 60.0); // 60 FPS

  // Render
  render_game();

  // Save frame (for demonstration - remove in real implementation)
  if (frame_count % 30 == 0) { // Save every 0.5 seconds
    char filename[64];
    snprintf(filename, sizeof(filename), "snake_frame_%04d.ppm", frame_count);
    save_frame(filename);
  }
}

int main() {
  // Initialize canvas
  canvas.width = WINDOW_WIDTH;
  canvas.height = WINDOW_HEIGHT;
  canvas.stride = canvas.width;
  canvas.pixels = malloc(sizeof(uint32_t) * canvas.width * canvas.height);

  if (!canvas.pixels) {
    fprintf(stderr, "ERROR: Could not allocate memory for canvas\n");
    return 1;
  }

  // Initialize game
  init_game();

  printf("Snake Game with olive.c\n");
  printf("Generating demo frames...\n");

  // Simulate a few frames (in real implementation, this would be your main
  // loop)
  for (int i = 0; i < 300; i++) {
    simulate_game_frame();
  }

  printf("Demo complete! Check the generated PPM files.\n");
  printf("\nTo integrate with a window system:\n");
  printf("1. Add SDL2 or GLFW for window management and input\n");
  printf("2. Replace simulate_game_frame() with your main loop\n");
  printf("3. Handle keyboard input in handle_input()\n");
  printf("4. Display canvas.pixels in your window\n");

  // Cleanup
  free(canvas.pixels);
  return 0;
}
