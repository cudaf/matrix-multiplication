#include <cuda_runtime.h>
#include <device_launch_parameters.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "support.h"




__global__ void kernel_tiled(float *a, float *x, float *y, int xr, int xc, int yc) {
  __shared__ float as[BY*BX];
  __shared__ float xs[BY*BX];
  __shared__ float ys[BY*BX];
  int r = by*BY + ty;
  int c = bx*BX + tx;
  as[ty][tx] = 0;
  for (int i=0; i<xc; i+=BX) {
    __syncthreads();
    xs[ty][tx] = x[by*BY + ty][bx*BX + i+tx];
    ys[ty][tx] = y[by*BY + i+ty][bx*BX + tx];
    __syncthreads();
    for (int j=0; j<BX; j++)
      as[ty][tx] += xs[ty][j] * ys[j][tx];
  }
  __syncthreads();
  a[by*BY + ty][bx*BX + tx] = as[ty][tx];
}




float test_tiled(float *a, float *x, float *y, int xr, int xc, int yc) {
  int A1 = xr * yc * sizeof(float);
  int X1 = xr * xc * sizeof(float);
  int Y1 = xc * yc * sizeof(float);

  cudaEvent_t start, stop;
  TRY( cudaEventCreate(&start) );
  TRY( cudaEventCreate(&stop) );

  void *aD, *xD, *yD;
  TRY( cudaMalloc(&aD, A1) );
  TRY( cudaMalloc(&xD, X1) );
  TRY( cudaMalloc(&yD, Y1) );

  TRY( cudaMemcpy(xD, x, X1, cudaMemcpyHostToDevice) );
  TRY( cudaMemcpy(yD, y, Y1, cudaMemcpyHostToDevice) );

  dim3 threads(16, 16);
  dim3 blocks(CEILDIV(xr, 16), CEILDIV(yc, 16));
  kernel_tiled<<<blocks, threads>>>(aD, xD, yD, xr, xc, yc);

  TRY( cudaMemcpy(a, aD, A1, cudaMemcpyDeviceToHost) );

  float duration;
  TRY( cudaEventRecord(stop, 0) );
  TRY( cudaEventSynchronize(stop); );
  TRY( cudaEventElapsedTime(&duration, start, stop) );

  TRY( cudaEventDestroy(start) );
  TRY( cudaEventDestroy(stop) );
  TRY( cudaFree(yD) );
  TRY( cudaFree(xD) );
  TRY( cudaFree(aD) );
  return duration;
}



int main() {
  int size = 10 * 1024 * 1024;

  printf("CPU malloc -> CPU malloc: %3.1f ms\n",
    test_malloc(size));
  printf("\n");

  printf("CPU malloc -> GPU cudaMalloc: %3.1f ms\n",
    test_cuda_malloc(size, 1));
  printf("CPU malloc <- GPU cudaMalloc: %3.1f ms\n",
    test_cuda_malloc(size, 0));
  printf("\n");

  printf("CPU cudaHostAlloc -> GPU cudaMalloc: %3.1f ms\n",
    test_cuda_host_alloc(size, 1));
  printf("CPU cudaHostAlloc <- GPU cudaMalloc: %3.1f ms\n",
    test_cuda_host_alloc(size, 0));
  return 0;
}
