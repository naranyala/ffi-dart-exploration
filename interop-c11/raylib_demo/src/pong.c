// // Single-file Pong in C11 with Raylib (no external Clamp)
// // Compile (Linux/macOS):
// //   gcc -std=c11 -O2 pong.c -o pong -lraylib -lm
//
// #include "raylib.h"
// #include <math.h> // for fmaxf/fminf (optional, we use pure C below)
// #include <stdbool.h>
//
// static float ClampF(float v, float lo, float hi) {
//   return (v < lo) ? lo : (v > hi) ? hi : v;
// }
//
// int main(void) {
//   const int screenWidth = 800;
//   const int screenHeight = 600;
//
//   InitWindow(screenWidth, screenHeight, "Pong");
//
//   // Paddles
//   Rectangle leftPaddle = {10, screenHeight / 2 - 50, 10, 100};
//   Rectangle rightPaddle = {screenWidth - 20, screenHeight / 2 - 50, 10, 100};
//
//   // Ball
//   const int ballSize = 16;
//   Vector2 ballPos = {screenWidth / 2 - ballSize / 2,
//                      screenHeight / 2 - ballSize / 2};
//   Vector2 ballVel = {200.0f, 200.0f};
//
//   const float paddleSpd = 400.0f;
//
//   SetTargetFPS(60);
//   while (!WindowShouldClose()) {
//     float dt = GetFrameTime();
//
//     // Move paddles
//     if (IsKeyDown(KEY_W))
//       leftPaddle.y -= paddleSpd * dt;
//     if (IsKeyDown(KEY_S))
//       leftPaddle.y += paddleSpd * dt;
//     if (IsKeyDown(KEY_UP))
//       rightPaddle.y -= paddleSpd * dt;
//     if (IsKeyDown(KEY_DOWN))
//       rightPaddle.y += paddleSpd * dt;
//
//     // Clamp paddles inside window
//     leftPaddle.y = ClampF(leftPaddle.y, 0, screenHeight - leftPaddle.height);
//     rightPaddle.y = ClampF(rightPaddle.y, 0, screenHeight -
//     rightPaddle.height);
//
//     // Ball physics
//     ballPos.x += ballVel.x * dt;
//     ballPos.y += ballVel.y * dt;
//
//     // Bounce off top/bottom
//     if (ballPos.y <= 0 || ballPos.y + ballSize >= screenHeight)
//       ballVel.y *= -1;
//
//     // Paddle collisions
//     Rectangle ballRect = {ballPos.x, ballPos.y, ballSize, ballSize};
//     if (CheckCollisionRecs(ballRect, leftPaddle) ||
//         CheckCollisionRecs(ballRect, rightPaddle))
//       ballVel.x *= -1;
//
//     // Reset when out of bounds
//     if (ballPos.x < 0 || ballPos.x + ballSize > screenWidth) {
//       ballPos = (Vector2){screenWidth / 2 - ballSize / 2,
//                           screenHeight / 2 - ballSize / 2};
//       // send ball in opposite horizontal direction, randomize vertical
//       ballVel.x = -ballVel.x;
//       ballVel.y = 200.0f * (GetRandomValue(0, 1) ? 1 : -1);
//     }
//
//     // Draw
//     BeginDrawing();
//     ClearBackground(BLACK);
//     DrawRectangleRec(leftPaddle, WHITE);
//     DrawRectangleRec(rightPaddle, WHITE);
//     DrawRectangle(ballPos.x, ballPos.y, ballSize, ballSize, WHITE);
//     EndDrawing();
//   }
//
//   CloseWindow();
//   return 0;
// }
