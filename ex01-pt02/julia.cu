#define __STRICT_ANSI__
#include <cuda_runtime.h>
#include <stdio.h>
#include <vector>
#include <cstdint>

#include "lodepng.h"

#define FNAME "julia.png"

// Image dimensions
#define WIDTH  1920
#define HEIGHT 1080
#define MAX_ITER 128
#define THRESHOLD 10.0f

// Julia set constant c = -0.8 + 0.2i
#define C_REAL -0.8f
#define C_IMAG  0.2f

// Domain: [-2, 2] x [-2, 2] scaled to image aspect ratio
#define DOMAIN_MIN_X -2.0f
#define DOMAIN_MAX_X  2.0f
#define DOMAIN_MIN_Y -1.125f
#define DOMAIN_MAX_Y  1.125f

__device__ void iterToColor(int iter, int maxIter, uint8_t &r, uint8_t &g, uint8_t &b) {
    if (iter == maxIter) {
        // Inside set → black
        r = g = b = 0;
        return;
    }
    // Smooth color mapping using sine waves for vivid colors
    float t = (float)iter / (float)maxIter;
    r = (uint8_t)(9   * (1 - t) * t * t * t * 255);
    g = (uint8_t)(15  * (1 - t) * (1 - t) * t * t * 255);
    b = (uint8_t)(8.5 * (1 - t) * (1 - t) * (1 - t) * t * 255);
}

__global__ void juliaKernel(uint8_t *image, int width, int height, int maxIter,
                             float cReal, float cImag,
                             float domainMinX, float domainMaxX,
                             float domainMinY, float domainMaxY) {
    int px = blockIdx.x * blockDim.x + threadIdx.x;
    int py = blockIdx.y * blockDim.y + threadIdx.y;

    if (px >= width || py >= height) return;

    // Map pixel to complex plane
    float zReal = domainMinX + (domainMaxX - domainMinX) * px / (float)(width  - 1);
    float zImag = domainMinY + (domainMaxY - domainMinY) * py / (float)(height - 1);

    int iter = 0;
    while (iter < maxIter && (zReal * zReal + zImag * zImag) < THRESHOLD * THRESHOLD) {
        float newReal = zReal * zReal - zImag * zImag + cReal;
        float zImag2  = 2.0f * zReal * zImag + cImag;
        zReal = newReal;
        zImag = zImag2;
        ++iter;
    }

    uint8_t r, g, b;
    iterToColor(iter, maxIter, r, g, b);

    int idx = (py * width + px) * 4;
    image[idx + 0] = r;
    image[idx + 1] = g;
    image[idx + 2] = b;
    image[idx + 3] = 255; // alpha
}

int main(int argc, char *argv[]) {
    int width    = WIDTH;
    int height   = HEIGHT;
    int maxIter  = MAX_ITER;
    float cReal  = C_REAL;
    float cImag  = C_IMAG;
    const char *fname = FNAME;

    // Optional CLI overrides: width height maxIter cReal cImag
    if (argc > 1) width   = atoi(argv[1]);
    if (argc > 2) height  = atoi(argv[2]);
    if (argc > 3) maxIter = atoi(argv[3]);
    if (argc > 4) cReal   = atof(argv[4]);
    if (argc > 5) cImag   = atof(argv[5]);
    if (argc > 6) fname   =       argv[6];

    printf("Julia set: %dx%d, maxIter=%d, c=%.4f+%.4fi\n",
           width, height, maxIter, cReal, cImag);

    size_t imageSize = width * height * 4 * sizeof(uint8_t);

    // Allocate GPU memory
    uint8_t *d_image;
    cudaMalloc(&d_image, imageSize);

    // 2D block/grid
    dim3 blockSize(16, 16);
    dim3 gridSize((width  + blockSize.x - 1) / blockSize.x,
                  (height + blockSize.y - 1) / blockSize.y);

    // Timing
    cudaEvent_t start, stop;
    cudaEventCreate(&start);
    cudaEventCreate(&stop);

    cudaEventRecord(start);
    juliaKernel<<<gridSize, blockSize>>>(
        d_image, width, height, maxIter,
        cReal, cImag,
        DOMAIN_MIN_X, DOMAIN_MAX_X,
        DOMAIN_MIN_Y, DOMAIN_MAX_Y
    );
    cudaEventRecord(stop);
    cudaEventSynchronize(stop);

    float ms = 0.0f;
    cudaEventElapsedTime(&ms, start, stop);
    printf("Kernel time: %.3f ms\n", ms);

    // Copy result back
    std::vector<uint8_t> image(width * height * 4);
    cudaMemcpy(image.data(), d_image, imageSize, cudaMemcpyDeviceToHost);

    // Save as PNG
    unsigned error = lodepng::encode(fname, image, width, height);
    if (error)
        printf("lodepng error %u: %s\n", error, lodepng_error_text(error));
    else
        printf("Saved: %s\n", fname);

    cudaEventDestroy(start);
    cudaEventDestroy(stop);
    cudaFree(d_image);

    return 0;
}
