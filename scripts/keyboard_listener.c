#define _DEFAULT_SOURCE // Required for usleep
#include <stdio.h>
#include <fcntl.h>
#include <errno.h>
#include <string.h> 
#include <unistd.h>
#include <stdlib.h> 
#include <libinput.h>
#include <libudev.h>
#include <linux/input-event-codes.h>

// This is a required callback function for libinput.
// It opens a device file path.
static int open_restricted(const char *path, int flags, void *user_data) {
    (void)user_data; // Suppress unused parameter warning
    int fd = open(path, flags);
    if (fd < 0) {
        fprintf(stderr, "Failed to open %s (%s)\n", path, strerror(errno));
    }
    return fd < 0 ? -errno : fd;
}

// This is another required callback function.
// It simply closes a file descriptor.
static void close_restricted(int fd, void *user_data) {
    (void)user_data; // Suppress unused parameter warning
    close(fd);
}

// The interface struct with our callback functions.
static const struct libinput_interface interface = {
    .open_restricted = open_restricted,
    .close_restricted = close_restricted,
};

int main(void) {
    struct libinput *li;
    struct libinput_event *event;
    struct udev *udev = udev_new();

    if (!udev) {
        fprintf(stderr, "Failed to initialize udev\n");
        return 1;
    }
    printf("udev context created successfully.\n");

    li = libinput_udev_create_context(&interface, NULL, udev);
    if (!li) {
        fprintf(stderr, "Failed to initialize libinput from udev\n");
        udev_unref(udev);
        return 1;
    }
    printf("libinput context created successfully.\n");

    if (libinput_udev_assign_seat(li, "seat0") != 0) {
        fprintf(stderr, "Failed to assign seat 'seat0'.\n");
        libinput_unref(li);
        udev_unref(udev);
        return 1;
    }
    printf("Assigned to seat0 successfully.\n");


    printf("\nListening for events... Press any key. Press Ctrl+C to exit.\n");
    fflush(stdout);

    // Main event loop
    while (1) {
        libinput_dispatch(li); // Process available events
        event = libinput_get_event(li);

        if (!event) {
            usleep(1000);
            continue;
        }

        enum libinput_event_type type = libinput_event_get_type(event);

        if (type == LIBINPUT_EVENT_DEVICE_ADDED) {
            struct libinput_device *device = libinput_event_get_device(event);
            printf("--- DEVICE ADDED ---\n");
            printf("  Name: %s\n", libinput_device_get_name(device));
            if (libinput_device_has_capability(device, LIBINPUT_DEVICE_CAP_KEYBOARD)) {
                printf("  This device IS a keyboard.\n");
            } else {
                printf("  This device is NOT a keyboard.\n");
            }
	    if (libinput_device_has_capability(device, LIBINPUT_DEVICE_CAP_POINTER)) {
                printf("  This device IS a mouse/pointer.\n");
	    }
            printf("--------------------\n");
        }


        if (type == LIBINPUT_EVENT_KEYBOARD_KEY) {
            struct libinput_event_keyboard *key_event = libinput_event_get_keyboard_event(event);
            enum libinput_key_state key_state = libinput_event_keyboard_get_key_state(key_event);
            uint32_t key_code = libinput_event_keyboard_get_key(key_event);
            
            if (key_state == LIBINPUT_KEY_STATE_PRESSED) {
         	printf("%u\n", key_code);

                // --- NEW EFFICIENT METHOD ---
                // 1. Create a buffer to hold the command string.
                char command[256];

                // 2. Format the command into the buffer using snprintf.
                snprintf(command, sizeof(command), "echo %u > /tmp/input_key.txt", key_code);

                // 3. Execute the fully formed command.
                int return_value = system(command);
                if (return_value != 0) {
                    fprintf(stderr, "Command execution failed!\n");
                }
            }
        }
	if (type == LIBINPUT_EVENT_POINTER_AXIS) {
            struct libinput_event_pointer *pointer_event = libinput_event_get_pointer_event(event);
            
            // Check if the event is for the vertical scroll axis
            if (libinput_event_pointer_has_axis(pointer_event, LIBINPUT_POINTER_AXIS_SCROLL_VERTICAL)) {
                double scroll_value = libinput_event_pointer_get_axis_value(pointer_event, LIBINPUT_POINTER_AXIS_SCROLL_VERTICAL);
                const char* direction = "unknown";
                
                if (scroll_value < 0) {
                    direction = "up";
                    printf("%s\n", direction);
                } else if (scroll_value > 0) {
                    direction = "down";
                    printf("%s\n", direction);
                }
                
                char command[256];
                snprintf(command, sizeof(command), "echo %s > /tmp/input_key.txt", direction);
                system(command);
            }
        }

	if (type == LIBINPUT_EVENT_POINTER_BUTTON) {
            struct libinput_event_pointer *pointer_event = libinput_event_get_pointer_event(event);
            enum libinput_button_state button_state = libinput_event_pointer_get_button_state(pointer_event);
            
            if (button_state == LIBINPUT_BUTTON_STATE_PRESSED) {
                uint32_t button_code = libinput_event_pointer_get_button(pointer_event);
                const char* button_name = "unknown";

                switch (button_code) {
                    case BTN_LEFT:
                        button_name = "left";
                        printf("%s\n", button_name);
                        break;
                    case BTN_RIGHT:
                        button_name = "right";
                        printf("%s\n", button_name);
                        break;
                    case BTN_MIDDLE:
                        button_name = "middle";
                        printf("%s\n", button_name);
                        break;
                }

                char command[256];
                snprintf(command, sizeof(command), "echo %s > /tmp/input_key.txt", button_name);
                system(command);
            }
        }
        libinput_event_destroy(event);
        fflush(stdout); // Flush after every event for immediate feedback
    }

    // Clean up
    libinput_unref(li);
    udev_unref(udev);

    return 0;
}


