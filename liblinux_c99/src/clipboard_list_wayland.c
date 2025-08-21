#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/wait.h>

// Function to execute command and capture output
char* execute_command(const char* command) {
    FILE* fp = popen(command, "r");
    if (!fp) {
        return NULL;
    }

    // Read output into buffer
    char* result = NULL;
    size_t len = 0;
    size_t capacity = 1024;
    result = malloc(capacity);
    if (!result) {
        pclose(fp);
        return NULL;
    }

    char buffer[256];
    while (fgets(buffer, sizeof(buffer), fp)) {
        size_t buffer_len = strlen(buffer);
        if (len + buffer_len >= capacity) {
            capacity *= 2;
            char* temp = realloc(result, capacity);
            if (!temp) {
                free(result);
                pclose(fp);
                return NULL;
            }
            result = temp;
        }
        strcpy(result + len, buffer);
        len += buffer_len;
    }

    int exit_code = pclose(fp);
    if (exit_code != 0) {
        free(result);
        return NULL;
    }

    // Remove trailing newline if present
    if (len > 0 && result[len-1] == '\n') {
        result[len-1] = '\0';
    }

    return result;
}

// Check if a command exists in PATH
int command_exists(const char* command) {
    char check_cmd[256];
    snprintf(check_cmd, sizeof(check_cmd), "command -v %s >/dev/null 2>&1", command);
    return system(check_cmd) == 0;
}

int main(void) {
    char* clipboard_content = NULL;

    // Detect display server and try appropriate methods
    if (getenv("WAYLAND_DISPLAY")) {
        // We're on Wayland
        if (command_exists("wl-paste")) {
            clipboard_content = execute_command("wl-paste 2>/dev/null");
        }

        if (!clipboard_content && command_exists("cliphist")) {
            // Alternative Wayland clipboard manager
            clipboard_content = execute_command("cliphist list | head -1 | cliphist decode");
        }

    } else if (getenv("DISPLAY")) {
        // We're on X11
        if (command_exists("xclip")) {
            clipboard_content = execute_command("xclip -selection clipboard -o 2>/dev/null");
        } else if (command_exists("xsel")) {
            clipboard_content = execute_command("xsel --clipboard --output 2>/dev/null");
        }
    }

    // Fallback attempts for edge cases
    if (!clipboard_content) {
        // Try wl-paste even if WAYLAND_DISPLAY isn't set (some setups)
        if (command_exists("wl-paste")) {
            clipboard_content = execute_command("wl-paste 2>/dev/null");
        }

        // Try xclip even if DISPLAY isn't set (some SSH X11 forwarding setups)
        if (!clipboard_content && command_exists("xclip")) {
            clipboard_content = execute_command("xclip -selection clipboard -o 2>/dev/null");
        }
    }

    // Display results
    if (clipboard_content && strlen(clipboard_content) > 0) {
        printf("%s\n", clipboard_content);
        free(clipboard_content);
        return 0;
    } else {
        fprintf(stderr, "No clipboard content available or clipboard tools not found.\n");
        fprintf(stderr, "\nRequired tools:\n");
        fprintf(stderr, "  For Wayland: wl-clipboard (wl-paste command)\n");
        fprintf(stderr, "  For X11: xclip or xsel\n");
        fprintf(stderr, "\nInstall with:\n");
        fprintf(stderr, "  Ubuntu/Debian: sudo apt install wl-clipboard xclip\n");
        fprintf(stderr, "  Fedora: sudo dnf install wl-clipboard xclip\n");
        fprintf(stderr, "  Arch: sudo pacman -S wl-clipboard xclip\n");

        if (clipboard_content) {
            free(clipboard_content);
        }
        return 1;
    }
}
