#
//  Makefile
//  Metal2DTo3D
//
//  Created by Siddh Javeri on 10/1/25.
//

PROJECT_NAME = Metal2DTo3D
EXECUTABLE = .build/release/$(PROJECT_NAME)

.PHONY: all build run clean test

all: build

# Builds the release version of the project
build:
	@echo "Building $(PROJECT_NAME)..."
	swift build -c release --product $(PROJECT_NAME)

# Runs the project
run: build
	@echo "Running $(PROJECT_NAME)..."
	@$(EXECUTABLE)

# Cleans all build artifacts and outputs
clean:
	@echo "Cleaning project..."
	swift package clean
	rm -rf .build Outputs

# Runs the test suite
test: build
	@echo "Running test suite..."
	@$(EXECUTABLE) --test-all
