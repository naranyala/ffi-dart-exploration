// wave_circle.c - Centered Circle with Wave Animation (C11 + raylib)
// Build (Linux/Mac): cc -std=c11 wave_circle.c -o wave_circle -lraylib -lm
// Build (Windows, MinGW): gcc -std=c11 wave_circle.c -o wave_circle.exe
// -lraylib -lopengl32 -lgdi32 -lwinmm

#include "raylib.h"
#include <math.h> // for sinf()

int main(void) {
  const int screenWidth = 800;
  const int screenHeight = 600;

  InitWindow(screenWidth, screenHeight, "Centered Circle Wave Animation");
  SetTargetFPS(60);

  float baseRadius = 50.0f; // starting radius
  float amplitude = 20.0f;  // how much it grows/shrinks
  float speed = 2.0f;       // wave speed multiplier

  while (!WindowShouldClose()) {
    // Time-based animation
    float time = GetTime();
    float wave = sinf(time * speed); // oscillates between -1 and 1
    float radius = baseRadius + amplitude * wave;

    BeginDrawing();
    ClearBackground(BLACK);

    // Draw centered circle
    DrawCircle(screenWidth / 2, screenHeight / 2, radius, SKYBLUE);

    // Optional: draw debug info
    DrawText(TextFormat("Radius: %.2f", radius), 10, 10, 20, RAYWHITE);
    EndDrawing();
  }

  CloseWindow();
  return 0;
}
