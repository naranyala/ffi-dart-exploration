#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int get_bluetooth_state(void) {
    FILE *fp = popen("bluetoothctl show | grep Powered", "r");
    if (!fp) {
        perror("Failed to run bluetoothctl");
        return -1;
    }

    char line[256];
    int state = -1;
    if (fgets(line, sizeof(line), fp)) {
        if (strstr(line, "Powered: yes")) {
            state = 0; // ON
        } else if (strstr(line, "Powered: no")) {
            state = 1; // OFF
        }
    }

    pclose(fp);
    if (state == -1) {
        fprintf(stderr, "Failed to determine Bluetooth state\n");
    }
    return state;
}

int set_bluetooth_state(int power_on) {
    char *cmd = power_on ? "bluetoothctl power on" : "bluetoothctl power off";
    if (system(cmd) != 0) {
        fprintf(stderr, "Failed to turn Bluetooth %s\n", power_on ? "on" : "off");
        return -1;
    }

    // Allow time for state change to propagate
    usleep(500000); // 500ms delay

    // Verify state
    int new_state = get_bluetooth_state();
    if (new_state != !power_on) {
        fprintf(stderr, "Bluetooth state change failed: expected %s, got %s\n",
                power_on ? "ON" : "OFF", new_state ? "OFF" : "ON");
        return -1;
    }
    return 0;
}

int main(void) {
    // Ensure bluetoothd is running
    if (system("systemctl is-active --quiet bluetooth") != 0) {
        fprintf(stderr, "Bluetooth service is not active. Starting it...\n");
        if (system("sudo systemctl start bluetooth") != 0) {
            fprintf(stderr, "Failed to start bluetooth service\n");
            return 1;
        }
    }

    int current_state = get_bluetooth_state();
    if (current_state < 0) {
        return 1;
    }

    printf("Bluetooth is currently %s\n", current_state ? "OFF" : "ON");

    int new_state = !current_state;
    if (set_bluetooth_state(!new_state) == 0) {
        printf("Bluetooth has been turned %s\n", new_state ? "OFF" : "ON");
    } else {
        return 1;
    }

    return 0;
}
