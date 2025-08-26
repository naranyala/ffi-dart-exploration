#include "raylib.h"
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define SCREEN_WIDTH 400
#define SCREEN_HEIGHT 600
#define BUTTON_WIDTH 80
#define BUTTON_HEIGHT 80
#define BUTTON_MARGIN 10
#define DISPLAY_HEIGHT 120

typedef struct {
  Rectangle rect;
  char text[10];
  Color color;
  Color textColor;
  bool pressed;
} Button;

typedef struct {
  char display[50];
  double currentValue;
  double storedValue;
  char operation;
  bool newInput;
  bool error;
} Calculator;

// Button definitions
const char *buttonLabels[20] = {
    "C", "+/-", "%", "/", "7", "8", "9", "*", "4", "5",
    "6", "-",   "1", "2", "3", "+", "0", ".", "=", "←" // ← instead of ⌫
};

Color buttonColors[20] = {ORANGE,   LIGHTGRAY, LIGHTGRAY, ORANGE,   DARKGRAY,
                          DARKGRAY, DARKGRAY,  ORANGE,    DARKGRAY, DARKGRAY,
                          DARKGRAY, ORANGE,    DARKGRAY,  DARKGRAY, DARKGRAY,
                          ORANGE,   DARKGRAY,  DARKGRAY,  ORANGE,   ORANGE};

void InitCalculator(Calculator *calc) {
  strcpy(calc->display, "0");
  calc->currentValue = 0;
  calc->storedValue = 0;
  calc->operation = '\0';
  calc->newInput = true;
  calc->error = false;
}

void UpdateDisplay(Calculator *calc) {
  if (calc->error) {
    strcpy(calc->display, "Error");
    return;
  }

  // Format the number for display
  if (fabs(calc->currentValue) > 1e10 ||
      (fabs(calc->currentValue) < 1e-10 && calc->currentValue != 0)) {
    snprintf(calc->display, sizeof(calc->display), "%.4e", calc->currentValue);
    return;
  }

  // Remove trailing zeros and decimal point if not needed
  char temp[50];
  snprintf(temp, sizeof(temp), "%.10f", calc->currentValue);

  // Trim trailing zeros
  char *ptr = temp + strlen(temp) - 1;
  while (*ptr == '0' && ptr > temp) {
    *ptr-- = '\0';
  }
  if (*ptr == '.') {
    *ptr = '\0';
  }

  if (strlen(temp) == 0)
    strcpy(temp, "0"); // Safety check

  strncpy(calc->display, temp, sizeof(calc->display) - 1);
  calc->display[sizeof(calc->display) - 1] = '\0';
}

void ProcessButtonPress(Calculator *calc, int buttonIndex) {
  if (calc->error && buttonIndex != 0) { // Only allow Clear when in error
    return;
  }

  const char *label = buttonLabels[buttonIndex];

  if (strcmp(label, "C") == 0) {
    InitCalculator(calc);
    return;
  }

  if (strcmp(label, "⌫") == 0) {
    if (strlen(calc->display) > 1) {
      calc->display[strlen(calc->display) - 1] = '\0';
      calc->currentValue = atof(calc->display);
    } else {
      strcpy(calc->display, "0");
      calc->currentValue = 0;
      calc->newInput = true;
    }
    return;
  }

  if (strcmp(label, "±") == 0) {
    calc->currentValue = -calc->currentValue;
    UpdateDisplay(calc);
    return;
  }

  if (strcmp(label, "%") == 0) {
    calc->currentValue /= 100.0;
    UpdateDisplay(calc);
    return;
  }

  if (strcmp(label, ".") == 0) {
    if (calc->newInput) {
      strcpy(calc->display, "0.");
      calc->currentValue = 0;
      calc->newInput = false;
    } else if (strchr(calc->display, '.') == NULL) {
      strcat(calc->display, ".");
    }
    return;
  }

  if (strcmp(label, "=") == 0) {
    if (calc->operation != '\0') {
      double result = 0;
      switch (calc->operation) {
      case '+':
        result = calc->storedValue + calc->currentValue;
        break;
      case '-':
        result = calc->storedValue - calc->currentValue;
        break;
      case '*':
        result = calc->storedValue * calc->currentValue;
        break;
      case '/':
        if (fabs(calc->currentValue) < 1e-10) {
          calc->error = true;
          return;
        }
        result = calc->storedValue / calc->currentValue;
        break;
      }
      calc->currentValue = result;
      calc->operation = '\0';
      UpdateDisplay(calc);
      calc->newInput = true;
    }
    return;
  }

  // Handle arithmetic operations
  if (strcmp(label, "+") == 0 || strcmp(label, "-") == 0 ||
      strcmp(label, "*") == 0 || strcmp(label, "/") == 0) {

    if (calc->operation != '\0' && !calc->newInput) {
      ProcessButtonPress(calc, 18); // Evaluate previous op
    }

    calc->storedValue = calc->currentValue;
    calc->operation = label[0]; // Now safe: '+', '-', '*', '/'
    calc->newInput = true;
    return;
  }

  // Handle number input
  if (label[0] >= '0' && label[0] <= '9') {
    if (calc->newInput) {
      strcpy(calc->display, label);
      calc->currentValue = atof(label);
      calc->newInput = false;
    } else {
      if (strlen(calc->display) < 15) {
        if (strcmp(calc->display, "0") == 0) {
          strcpy(calc->display, label);
        } else {
          strcat(calc->display, label);
        }
        calc->currentValue = atof(calc->display);
      }
    }
    return;
  }
}

void DrawCalculator(Calculator *calc, Button *buttons) {
  // Draw display background
  DrawRectangle(0, 0, SCREEN_WIDTH, DISPLAY_HEIGHT, (Color){40, 40, 40, 255});
  DrawRectangleLines(0, 0, SCREEN_WIDTH, DISPLAY_HEIGHT, DARKGRAY);

  // Draw display text
  int textWidth = MeasureText(calc->display, 40);
  int textX = SCREEN_WIDTH - textWidth - 20;
  int textY = DISPLAY_HEIGHT - 50;
  DrawText(calc->display, textX, textY, 40, WHITE);

  // Draw buttons
  for (int i = 0; i < 20; i++) {
    Color btnColor =
        buttons[i].pressed ? Fade(buttonColors[i], 0.7f) : buttonColors[i];

    DrawRectangleRounded(buttons[i].rect, 0.3f, 10, btnColor);
    // New (correct for Raylib 5.5):
    DrawRectangleRoundedLines(buttons[i].rect, 0.3f, 10, Fade(DARKGRAY, 0.5f));

    int textWidth = MeasureText(buttons[i].text, 30);
    int textX = buttons[i].rect.x + (buttons[i].rect.width - textWidth) / 2;
    int textY = buttons[i].rect.y + (buttons[i].rect.height - 30) / 2;

    DrawText(buttons[i].text, textX, textY, 30, buttons[i].textColor);
  }

  // Draw operation indicator
  if (calc->operation != '\0') {
    char opText[2] = {calc->operation, '\0'};
    DrawText(opText, 20, DISPLAY_HEIGHT - 50, 30, ORANGE);
  }
}

int main(void) {
  InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Raylib Calculator");
  SetTargetFPS(60);

  Calculator calc;
  InitCalculator(&calc);

  Button buttons[20];

  // Initialize buttons
  int index = 0;
  for (int row = 0; row < 5; row++) {
    for (int col = 0; col < 4; col++) {
      index = row * 4 + col;

      // Special case: 0 button spans two columns
      if (index == 16) { // Row 4, Col 0 → spans Col 0 & 1
        buttons[index].rect =
            (Rectangle){col * (BUTTON_WIDTH + BUTTON_MARGIN) + BUTTON_MARGIN,
                        row * (BUTTON_HEIGHT + BUTTON_MARGIN) + DISPLAY_HEIGHT +
                            BUTTON_MARGIN,
                        BUTTON_WIDTH * 2 + BUTTON_MARGIN, BUTTON_HEIGHT};
      } else {
        buttons[index].rect =
            (Rectangle){col * (BUTTON_WIDTH + BUTTON_MARGIN) + BUTTON_MARGIN,
                        row * (BUTTON_HEIGHT + BUTTON_MARGIN) + DISPLAY_HEIGHT +
                            BUTTON_MARGIN,
                        BUTTON_WIDTH, BUTTON_HEIGHT};
      }

      // Skip drawing the button at position 17 (where '.' is) if it's
      // overlapped by '0' But we still want button 17 ('.') to exist, so just
      // reposition it correctly

      strncpy(buttons[index].text, buttonLabels[index],
              sizeof(buttons[index].text) - 1);
      buttons[index].textColor = (ColorIsEqual(buttonColors[index], DARKGRAY) ||
                                  ColorIsEqual(buttonColors[index], ORANGE))
                                     ? WHITE
                                     : BLACK;
      buttons[index].pressed = false;
    }
  }

  // Manually fix the position of the '.' button (index 17), since '0' takes two
  // spots
  buttons[17].rect = (Rectangle){
      2 * (BUTTON_WIDTH + BUTTON_MARGIN) + BUTTON_MARGIN,
      4 * (BUTTON_HEIGHT + BUTTON_MARGIN) + DISPLAY_HEIGHT + BUTTON_MARGIN,
      BUTTON_WIDTH, BUTTON_HEIGHT};

  // Also fix '=' button (index 18) to be in column 3, row 4
  buttons[18].rect = (Rectangle){
      3 * (BUTTON_WIDTH + BUTTON_MARGIN) + BUTTON_MARGIN,
      4 * (BUTTON_HEIGHT + BUTTON_MARGIN) + DISPLAY_HEIGHT + BUTTON_MARGIN,
      BUTTON_WIDTH, BUTTON_HEIGHT};

  while (!WindowShouldClose()) {
    // Update button states
    Vector2 mousePos = GetMousePosition();

    for (int i = 0; i < 20; i++) {
      bool wasPressed = buttons[i].pressed;
      buttons[i].pressed = CheckCollisionPointRec(mousePos, buttons[i].rect) &&
                           IsMouseButtonDown(MOUSE_LEFT_BUTTON);

      // Detect button release (click)
      if (wasPressed && !buttons[i].pressed &&
          CheckCollisionPointRec(mousePos, buttons[i].rect)) {
        ProcessButtonPress(&calc, i);
      }
    }

    // Handle keyboard input
    int key = GetKeyPressed();
    if (key >= KEY_ZERO && key <= KEY_NINE) {
      int digit = key - KEY_ZERO;
      int buttonIndex =
          (digit == 0) ? 16 : (13 - (9 - digit)); // 7→4, 8→5, 9→6, ..., 0→16
      ProcessButtonPress(&calc, buttonIndex);
    }

    if (key == KEY_KP_EQUAL || key == KEY_ENTER || key == KEY_EQUAL) {
      ProcessButtonPress(&calc, 18); // = button
    }
    if (key == KEY_ESCAPE || key == KEY_C) {
      ProcessButtonPress(&calc, 0); // C button
    }
    if (key == KEY_BACKSPACE || key == KEY_DELETE) {
      ProcessButtonPress(&calc, 19); // ⌫ button
    }
    if (key == KEY_PERIOD || key == KEY_KP_DECIMAL) {
      ProcessButtonPress(&calc, 17); // . button
    }
    // Addition
    if (key == KEY_KP_ADD || (key == KEY_EQUAL && IsKeyDown(KEY_LEFT_SHIFT))) {
      ProcessButtonPress(&calc, 15); // + button
    }

    // Subtraction
    if (key == KEY_KP_SUBTRACT || key == KEY_MINUS) {
      ProcessButtonPress(&calc, 11); // - button
    }

    // Multiplication (only numpad *)
    if (key == KEY_KP_MULTIPLY) {
      ProcessButtonPress(&calc, 7); // × button
    }

    // Division
    if (key == KEY_KP_DIVIDE || key == KEY_SLASH) {
      ProcessButtonPress(&calc, 3); // ÷ button
    }
    BeginDrawing();
    ClearBackground((Color){60, 60, 60, 255});

    DrawCalculator(&calc, buttons);

    DrawText("Calculator - Use mouse or keyboard", 10, SCREEN_HEIGHT - 25, 20,
             LIGHTGRAY);

    EndDrawing();
  }

  CloseWindow();
  return 0;
}
