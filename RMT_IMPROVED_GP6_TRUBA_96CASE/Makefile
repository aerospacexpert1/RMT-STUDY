CC ?= gcc
CFLAGS ?= -O3 -march=native -std=c11 -Wall -Wextra -Wpedantic -fopenmp
LDLIBS ?= -lm

TARGET := build/opposedflow_rmt_improved
SOURCE := src/opposedflow_rmt_improved.c

.PHONY: all clean syntax
all: $(TARGET)

$(TARGET): $(SOURCE)
	@mkdir -p build
	$(CC) $(CFLAGS) $(SOURCE) $(LDLIBS) -o $(TARGET)

syntax:
	$(CC) -std=c11 -Wall -Wextra -Wpedantic -fopenmp -fsyntax-only $(SOURCE)

clean:
	rm -rf build
