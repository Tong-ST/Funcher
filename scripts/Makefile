# Makefile for compiling the libinput

CC = gcc
CFLAGS = -Wall -Wextra -std=c99
# pkg-config is used to get the correct compiler and linker flags
LDFLAGS = $(shell pkg-config --libs libinput libudev)
CFLAGS += $(shell pkg-config --cflags libinput libudev)

TARGET = keyboard_listener

.PHONY: all clean

all: $(TARGET)

$(TARGET): keyboard_listener.c
	$(CC) $(CFLAGS) -o $(TARGET) keyboard_listener.c $(LDFLAGS)

clean:
	rm -f $(TARGET)
