//
//  test.h
//  gpuqp_cuda
//
//  Created by Zhuohang Lai on 01/19/16.
//  Copyright (c) 2015-2016 Zhuohang Lai. All rights reserved.
//
#ifndef __TEST_H__
#define __TEST_H__

#include "kernels.h"

void test_bandwidth();
bool testScan_thrust(int len, float& totalTime, int isExclusive);

template<class T> bool testMap( 
#ifdef RECORDS
	int *source_keys, 
#endif
	T *source_values, int r_len, 
	float& totalTime, int blockSize=BLOCKSIZE, int gridSize=GRIDSIZE);

template<class T> bool testGather( 
#ifdef RECORDS
	int *source_keys, 
#endif
	T *source_values, int r_len, int* loc,
	float& totalTime, int blockSize=BLOCKSIZE, int gridSize=GRIDSIZE);

template<class T> bool testGather_mul( 
#ifdef RECORDS
	int *source_keys, 
#endif
	T *source_values, int r_len, int* loc,
	float& totalTime, int blockSize=BLOCKSIZE, int gridSize=GRIDSIZE);

template<class T> bool testScatter( 
#ifdef RECORDS
	int *source_keys, 
#endif
	T *source_values, int r_len, int* loc,
	float& totalTime, int blockSize=BLOCKSIZE, int gridSize=GRIDSIZE);

template<class T> bool testScatter_mul( 
#ifdef RECORDS
	int *source_keys, 
#endif
	T *source_values, int r_len, int* loc,
	float& totalTime, int blockSize=BLOCKSIZE, int gridSize=GRIDSIZE);

template<class T> bool testSplit(
#ifdef RECORDS
	int *source_keys, 
#endif
	T *source_values,int r_len, float& totalTime,  
	int fanout, int blockSize=BLOCKSIZE, int gridSize=GRIDSIZE); 

template<typename T>
bool testScan_warp(T *source, int r_len, float& totalTime, int isExclusive,  int blockSize=BLOCKSIZE, int gridSize=GRIDSIZE);

template<typename T>
bool testScan_ble(T *source, int r_len, float& totalTime, int isExclusive,  int blockSize=BLOCKSIZE, int gridSize=GRIDSIZE);

template<typename T>
bool testRadixSort(
#ifdef RECORDS
	int *source_keys, 
#endif
	T *source_values, int len, float& totalTime);

bool testBisort(Record *source, int r_len, double& totalTime,int dir, int blockSize=BLOCKSIZE, int gridSize=GRIDSIZE);



//new version
bool testScan_thrust(int len, float& totalTime, int isExclusive);

#endif