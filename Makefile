
# Variables
ZIG=zig
SRC=src/main.zig
OUT=main

# Default target: Build and run
all: buildpgsql run

# Build the Zig PGSQL
buildpgsql:
	zig build-exe -I./src -I/opt/homebrew/opt/libpq/include \
    src/main.zig -L/opt/homebrew/opt/libpq/lib -lpq -femit-bin=./main

# Run the built executable
run:
	./$(OUT)

# Clean up the built executable
clean:
	rm -f $(OUT)

.PHONY: all build run clean

