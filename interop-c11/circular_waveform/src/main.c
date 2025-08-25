// circular_waveform.c - Fake circular waveform animation in raylib (C11)
// Build (Linux/Mac): cc -std=c11 circular_waveform.c -o circular_waveform
// -lraylib -lm Build (Windows, MinGW): gcc -std=c11 circular_waveform.c -o
// circular_waveform.exe -lraylib -lopengl32 -lgdi32 -lwinmm

#include "raylib.h"
#include <math.h>

int main(void) {
  const int screenWidth = 800;
  const int screenHeight = 600;
  InitWindow(screenWidth, screenHeight, "Circular Fake Waveform Animation");
  SetTargetFPS(60);

  const int numBars = 64;       // number of radial bars
  const float baseRadius = 100; // inner circle radius
  const float amplitude = 50;   // how far bars extend
  const float speed = 4.0f;     // animation speed

  while (!WindowShouldClose()) {
    float time = GetTime();

    BeginDrawing();
    ClearBackground(BLACK);

    Vector2 center = {screenWidth / 2.0f, screenHeight / 2.0f};

    for (int i = 0; i < numBars; i++) {
      float angle = ((float)i / numBars) * 2.0f * PI;
      // Fake waveform: sine wave offset by bar index
      float wave = sinf(time * speed + i * 0.3f);
      float length = baseRadius + amplitude * (0.5f + 0.5f * wave);

      Vector2 start = {center.x + cosf(angle) * baseRadius,
                       center.y + sinf(angle) * baseRadius};
      Vector2 end = {center.x + cosf(angle) * length,
                     center.y + sinf(angle) * length};

      DrawLineEx(start, end, 2.0f,
                 ColorFromHSV((i * 360.0f / numBars), 1.0f, 1.0f));
    }

    DrawText("Fake Circular Waveform", 10, 10, 20, RAYWHITE);
    EndDrawing();
  }

  CloseWindow();
  return 0;
}
