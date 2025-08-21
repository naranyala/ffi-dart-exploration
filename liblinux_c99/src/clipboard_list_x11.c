#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <X11/Xlib.h>
#include <X11/Xatom.h>
#include <sys/select.h>
#include <unistd.h>

int main(void) {
    Display *display = XOpenDisplay(NULL);
    if (!display) {
        fprintf(stderr, "Cannot open X display\n");
        return 1;
    }

    Window window = XCreateSimpleWindow(display, DefaultRootWindow(display),
                                        0, 0, 1, 1, 0, 0, 0);
    if (!window) {
        fprintf(stderr, "Failed to create window\n");
        XCloseDisplay(display);
        return 1;
    }

    // Get the necessary atoms
    Atom clipboard = XInternAtom(display, "CLIPBOARD", False);
    Atom utf8 = XInternAtom(display, "UTF8_STRING", False);
    Atom string = XInternAtom(display, "STRING", False);
    Atom property = XInternAtom(display, "XSEL_DATA", False);

    // Request the clipboard content
    XConvertSelection(display, clipboard, utf8, property, window, CurrentTime);
    XFlush(display);

    // Set up timeout for event waiting
    fd_set fds;
    struct timeval timeout;
    int x11_fd = ConnectionNumber(display);

    timeout.tv_sec = 5;  // 5 second timeout
    timeout.tv_usec = 0;

    FD_ZERO(&fds);
    FD_SET(x11_fd, &fds);

    XEvent event;
    int selection_received = 0;

    // Wait for events with timeout
    while (!selection_received) {
        // Check if there are pending X11 events
        if (XPending(display) > 0) {
            XNextEvent(display, &event);

            if (event.type == SelectionNotify) {
                selection_received = 1;

                if (event.xselection.property == None) {
                    fprintf(stderr, "Clipboard data unavailable or conversion failed\n");
                    // Try fallback to STRING type
                    XConvertSelection(display, clipboard, string, property, window, CurrentTime);
                    XFlush(display);
                    selection_received = 0;  // Wait for another response
                    continue;
                }

                Atom actual_type;
                int actual_format;
                unsigned long nitems, bytes_after;
                unsigned char *data = NULL;

                int result = XGetWindowProperty(display, window, property, 0, (~0L), True,
                                              AnyPropertyType, &actual_type, &actual_format,
                                              &nitems, &bytes_after, &data);

                if (result == Success && data) {
                    if (actual_format == 8 && nitems > 0) {
                        // Ensure null termination
                        printf("Clipboard contents:\n%.*s\n", (int)nitems, data);
                    } else {
                        fprintf(stderr, "Unexpected data format: %d bits, %lu items\n",
                               actual_format, nitems);
                    }
                    XFree(data);
                } else {
                    fprintf(stderr, "Failed to get window property: %d\n", result);
                }
            }
        } else {
            // Use select to wait with timeout
            FD_ZERO(&fds);
            FD_SET(x11_fd, &fds);
            timeout.tv_sec = 5;
            timeout.tv_usec = 0;

            int ready = select(x11_fd + 1, &fds, NULL, NULL, &timeout);
            if (ready == 0) {
                fprintf(stderr, "Timeout waiting for clipboard data\n");
                break;
            } else if (ready < 0) {
                perror("select failed");
                break;
            }
        }
    }

    XDestroyWindow(display, window);
    XCloseDisplay(display);
    return 0;
}
