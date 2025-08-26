#include "raylib.h"
#include <math.h>

// Structure to hold triangle properties
typedef struct {
  Vector2 center;
  float radius;
  float angle;
  float rotationSpeed;
  Color fillColor;
  Color borderColor;
  float borderThickness;
} Triangle;

// Function to create a new triangle
Triangle CreateTriangle(Vector2 center, float radius, float rotationSpeed,
                        Color fillColor, Color borderColor,
                        float borderThickness) {
  Triangle triangle = {0};
  triangle.center = center;
  triangle.radius = radius;
  triangle.angle = 0.0f;
  triangle.rotationSpeed = rotationSpeed;
  triangle.fillColor = fillColor;
  triangle.borderColor = borderColor;
  triangle.borderThickness = borderThickness;
  return triangle;
}

// Function to update triangle rotation
void UpdateTriangle(Triangle *triangle) {
  triangle->angle += triangle->rotationSpeed * GetFrameTime();
}

// Function to draw a triangle
void DrawTriangleShape(Triangle triangle) {
  // Convert angle to radians
  float angleRad = triangle.angle * DEG2RAD;

  // Calculate triangle vertices (equilateral triangle)
  Vector2 vertex1 = {
      triangle.center.x +
          triangle.radius * cosf(angleRad - PI / 2), // Top vertex
      triangle.center.y + triangle.radius * sinf(angleRad - PI / 2)};

  Vector2 vertex2 = {
      triangle.center.x +
          triangle.radius * cosf(angleRad + PI / 2 + PI / 3), // Bottom right
      triangle.center.y + triangle.radius * sinf(angleRad + PI / 2 + PI / 3)};

  Vector2 vertex3 = {
      triangle.center.x +
          triangle.radius * cosf(angleRad + PI / 2 - PI / 3), // Bottom left
      triangle.center.y + triangle.radius * sinf(angleRad + PI / 2 - PI / 3)};

  // Draw filled triangle
  DrawTriangle(vertex1, vertex2, vertex3, triangle.fillColor);

  // Draw triangle border
  DrawLineEx(vertex1, vertex2, triangle.borderThickness, triangle.borderColor);
  DrawLineEx(vertex2, vertex3, triangle.borderThickness, triangle.borderColor);
  DrawLineEx(vertex3, vertex1, triangle.borderThickness, triangle.borderColor);
}

int main(void) {
  // Screen dimensions
  const int screenWidth = 800;
  const int screenHeight = 450;

  // Initialize window
  InitWindow(screenWidth, screenHeight, "Two Spinning Triangles");

  // Create two perfectly centered overlapping triangles
  Vector2 screenCenter = {screenWidth / 2.0f, screenHeight / 2.0f};

  Triangle triangle1 =
      CreateTriangle(screenCenter, // Perfect center
                     80.0f,        // Larger radius
                     60.0f,        // Rotation speed (degrees/sec)
                     (Color){255, 100, 100, 180}, // Semi-transparent red
                     YELLOW,                      // Border color
                     3.0f                         // Border thickness
      );

  Triangle triangle2 =
      CreateTriangle(screenCenter, // Same perfect center
                     70.0f,        // Smaller radius
                     -80.0f,       // Negative rotation (counter-clockwise)
                     (Color){100, 100, 255, 180}, // Semi-transparent blue
                     WHITE,                       // Border color
                     2.5f                         // Border thickness
      );

  SetTargetFPS(60);

  // Main game loop
  while (!WindowShouldClose()) {
    // Update both triangles
    UpdateTriangle(&triangle1);
    UpdateTriangle(&triangle2);

    // Draw everything
    BeginDrawing();

    ClearBackground(DARKGRAY);

    // Draw both triangles
    DrawTriangleShape(triangle1);
    DrawTriangleShape(triangle2);

    // Draw center point for reference (both triangles share this point)
    DrawCircleV(screenCenter, 4.0f, GREEN);

    // Draw info text
    DrawText("Perfectly Centered Spinning Triangles", 10, 10, 20, WHITE);
    DrawText("Concentric rotation with size difference", 10, 40, 16, LIGHTGRAY);
    DrawText(TextFormat("Red Triangle Angle: %.1f°", triangle1.angle), 10, 70,
             14, LIGHTGRAY);
    DrawText(TextFormat("Blue Triangle Angle: %.1f°", triangle2.angle), 10, 90,
             14, LIGHTGRAY);

    EndDrawing();
  }

  // Clean up
  CloseWindow();

  return 0;
}
