/*  Reference: OpenCL V1.2 cheat sheet
 *  https://www.khronos.org/files/opencl-1-2-quick-reference-card.pdf
 * */

#pragma once

// 1st: macros
#define kernel
#define global
#define local

#define CLK_LOCAL_MEM_FENCE     0
#define CLK_GLOBAL_MEM_FENCE    1

// 2nd: built-in functions
int get_global_id(int);
int get_global_size(int);
int get_local_id(int);
int get_local_size(int);
int get_group_id(int);
int get_num_groups(int);
void barrier(int);
void mem_fence(int);

/*atomic functions*/
int atomic_inc(int*);

//
///*OpenCL Constructs*/
//using cl_platform_id = int;
//using cl_device_id = int;
//using cl_context = int;
//using cl_command_queue_properties = int;
//using cl_command_queue = int;
//
//enum cl_device_type{
//    CL_DEVICE_TYPE_GPU, CL_DEVICE_TYPE_CPU, CL_DEVICE_TYPE_ALL
//};
//
//enum cl_device_info {
//    CL_​DEVICE_​TYPE,
//    CL_​DEVICE_​VENDOR_​ID4,
//    CL_​DEVICE_​MAX_​COMPUTE_​UNITS,
//    CL_​DEVICE_​MAX_​WORK_​ITEM_​DIMENSIONS,
//    CL_​DEVICE_​MAX_​WORK_​ITEM_​SIZES,
//    CL_​DEVICE_​MAX_​WORK_​GROUP_​SIZE,
//    CL_​DEVICE_​PREFERRED_​VECTOR_​WIDTH_​CHAR,
//    CL_​DEVICE_​PREFERRED_​VECTOR_​WIDTH_​SHORT,
//    CL_​DEVICE_​PREFERRED_​VECTOR_​WIDTH_​INT,
//    CL_​DEVICE_​PREFERRED_​VECTOR_​WIDTH_​LONG,
//    CL_​DEVICE_​PREFERRED_​VECTOR_​WIDTH_​FLOAT,
//    CL_​DEVICE_​PREFERRED_​VECTOR_​WIDTH_​DOUBLE,
//    CL_​DEVICE_​PREFERRED_​VECTOR_​WIDTH_​HALF,
//    CL_​DEVICE_​NATIVE_​VECTOR_​WIDTH_​CHAR,
//    CL_​DEVICE_​NATIVE_​VECTOR_​WIDTH_​SHORT,
//    CL_​DEVICE_​NATIVE_​VECTOR_​WIDTH_​INT,
//    CL_​DEVICE_​NATIVE_​VECTOR_​WIDTH_​LONG,
//    CL_​DEVICE_​NATIVE_​VECTOR_​WIDTH_​FLOAT,
//    CL_​DEVICE_​NATIVE_​VECTOR_​WIDTH_​DOUBLE,
//    CL_​DEVICE_​NATIVE_​VECTOR_​WIDTH_​HALF,
//    CL_​DEVICE_​MAX_​CLOCK_​FREQUENCY,
//    CL_​DEVICE_​ADDRESS_​BITS,
//    CL_​DEVICE_​MAX_​MEM_​ALLOC_​SIZE,
//    CL_​DEVICE_​IMAGE_​SUPPORT,
//    CL_​DEVICE_​MAX_​READ_​IMAGE_​ARGS5,
//    CL_​DEVICE_​MAX_​WRITE_​IMAGE_​ARGS,
//    CL_​DEVICE_​MAX_​READ_​WRITE_​IMAGE_​ARGS6,
//    CL_​DEVICE_​IL_​VERSION,
//    CL_​DEVICE_​IMAGE2D_​MAX_​WIDTH,
//    CL_​DEVICE_​IMAGE2D_​MAX_​HEIGHT,
//    CL_​DEVICE_​IMAGE3D_​MAX_​WIDTH,
//    CL_​DEVICE_​IMAGE3D_​MAX_​HEIGHT,
//    CL_​DEVICE_​IMAGE3D_​MAX_​DEPTH,
//    CL_​DEVICE_​IMAGE_​MAX_​BUFFER_​SIZE,
//    CL_​DEVICE_​IMAGE_​MAX_​ARRAY_​SIZE,
//    CL_​DEVICE_​MAX_​SAMPLERS,
//    CL_​DEVICE_​IMAGE_​PITCH_​ALIGNMENT,
//    CL_​DEVICE_​IMAGE_​BASE_​ADDRESS_​ALIGNMENT,
//    CL_​DEVICE_​MAX_​PIPE_​ARGS,
//    CL_​DEVICE_​PIPE_​MAX_​ACTIVE_​RESERVATIONS,
//    CL_​DEVICE_​PIPE_​MAX_​PACKET_​SIZE,
//    CL_​DEVICE_​MAX_​PARAMETER_​SIZE,
//    CL_​DEVICE_​MEM_​BASE_​ADDR_​ALIGN,
//    CL_​DEVICE_​MIN_​DATA_​TYPE_​ALIGN_​SIZE,
//    CL_​DEVICE_​SINGLE_​FP_​CONFIG7,
//    CL_​DEVICE_​DOUBLE_​FP_​CONFIG8,
//    CL_​DEVICE_​GLOBAL_​MEM_​CACHE_​TYPE,
//    CL_​DEVICE_​GLOBAL_​MEM_​CACHELINE_​SIZE,
//    CL_​DEVICE_​GLOBAL_​MEM_​CACHE_​SIZE,
//    CL_​DEVICE_​GLOBAL_​MEM_​SIZE,
//    CL_​DEVICE_​MAX_​CONSTANT_​BUFFER_​SIZE,
//    CL_​DEVICE_​MAX_​CONSTANT_​ARGS,
//    CL_​DEVICE_​MAX_​GLOBAL_​VARIABLE_​SIZE,
//    CL_​DEVICE_​GLOBAL_​VARIABLE_​PREFERRED_​TOTAL_​SIZE,
//    CL_​DEVICE_​LOCAL_​MEM_​TYPE,
//    CL_​DEVICE_​LOCAL_​MEM_​SIZE,
//    CL_​DEVICE_​ERROR_​CORRECTION_​SUPPORT,
//    CL_​DEVICE_​HOST_​UNIFIED_​MEMORY,
//    CL_​DEVICE_​PROFILING_​TIMER_​RESOLUTION,
//    CL_​DEVICE_​ENDIAN_​LITTLE,
//    CL_​DEVICE_​AVAILABLE,
//    CL_​DEVICE_​COMPILER_​AVAILABLE,
//    CL_​DEVICE_​LINKER_​AVAILABLE,
//    CL_​DEVICE_​EXECUTION_​CAPABILITIES,
//    CL_​DEVICE_​QUEUE_​PROPERTIES,
//    CL_​DEVICE_​QUEUE_​ON_​HOST_​PROPERTIES,
//    CL_​DEVICE_​QUEUE_​ON_​DEVICE_​PROPERTIES,
//    CL_​DEVICE_​QUEUE_​ON_​DEVICE_​PREFERRED_​SIZE,
//    CL_​DEVICE_​QUEUE_​ON_​DEVICE_​MAX_​SIZE,
//    CL_​DEVICE_​MAX_​ON_​DEVICE_​QUEUES,
//    CL_​DEVICE_​MAX_​ON_​DEVICE_​EVENTS,
//    CL_​DEVICE_​BUILT_​IN_​KERNELS,
//    CL_​DEVICE_​PLATFORM,
//    CL_​DEVICE_​NAME,
//    CL_​DEVICE_​VENDOR,
//    CL_​DRIVER_​VERSION,
//    CL_​DEVICE_​PROFILE9,
//    CL_​DEVICE_​VERSION,
//    CL_​DEVICE_​OPENCL_​C_​VERSION,
//    CL_​DEVICE_​EXTENSIONS,
//    CL_​DEVICE_​PRINTF_​BUFFER_​SIZE,
//    CL_​DEVICE_​PREFERRED_​INTEROP_​USER_​SYNC,
//    CL_​DEVICE_​PARENT_​DEVICE,
//    CL_​DEVICE_​PARTITION_​MAX_​SUB_​DEVICES,
//    CL_​DEVICE_​PARTITION_​PROPERTIES,
//    CL_​DEVICE_​PARTITION_​AFFINITY_​DOMAIN,
//    CL_​DEVICE_​PARTITION_​TYPE,
//    CL_​DEVICE_​REFERENCE_​COUNT,
//    CL_​DEVICE_​SVM_​CAPABILITIES,
//    CL_​DEVICE_​PREFERRED_​PLATFORM_​ATOMIC_​ALIGNMENT,
//    CL_​DEVICE_​PREFERRED_​GLOBAL_​ATOMIC_​ALIGNMENT,
//    CL_​DEVICE_​PREFERRED_​LOCAL_​ATOMIC_​ALIGNMENT,
//    CL_​DEVICE_​MAX_​NUM_​SUB_​GROUPS,
//    CL_​DEVICE_​SUB_​GROUP_​INDEPENDENT_​FORWARD_​PROGRESS
//};
//
///*OpenCL Types*/
//using cl_int = int;
//
///*OpenCL Runtime*/
//cl_command_queue
//clCreateCommandQueue(cl_context context,
//                     cl_device_id device,
//                     cl_command_queue_properties properties,
//                     cl_int *errcode_ret);
//cl_int
//clGetDeviceInfo(cl_device_id device,
//                cl_device_info param_name,
//                size_t param_value_size,
//                void *param_value,
//                size_t *param_value_size_ret);

