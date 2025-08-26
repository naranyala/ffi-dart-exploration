#include "raylib.h"
#include <math.h>
#include <stdio.h>
#include <time.h>

#define SCREEN_WIDTH 800
#define SCREEN_HEIGHT 600
#define CENTER_X (SCREEN_WIDTH / 2)
#define CENTER_Y (SCREEN_HEIGHT / 2)
#define CLOCK_RADIUS 200

// Function to draw clock hands with proper ticking movement
void DrawClockHands(int centerX, int centerY, float radius) {
  time_t now = time(NULL);
  struct tm *timeinfo = localtime(&now);

  // Get discrete time values for ticking behavior
  int seconds = timeinfo->tm_sec;
  int minutes = timeinfo->tm_min;
  int hours = timeinfo->tm_hour;

  if (hours >= 12)
    hours -= 12;

  // Convert to angles with discrete steps (no smooth interpolation)
  float secondAngle = (seconds / 60.0f) * 360.0f - 90.0f;
  float minuteAngle = (minutes / 60.0f) * 360.0f - 90.0f;
  float hourAngle =
      (hours / 12.0f) * 360.0f + (minutes / 60.0f) * 30.0f - 90.0f;

  // Draw hour hand (thick, dark)
  Vector2 hourEnd = {centerX + cos(hourAngle * DEG2RAD) * (radius * 0.5f),
                     centerY + sin(hourAngle * DEG2RAD) * (radius * 0.5f)};
  DrawLineEx((Vector2){centerX, centerY}, hourEnd, 8, DARKBROWN);

  // Draw minute hand (medium thickness)
  Vector2 minuteEnd = {centerX + cos(minuteAngle * DEG2RAD) * (radius * 0.75f),
                       centerY + sin(minuteAngle * DEG2RAD) * (radius * 0.75f)};
  DrawLineEx((Vector2){centerX, centerY}, minuteEnd, 5, DARKGRAY);

  // Draw second hand with proper ticking behavior
  Vector2 secondEnd = {centerX + cos(secondAngle * DEG2RAD) * (radius * 0.9f),
                       centerY + sin(secondAngle * DEG2RAD) * (radius * 0.9f)};

  // Make second hand red and thin
  DrawLineEx((Vector2){centerX, centerY}, secondEnd, 2, RED);

  // Draw counterweight for second hand
  Vector2 counterWeightEnd = {
      centerX + cos((secondAngle + 180) * DEG2RAD) * (radius * 0.15f),
      centerY + sin((secondAngle + 180) * DEG2RAD) * (radius * 0.15f)};
  DrawLineEx((Vector2){centerX, centerY}, counterWeightEnd, 2, RED);

  // Draw center circle with different colors
  DrawCircle(centerX, centerY, 10, BLACK);
  DrawCircle(centerX, centerY, 8, RED);
  DrawCircle(centerX, centerY, 4, WHITE);
}

// Function to draw clock face with enhanced ticks
void DrawClockFace(int centerX, int centerY, float radius) {
  // Draw clock face background
  DrawCircle(centerX, centerY, radius + 5, LIGHTGRAY);
  DrawCircle(centerX, centerY, radius, WHITE);

  // Draw outer rings
  DrawRing((Vector2){centerX, centerY}, radius - 2, radius + 2, 0, 360, 32,
           DARKGRAY);
  DrawRing((Vector2){centerX, centerY}, radius - 4, radius - 2, 0, 360, 32,
           LIGHTGRAY);

  // Draw hour ticks and numbers
  for (int i = 0; i < 12; i++) {
    float angle = (i * 30.0f) - 90.0f;
    float cosAngle = cos(angle * DEG2RAD);
    float sinAngle = sin(angle * DEG2RAD);

    // Draw major ticks (hours) - longer and thicker
    Vector2 innerPoint = {centerX + cosAngle * (radius * 0.8f),
                          centerY + sinAngle * (radius * 0.8f)};
    Vector2 outerPoint = {centerX + cosAngle * radius,
                          centerY + sinAngle * radius};
    DrawLineEx(innerPoint, outerPoint, 4, BLACK);

    // Draw hour numbers with better positioning
    char hourText[3];
    snprintf(hourText, sizeof(hourText), "%d", i == 0 ? 12 : i);

    int textWidth = MeasureText(hourText, 24);
    Vector2 textPos = {centerX + cosAngle * (radius * 0.65f) - textWidth / 2,
                       centerY + sinAngle * (radius * 0.65f) - 12};
    DrawText(hourText, textPos.x, textPos.y, 24, BLACK);
  }

  // Draw minute ticks - shorter and thinner
  for (int i = 0; i < 60; i++) {
    if (i % 5 != 0) { // Skip positions where hour ticks are
      float angle = (i * 6.0f) - 90.0f;
      float cosAngle = cos(angle * DEG2RAD);
      float sinAngle = sin(angle * DEG2RAD);

      Vector2 innerPoint = {centerX + cosAngle * (radius * 0.9f),
                            centerY + sinAngle * (radius * 0.9f)};
      Vector2 outerPoint = {centerX + cosAngle * radius,
                            centerY + sinAngle * radius};
      DrawLineEx(innerPoint, outerPoint, 2, DARKGRAY);
    }
  }
}

// Function to add subtle tick animation effect
void DrawTickAnimation(int centerX, int centerY, float radius) {
  static float tickEffect = 0.0f;
  static int lastSecond = -1;

  time_t now = time(NULL);
  struct tm *timeinfo = localtime(&now);
  int currentSecond = timeinfo->tm_sec;

  // Reset animation when second changes
  if (currentSecond != lastSecond) {
    tickEffect = 1.0f;
    lastSecond = currentSecond;
  }

  // Animate the tick effect
  if (tickEffect > 0.0f) {
    tickEffect -= GetFrameTime() * 8.0f; // Faster decay

    // Draw a subtle pulse effect
    float pulseSize = tickEffect * 10.0f;
    DrawCircleLines(centerX, centerY, radius + pulseSize,
                    Fade(RED, tickEffect * 0.3f));

    // Draw a small highlight at the tip of the second hand
    float secondAngle = (currentSecond / 60.0f) * 360.0f - 90.0f;
    Vector2 secondEnd = {centerX + cos(secondAngle * DEG2RAD) * (radius * 0.9f),
                         centerY +
                             sin(secondAngle * DEG2RAD) * (radius * 0.9f)};
    DrawCircle(secondEnd.x, secondEnd.y, 3 + pulseSize * 0.5f,
               Fade(YELLOW, tickEffect));
  }
}

int main(void) {
  // Initialize window
  InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Analog Clock with Proper Ticking");
  SetTargetFPS(60);

  // Main game loop
  while (!WindowShouldClose()) {
    // Begin drawing
    BeginDrawing();
    ClearBackground((Color){240, 240, 240, 255}); // Light gray background

    // Draw clock face
    DrawClockFace(CENTER_X, CENTER_Y, CLOCK_RADIUS);

    // Draw tick animation effect
    DrawTickAnimation(CENTER_X, CENTER_Y, CLOCK_RADIUS);

    // Draw clock hands (will tick every second)
    DrawClockHands(CENTER_X, CENTER_Y, CLOCK_RADIUS);

    // Draw digital time display
    time_t now = time(NULL);
    struct tm *timeinfo = localtime(&now);
    char timeStr[9];
    strftime(timeStr, sizeof(timeStr), "%H:%M:%S", timeinfo);

    // Style the digital display
    DrawRectangle(CENTER_X - 70, CENTER_Y + CLOCK_RADIUS + 20, 140, 40, BLACK);
    DrawText(timeStr, CENTER_X - MeasureText(timeStr, 20) / 2,
             CENTER_Y + CLOCK_RADIUS + 30, 20, GREEN);

    // Draw FPS counter
    DrawFPS(10, 10);

    // Draw instructions
    DrawText("Analog Clock with Proper Ticking Behavior", 200, 10, 20,
             DARKGRAY);

    EndDrawing();
  }

  // Close window
  CloseWindow();

  return 0;
}
