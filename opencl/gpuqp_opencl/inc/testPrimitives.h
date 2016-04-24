//
//  testPrimitives.h
//  gpuqp_opencl
//
//  Created by Bryan on 5/21/15.
//  Copyright (c) 2015 Bryan. All rights reserved.
//

#ifndef gpuqp_opencl_testPrimitives_h
#define gpuqp_opencl_testPrimitives_h

#include "Foundation.h"

bool testMap(
#ifdef RECORDS
    int *fixedKeys,
#endif
    int *fixedValues, 
    int length, PlatInfo info , double& totalTime, int localSize=BLOCKSIZE, int gridSize=GRIDSIZE);

bool testGather(
#ifdef RECORDS
    int *fixedKeys,
#endif
    int *fixedValues, int length, PlatInfo info , double& totalTime, int localSize=BLOCKSIZE, int gridSize=GRIDSIZE);

bool testScatter(
#ifdef RECORDS
    int *fixedKeys,
#endif
    int *fixedValues, int length, PlatInfo info , double& totalTime, int localSize=BLOCKSIZE, int gridSize=GRIDSIZE);

bool testRadixSort(
#ifdef RECORDS
    int *fixedKeys,
#endif
    int *fixedValues, 
    int length, PlatInfo info, double& totalTime);

bool testScan(int *fixedSource, int length, PlatInfo info, double& totalTime, int isExclusive, int localSize = BLOCKSIZE);
bool testSplit(Record *fixedSource, int length, PlatInfo info , int fanout, double& totalTime, int localSize= BLOCKSIZE, int gridSize = GRIDSIZE);
bool testBitonitSort(Record *fixedSource, int length, PlatInfo info, int dir, double& totalTime, int localSize = BLOCKSIZE, int gridSize = GRIDSIZE);
#endif
