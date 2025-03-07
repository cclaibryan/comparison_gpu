//
//  radixSort.cu
//  OpenCL-Primitives
//
//  Created by Zhuohang Lai on 01/26/16.
//  Copyright (c) 2015-2016 Zhuohang Lai. All rights reserved.
//

/*pay attention:
 * The ScatterData data structure may use char to record number count for speeding up. If the count is >= 256, it will cause problem!
 *  So a tile should not contain too many elements, i.e, SCATTER_ELE_PER_TILE should not be too large.
 *
 */
#include "kernels.h"
#include "dataDef.h"

using namespace std;

/*
 *                          Fast radix sort
 *
 *          1. each block count histograms and reduce
 *          2. grid-wise exclusive scan on the histrograms
 *          3. each block does scatter according to the histograms
 *
 **/

template<typename T>
__global__ void radix_reduce(   
    T *d_source,
    const int total,        //total element length
    const int blockLen,     //len of elements each block should process
    int* histogram,        //size: globalSize * SORT_RADIX
    const int shiftBits)
{
    extern __shared__ int hist[];       

    int localId = threadIdx.x;
    int blockId = blockIdx.x;
    int blockSize = blockDim.x;
    int gridSize = gridDim.x;

    int begin = blockId * blockLen;
    int end = (blockId+1) * blockLen >= total ? total : (blockId+1) * blockLen;
    int mask = SORT_RADIX - 1;

    //initialization: temp size is blockSize * SORT_RADIX
    for(int i = 0; i < SORT_RADIX; i++) {
        hist[i * blockSize + localId ] = 0;
    }
    __syncthreads();

    for(uint i = begin + localId; i < end; i+= blockSize) {
        T current = d_source[i];
        current = (current >> shiftBits) & mask;
        hist[current * blockSize + localId] ++;
    }    
    __syncthreads();

    //reduce
    const uint ratio = blockSize / SORT_RADIX;
    const uint digit = localId / ratio;
    const uint c = localId & ( ratio - 1 );

    uint sum = 0;
    for(int i = 0; i < SORT_RADIX; i++)  sum += hist[digit * blockSize + i * ratio + c];
    __syncthreads();


    hist[digit * blockSize + c] = sum;
    __syncthreads();

#pragma unroll
    for(uint scale = ratio / 2; scale >= 1; scale >>= 1) {
        if ( c < scale ) {
            sum += hist[digit * blockSize + c + scale];
            hist[digit * blockSize + c] = sum;
        }
        __syncthreads();
    }

    //memory write
    if (localId < SORT_RADIX)    histogram[localId * gridSize + blockId] = hist[localId * blockSize];
}

//data structures for storing information for each TILE in a tile
template<typename T>
struct ScatterData{
    unsigned char digits[SCATTER_ELE_PER_TILE];        //store the digits 
    unsigned char shuffle[SCATTER_ELE_PER_TILE];       //the positions that each elements in the TILE should be scattered to
    unsigned char localHis[SCATTER_TILE_THREAD_NUM * SORT_RADIX];    //store the digit counts for a TILE
    unsigned char countArr[SORT_RADIX];
    uint bias[SORT_RADIX];                           //the global offsets of the radixes in this TILE
    T values[SCATTER_ELE_PER_TILE];
#ifdef RECORDS
    int keys[SCATTER_ELE_PER_TILE];            //store the keys
#endif
} ;

template<typename T>
__global__ void radix_scatter(
#ifdef RECORDS
    int *d_source_keys, int *d_dest_keys, 
#endif
    T *d_source_values, T *d_dest_values,
    int total,
    int tileLen,                //length for each tile(block in reduce)
    int tileNum,                //number of tiles (blocks in reduce)
    int *histogram,
    const int shiftBits
#ifdef RECORDS
    ,bool isRecord
#endif
    )
{
    int localId = threadIdx.x;
    int blockId = blockIdx.x;

    const int lid_in_tile = localId & (SCATTER_TILE_THREAD_NUM - 1);
    const int tile_in_block = localId / SCATTER_TILE_THREAD_NUM;
    const int my_tile_id = blockId * SCATTER_TILES_PER_BLOCK + tile_in_block;   //"my" means for the threads in one tile.

    //shared mem data
    __shared__ ScatterData<T> sharedInfo[SCATTER_TILES_PER_BLOCK];

    uint offset = 0;

    /*each threads with lid_in_tile has an offset recording the first place to write the  
     *element with digit "lid_in_tile" (lid_in_tile < SORT_RADIX)
     *
     * with lid_in_tile >= SORT_RADIX, their offset is always 0, no use
     */
    if (lid_in_tile < SORT_RADIX)    {
        offset = histogram[lid_in_tile * tileNum + my_tile_id];
    }

    int start = my_tile_id * tileLen;
    int stop = start + tileLen;
    int end = stop > total? total : stop;

    if (start >= end)   return;

    //each thread should run all the loops, even have reached the end
    //each iteration is called a TILE.
    for(; start < end; start += SCATTER_ELE_PER_TILE) {
        //each thread processes SCATTER_ELE_PER_THREAD consecutive keys
        //local counts for each thread:
        //recording how many same keys has been visited till now by this thread.
        unsigned char num_of_former_same_keys[SCATTER_ELE_PER_THREAD];

        //address in the localCount for each of the SCATTER_ELE_PER_THREAD element 
        unsigned char address_ele_per_thread[SCATTER_ELE_PER_THREAD];

        //put the global keys of this TILE to the shared memory, coalesced access
        for(uint i = 0; i < SCATTER_ELE_PER_THREAD; i++) {
            const uint lo_id = lid_in_tile + i * SCATTER_TILE_THREAD_NUM;
            const int addr = start + lo_id;
            if (addr >= end)    break;                                     //important to have it to deal with numbers not regular
#ifdef RECORDS
            const int current_key = (addr < end)? d_source_keys[addr] : 0;
            sharedInfo[tile_in_block].keys[lo_id] = current_key;
#endif
            const T current_value = (addr < end)? d_source_values[addr] : (T)0;
            sharedInfo[tile_in_block].values[lo_id] = current_value;
            
            sharedInfo[tile_in_block].digits[lo_id] = ( current_value >> shiftBits ) & (SORT_RADIX - 1);
        }

        //the SCATTER_ELE_PER_TILE threads will cooperate
        //How to cooperate?
        //Each threads read their own consecutive part, check how many same keys
        
        //initiate the localHis array
        for(uint i = 0; i < SORT_RADIX; i++) sharedInfo[tile_in_block].localHis[i * SCATTER_TILE_THREAD_NUM + lid_in_tile] = 0;
        __syncthreads();

        //doing the per-TILE histogram counting
        for(uint i = 0; i < SCATTER_ELE_PER_THREAD; i++) {
            //PAY ATTENTION: Here the shared memory access pattern has changed!!!!!!!
            //instead for coalesced access, here each thread processes consecutive area of 
            //SCATTER_ELE_PER_THREAD elements
            const uint lo_id = lid_in_tile * SCATTER_ELE_PER_THREAD + i;
            if (start + lo_id >= end)    break;                                     //important to have it to deal with numbers not regular

            const unsigned char digit = sharedInfo[tile_in_block].digits[lo_id];
            address_ele_per_thread[i] = digit * SCATTER_TILE_THREAD_NUM + lid_in_tile;
            num_of_former_same_keys[i] = sharedInfo[tile_in_block].localHis[address_ele_per_thread[i]];
            sharedInfo[tile_in_block].localHis[address_ele_per_thread[i]] = num_of_former_same_keys[i] + 1;
        }
        __syncthreads();

        //now what have been saved?
        //1. keys: the keys for this TILE
        //2. digits: the digits for this TILE
        //3. address_ele_per_thread: the address in localCount for each element visited by a thread
        //4. num_of_former_same_keys: # of same keys before this key
        //5. localHis: storing the key counts

        //localHist structure:
        //[SCATTER_TILE_THREAD_NUM for Radix 0][SCATTER_TILE_THREAD_NUM for Radix 1]...

        //now exclusive scan the localHist:
//doing the naive scan:--------------------------------------------------------------------------------------------------------------------------------
        int digitCount = 0;

        if (lid_in_tile < SORT_RADIX) {
            uint localBegin = lid_in_tile * SCATTER_TILE_THREAD_NUM;
            unsigned char prev = sharedInfo[tile_in_block].localHis[localBegin];
            unsigned char now = 0;
            sharedInfo[tile_in_block].localHis[localBegin] = 0;
            for(int i = localBegin + 1; i < localBegin + SCATTER_TILE_THREAD_NUM; i++) {
                now = sharedInfo[tile_in_block].localHis[i];
                sharedInfo[tile_in_block].localHis[i] = sharedInfo[tile_in_block].localHis[i-1] + prev;
                prev = now;
                if (i == localBegin + SCATTER_TILE_THREAD_NUM - 1)  sharedInfo[tile_in_block].countArr[lid_in_tile] = sharedInfo[tile_in_block].localHis[i] + prev;
            }
        }
        __syncthreads();

        if (lid_in_tile < SORT_RADIX)    digitCount = sharedInfo[tile_in_block].countArr[lid_in_tile];

        if (lid_in_tile == 0) {
            //exclusive scan for the countArr
            unsigned char prev = sharedInfo[tile_in_block].countArr[0];
            unsigned char now = 0;
            sharedInfo[tile_in_block].countArr[0] = 0;
            for(uint i = 1; i < SORT_RADIX; i++) {
                now = sharedInfo[tile_in_block].countArr[i];
                sharedInfo[tile_in_block].countArr[i] = sharedInfo[tile_in_block].countArr[i-1] + prev;
                prev = now;
            }
        }
        __syncthreads();

        if ( lid_in_tile < SORT_RADIX) {
            //scan add back
            uint localBegin = lid_in_tile * SCATTER_TILE_THREAD_NUM;
            for(uint i = localBegin; i < localBegin + SCATTER_TILE_THREAD_NUM; i++)
                sharedInfo[tile_in_block].localHis[i] += sharedInfo[tile_in_block].countArr[lid_in_tile];

            //now consider the offsets:
            //lid_in_tile which is < SORT_RADIX stores the global offset for this digit in this tile
            //here: updating the global offset
            //PAY ATTENTION: Why offset needs to deduct countArr? See the explaination in the final scatter!!
            sharedInfo[tile_in_block].bias[lid_in_tile] = offset - sharedInfo[tile_in_block].countArr[lid_in_tile];
            offset += digitCount;

        }

//end of naive scan:-------------------------------------------------------------------------------------------------------------------------------------

        //still consecutive access!!
        for(uint i = 0; i < SCATTER_ELE_PER_THREAD; i++) {
            const unsigned char lo_id = lid_in_tile * SCATTER_ELE_PER_THREAD + i;
            if (start + lo_id >= end)    break;                                     //important to have it to deal with numbers not regular

            //position of this element(with id: lo_id) being scattered to
            uint pos = num_of_former_same_keys[i] + sharedInfo[tile_in_block].localHis[address_ele_per_thread[i]];

            //since this access pattern is different from the scatter pattern(coalesced access), the position should be stored
            //also because this lo_id is not tractable in the scatter, thus using pos as the index instead of lo_id!!
            // both pos and lo_id are in the range of [0, SCATTER_ELE_PER_TILE)
            sharedInfo[tile_in_block].shuffle[pos] = lo_id;  
            // printf("write to shuffle[%d],value:%d\n",pos, lo_id);
        }
        __syncthreads();

        //scatter back to the global memory, iterating in the shuffle array
        for(uint i = 0; i < SCATTER_ELE_PER_THREAD; i++) {
            const uint lo_id = lid_in_tile + i * SCATTER_TILE_THREAD_NUM;   //coalesced access
            if ((int)lo_id < (int)end - (int)start) {                       //in case that some threads have been larger than the total length causing index overflow
                const unsigned char position = sharedInfo[tile_in_block].shuffle[lo_id];    //position is the lo_id above
                const unsigned char myDigit = sharedInfo[tile_in_block].digits[position];   //when storing digits, the storing pattern is lid_in_tile + i * SCATTER_TILE_THREAD_NUM, 
                //this is a bit complecated:
                //think about what we have now:
                //bias is the starting point for a cetain digit to be written to.
                //in the shuffle array, we have known that where each element should go
                //now we are iterating in the shuffle array
                //the array should be like this:
                // p0,p1,p2,p3......
                //p0->0, p1->0, p2->0, p3->1......
                //replacing the p0,p1...with the digit of the element they are pointing to, we can get 000000001111111122222....
                //so actually this for loop is iterating the 0000000111111122222.....!!!! for i=0, we deal with 0000.., for i = 1, we deal with 000111...
                
                //but pay attention:
                //for example: if we have 6 0's, 7 1's. Now for the first 1, lo_id = 6. Then addr would be wrong because we should write 
                //to bias[1] + 0 instead of bias[1] + 6. So we need to deduct the number of 0's, which is why previously bias need to be deducted!!!!!
                const uint addr = lo_id + sharedInfo[tile_in_block].bias[myDigit];
#ifdef RECORDS
                d_dest_keys[addr] = sharedInfo[tile_in_block].keys[position];
#endif
                d_dest_values[addr] = sharedInfo[tile_in_block].values[position];
            }
        }
        __syncthreads();
    }
}

template<typename T>
float radixSort(
#ifdef RECORDS
    int *d_source_keys,
#endif
    T *d_source_values, int len
#ifdef RECORDS
    ,bool isRecord
#endif
    )
{
    float myTime = 0.0f;

    int blockLen = REDUCE_BLOCK_SIZE * REDUCE_ELE_PER_THREAD;
    int gridSize = (len + blockLen- 1) / blockLen;

    dim3 grid(gridSize);
    dim3 block(REDUCE_BLOCK_SIZE);

    cudaEvent_t start, end;
    cudaEventCreate(&start);
    cudaEventCreate(&end);

#ifdef RECORDS
    int *d_temp_keys;
    checkCudaErrors(cudaMalloc(&d_temp_keys, sizeof(int)* len));
#endif
    T *d_temp_values;
    checkCudaErrors(cudaMalloc(&d_temp_values, sizeof(T)* len));

    int *histogram;
    checkCudaErrors(cudaMalloc(&histogram, sizeof(int)* gridSize * SORT_RADIX));

    cudaEventRecord(start);
    for(int shiftBits = 0; shiftBits < sizeof(T) * 8; shiftBits += SORT_BITS) {
        radix_reduce<T><<<grid, block, sizeof(int) * REDUCE_BLOCK_SIZE * SORT_RADIX>>>(d_source_values, len, blockLen, histogram, shiftBits);
        scan_warpwise<int>(histogram, gridSize * SORT_RADIX, 1, 1024);
        int tileLen = REDUCE_BLOCK_SIZE * REDUCE_ELE_PER_THREAD;
        radix_scatter<T><<<(gridSize+SCATTER_TILES_PER_BLOCK-1)/SCATTER_TILES_PER_BLOCK,SCATTER_BLOCK_SIZE>>>( 
#ifdef RECORDS
        d_source_keys, d_temp_keys,
#endif
        d_source_values, d_temp_values,
        len, tileLen, gridSize, histogram, shiftBits
#ifdef RECORDS
        ,isRecord
#endif
        );

        T *temp_values = d_temp_values;
        d_temp_values = d_source_values;
        d_source_values = temp_values;
#ifdef RECORDS
        int *temp_keys = d_temp_keys;
        d_temp_keys = d_source_keys;
        d_source_keys = temp_keys;
#endif
    }

    cudaEventRecord(end);
    cudaEventSynchronize(end);
    cudaEventElapsedTime(&myTime,start, end);

    checkCudaErrors(cudaFree(d_temp_values));
#ifdef RECORDS
    checkCudaErrors(cudaFree(d_temp_keys));
#endif
    
    cudaFree(histogram);
    return myTime;
}

//templates
template float radixSort<int>(
#ifdef RECORDS
    int *d_source_keys,
#endif
    int *d_source_values, int len
#ifdef RECORDS
    ,bool isRecord
#endif
    );

template float radixSort<long>(
#ifdef RECORDS
    int *d_source_keys,
#endif
    long *d_source_values, int len
#ifdef RECORDS
    ,bool isRecord
#endif
    );

/*******************************   end of fast radix sort ***************************************/





/*******************************   here is the old implementations ***************************************/
__global__
void countHis(const Record* source,
              const int length,
			  int* histogram,        //size: globalSize * SORT_RADIX
              const int shiftBits)
{
	extern __shared__ int temp[];		//each group has temp size of BLOCKSIZE * SORT_RADIX

    int localId = threadIdx.x;
    int globalId = threadIdx.x + blockDim.x * blockIdx.x;
    int globalSize = blockDim.x * gridDim.x;
    
    int elePerThread = (length + globalSize - 1) / globalSize;
    int offset = localId * SORT_RADIX;
    int mask = SORT_RADIX - 1;
    
    //initialization
    for(int i = 0; i < SORT_RADIX; i++) {
        temp[i + offset] = 0;
    }
    __syncthreads();
    
    for(int i = 0; i < elePerThread; i++) {
        int id = globalId * elePerThread + i;
        if (id >= length)   break;
        int current = source[id].y;
        current = (current >> shiftBits) & mask;
        temp[offset + current]++;
    }
    __syncthreads();
    
    for(int i = 0; i < SORT_RADIX; i++) {
        histogram[i*globalSize + globalId] = temp[offset+i];
    }
}

__global__
void writeHis(const Record* source,
			  const int length,
              const int* histogram,
              int* loc,              //size equal to the size of source
              const int shiftBits)               
{
	extern __shared__ int temp[];		//each group has temp size of BLOCKSIZE * SORT_RADIX

    int localId = threadIdx.x;
    int globalId = threadIdx.x + blockDim.x * blockIdx.x;
    int globalSize = blockDim.x * gridDim.x;
    
    int elePerThread = (length + globalSize - 1) / globalSize;     // length for each thread to proceed
    int offset = localId * SORT_RADIX;
    int mask = SORT_RADIX - 1;
    
    for(int i = 0; i < SORT_RADIX; i++) {
        temp[offset + i] = histogram[i*globalSize + globalId];
    }
    __syncthreads();
    
    for(int i = 0; i < elePerThread; i++) {
        int id = globalId * elePerThread + i;
        if (id >= length)   break;
        int current = source[globalId * elePerThread + i].y;
        current = (current >> shiftBits) & mask;
        loc[globalId * elePerThread + i] = temp[offset + current];
        temp[offset + current]++;
    }
}

__global__
void countHis_int(const int* source,
              	  const int length,
			  	  int* histogram,        //size: globalSize * SORT_RADIX
              	  const int shiftBits)
{
	extern __shared__ int temp[];		//each group has temp size of BLOCKSIZE * SORT_RADIX

    int localId = threadIdx.x;
    int globalId = threadIdx.x + blockDim.x * blockIdx.x;
    int globalSize = blockDim.x * gridDim.x;
    
    int elePerThread = (length + globalSize - 1) / globalSize;
    int offset = localId * SORT_RADIX;
    int mask = SORT_RADIX - 1;
    
    //initialization
    for(int i = 0; i < SORT_RADIX; i++) {
        temp[i + offset] = 0;
    }
    __syncthreads();
    
    for(int i = 0; i < elePerThread; i++) {
        int id = globalId * elePerThread + i;
        if (id >= length)   break;
        int current = source[id];
        current = (current >> shiftBits) & mask;
        temp[offset + current]++;
    }
    __syncthreads();
    
    for(int i = 0; i < SORT_RADIX; i++) {
        histogram[i*globalSize + globalId] = temp[offset+i];
    }
}

__global__
void writeHis_int(const int* source,
			  const int length,
              const int* histogram,
              int* loc,              //size equal to the size of source
              const int shiftBits)               
{
	extern __shared__ int temp[];		//each group has temp size of BLOCKSIZE * SORT_RADIX

    int localId = threadIdx.x;
    int globalId = threadIdx.x + blockDim.x * blockIdx.x;
    int globalSize = blockDim.x * gridDim.x;
    
    int elePerThread = (length + globalSize - 1) / globalSize;     // length for each thread to proceed
    int offset = localId * SORT_RADIX;
    int mask = SORT_RADIX - 1;
    
    for(int i = 0; i < SORT_RADIX; i++) {
        temp[offset + i] = histogram[i*globalSize + globalId];
    }
    __syncthreads();
    
    for(int i = 0; i < elePerThread; i++) {
        int id = globalId * elePerThread + i;
        if (id >= length)   break;
        int current = source[globalId * elePerThread + i];
        current = (current >> shiftBits) & mask;
        loc[globalId * elePerThread + i] = temp[offset + current];
        temp[offset + current]++;
    }
}

double radixSortDevice(Record *d_source, int r_len, int blockSize, int gridSize) {
	blockSize = 512;
	gridSize = 256;

	double totalTime = 0.0f;
	int globalSize = blockSize * gridSize;

	//histogram
	int *his, *loc, *res_his;
	checkCudaErrors(cudaMalloc(&his, sizeof(int)*globalSize * SORT_RADIX));
	checkCudaErrors(cudaMalloc(&loc, sizeof(int)*r_len));
	checkCudaErrors(cudaMalloc(&res_his, sizeof(int)*globalSize * SORT_RADIX));

	Record *d_temp;
	checkCudaErrors(cudaMalloc(&d_temp, sizeof(Record)*r_len));

	dim3 grid(gridSize);
	dim3 block(blockSize);

	struct timeval start, end;

	thrust::device_ptr<int> dev_his(his);
	thrust::device_ptr<int> dev_res_his(res_his);

	gettimeofday(&start,NULL);
	for(int shiftBits = 0; shiftBits < sizeof(int)*8; shiftBits += SORT_BITS) {

		countHis<<<grid,block,sizeof(int)*SORT_RADIX*blockSize>>>(d_source, r_len, his, shiftBits);
		scanDevice(his, globalSize*SORT_RADIX, 1024, 1024,1);
		writeHis<<<grid,block,sizeof(int)*SORT_RADIX*blockSize>>>(d_source,r_len,his,loc,shiftBits);
		// scatter(d_source,d_temp, r_len, loc, 1024,32768);
		cudaMemcpy(d_source, d_temp, sizeof(Record)*r_len, cudaMemcpyDeviceToDevice);
	}
	cudaDeviceSynchronize();
	gettimeofday(&end,NULL);
	totalTime = diffTime(end, start);

	checkCudaErrors(cudaFree(his));
	checkCudaErrors(cudaFree(d_temp));
	checkCudaErrors(cudaFree(loc));

	return totalTime;
}

double radixSortDevice_int(int *d_source, int r_len, int blockSize, int gridSize) {
	blockSize = 512;
	gridSize = 2048;

	double totalTime = 0.0f;
	int globalSize = blockSize * gridSize;

	//histogram
	int *his, *loc, *res_his;
	checkCudaErrors(cudaMalloc(&his, sizeof(int)*globalSize * SORT_RADIX));
	checkCudaErrors(cudaMalloc(&loc, sizeof(int)*r_len));
	checkCudaErrors(cudaMalloc(&res_his, sizeof(int)*globalSize * SORT_RADIX));

	int *d_temp;
	checkCudaErrors(cudaMalloc(&d_temp, sizeof(int)*r_len));

	dim3 grid(gridSize);
	dim3 block(blockSize);

	struct timeval start, end;

	thrust::device_ptr<int> dev_his(his);
	thrust::device_ptr<int> dev_res_his(res_his);

	gettimeofday(&start,NULL);

	std::cout<<"shared momery size:"<<sizeof(int)*SORT_RADIX*blockSize<<std::endl;
	for(int shiftBits = 0; shiftBits < sizeof(int)*8; shiftBits += SORT_BITS) {

		countHis_int<<<grid,block,sizeof(int)*SORT_RADIX*blockSize>>>(d_source, r_len, his, shiftBits);
		scanDevice(his, globalSize*SORT_RADIX, 1024, 1024,1);
		writeHis_int<<<grid,block,sizeof(int)*SORT_RADIX*blockSize>>>(d_source,r_len,his,loc,shiftBits);
		// scatter(d_source,d_temp, r_len, loc, 1024,32768);
		int *swapPointer = d_temp;
		d_temp = d_source;
		d_source = swapPointer;
	}
	cudaDeviceSynchronize();
	gettimeofday(&end,NULL);
	totalTime = diffTime(end, start);

	checkCudaErrors(cudaFree(his));
	checkCudaErrors(cudaFree(d_temp));
	checkCudaErrors(cudaFree(loc));

	return totalTime;
}

double radixSortImpl(Record *h_source, int r_len, int blockSize, int gridSize) {
	double totalTime = 0.0f;
	Record *d_source;
	
	//thrust test
	int *keys = new int[r_len];
	int *values = new int[r_len];

	for(int i = 0; i < r_len; i++) {
		keys[i] = h_source[i].x;
		values[i] = h_source[i].y;
	}

	checkCudaErrors(cudaMalloc(&d_source, sizeof(Record)*r_len));
	cudaMemcpy(d_source, h_source, sizeof(Record)*r_len, cudaMemcpyHostToDevice);

	totalTime = radixSortDevice(d_source, r_len, blockSize, gridSize);

	cudaMemcpy(h_source, d_source, sizeof(Record)*r_len, cudaMemcpyDeviceToHost);

	checkCudaErrors(cudaFree(d_source));


	// struct timeval start, end;

	// gettimeofday(&start, NULL);
	// thrust::sorting::stable_radix_sort_by_key(values, values+r_len, keys);
	// gettimeofday(&end, NULL);

	// for(int i = 0; i < r_len; i++) {
	// 	cout<<h_source[i].x<<' '<<h_source[i].y<<'\t'<<keys[i]<<' '<<values[i]<<endl;
	// }
	// double thrustTime = diff(end,start);
	// cout<<"Thrust time for radixsort: "<<thrustTime<<" ms."<<endl;

	delete[] keys;
	delete[] values;
	return totalTime;
}

double radixSortImpl_int(int *h_source, int r_len, int blockSize, int gridSize) {
	double totalTime = 0.0f;
	int *h_thrust_source = new int[r_len];
	
	int *d_source;
	int *d_thrust_source;

	checkCudaErrors(cudaMalloc(&d_source, sizeof(int)*r_len));
	checkCudaErrors(cudaMalloc(&d_thrust_source, sizeof(int)*r_len));

	cudaMemcpy(d_source, h_source, sizeof(int)*r_len, cudaMemcpyHostToDevice);
	cudaMemcpy(d_thrust_source, h_source, sizeof(int)*r_len, cudaMemcpyHostToDevice);

	totalTime = radixSortDevice_int(d_source, r_len, blockSize, gridSize);

	cudaMemcpy(h_source, d_source, sizeof(int)*r_len, cudaMemcpyDeviceToHost);

	checkCudaErrors(cudaFree(d_source));

	struct timeval start, end;

	thrust::device_ptr<int> dev_source(d_thrust_source);

	gettimeofday(&start, NULL);
	thrust::sort(dev_source, dev_source+r_len);
	cudaDeviceSynchronize();
	gettimeofday(&end, NULL);

	cudaMemcpy(h_thrust_source, d_thrust_source, sizeof(int) * r_len, cudaMemcpyDeviceToHost);
	
	double thrustTime = diffTime(end,start);
	std::cout<<"Thrust time for radixsort: "<<thrustTime<<" ms."<<std::endl;
	
	//check the thrust output with implemented output
	for(int i = 0; i < r_len; i++) {
		if (h_source[i] != h_thrust_source[i])	std::cerr<<"different"<<std::endl;
	}
	delete[] h_thrust_source;
	return totalTime;
}