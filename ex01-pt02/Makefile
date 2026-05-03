# --- Configuration ---
WIDTH      ?= 3840
HEIGHT     ?= 2160
MAX_ITER   ?= 1024
C_REAL     ?= -0.8
C_IMAG     ?= 0.156

TARGET     = julia_set
BUILD_DIR  = ./build
PNG_DIR    = ./pngs

NVCC       = nvc++
NVCC_FLAGS = -O3 -cuda

# This creates a unique name: e.g., julia_r-0.8_i0.156_it1024.png
OUT_NAME   = julia_r$(C_REAL)_i$(C_IMAG)_it$(MAX_ITER).png

.PHONY: all clean run

all: $(BUILD_DIR)/$(TARGET)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(PNG_DIR):
	mkdir -p $(PNG_DIR)

$(BUILD_DIR)/julia.o: julia.cu | $(BUILD_DIR)
	$(NVCC) $(NVCC_FLAGS) -c $< -o $@

$(BUILD_DIR)/lodepng.o: lodepng.cpp | $(BUILD_DIR)
	g++ -O3 -c $< -o $@

$(BUILD_DIR)/$(TARGET): $(BUILD_DIR)/julia.o $(BUILD_DIR)/lodepng.o
	$(NVCC) $(NVCC_FLAGS) $^ -o $@

# New Run Command: Passes the filename as the 6th argument
run: all | $(PNG_DIR)
	@echo "Generating: $(OUT_NAME)"
	$(BUILD_DIR)/$(TARGET) $(WIDTH) $(HEIGHT) $(MAX_ITER) $(C_REAL) $(C_IMAG) $(PNG_DIR)/$(OUT_NAME)
	@echo "Done! Saved to $(PNG_DIR)/$(OUT_NAME)"

clean:
	rm -rf $(BUILD_DIR) $(PNG_DIR)
