#|
  This file is a part of cl-cuda project.
  Copyright (c) 2012 Masayuki Takagi (kamonama@gmail.com)
|#

#|
  This file is automatically generated from drvapi_error_string.h in CUDA SDK, do not edit.
  Timestamp: Nov. 23 2012
|#

(in-package :cl-cuda)

(defparameter +error-strings+
  '(0 "CUDA_SUCCESS"
    1 "CUDA_ERROR_INVALID_VALUE"
    2 "CUDA_ERROR_OUT_OF_MEMORY"
    3 "CUDA_ERROR_NOT_INITIALIZED"
    4 "CUDA_ERROR_DEINITIALIZED"
    5 "CUDA_ERROR_PROFILER_DISABLED"
    6 "CUDA_ERROR_PROFILER_NOT_INITIALIZED"
    7 "CUDA_ERROR_PROFILER_ALREADY_STARTED"
    8 "CUDA_ERROR_PROFILER_ALREADY_STOPPED"
    100 "CUDA_ERROR_NO_DEVICE (no CUDA-capable devices were detected)"
    101 "CUDA_ERROR_INVALID_DEVICE (device specified is not a valid CUDA device)"
    200 "CUDA_ERROR_INVALID_IMAGE"
    201 "CUDA_ERROR_INVALID_CONTEXT"
    202 "CUDA_ERROR_CONTEXT_ALREADY_CURRENT"
    205 "CUDA_ERROR_MAP_FAILED"
    206 "CUDA_ERROR_UNMAP_FAILED"
    207 "CUDA_ERROR_ARRAY_IS_MAPPED"
    208 "CUDA_ERROR_ALREADY_MAPPED"
    209 "CUDA_ERROR_NO_BINARY_FOR_GPU"
    210 "CUDA_ERROR_ALREADY_ACQUIRED"
    211 "CUDA_ERROR_NOT_MAPPED"
    212 "CUDA_ERROR_NOT_MAPPED_AS_ARRAY"
    213 "CUDA_ERROR_NOT_MAPPED_AS_POINTER"
    214 "CUDA_ERROR_ECC_UNCORRECTABLE"
    215 "CUDA_ERROR_UNSUPPORTED_LIMIT"
    216 "CUDA_ERROR_CONTEXT_ALREADY_IN_USE"
    300 "CUDA_ERROR_INVALID_SOURCE"
    301 "CUDA_ERROR_FILE_NOT_FOUND"
    302 "CUDA_ERROR_SHARED_OBJECT_SYMBOL_NOT_FOUND"
    303 "CUDA_ERROR_SHARED_OBJECT_INIT_FAILED"
    304 "CUDA_ERROR_OPERATING_SYSTEM"
    400 "CUDA_ERROR_INVALID_HANDLE"
    500 "CUDA_ERROR_NOT_FOUND"
    600 "CUDA_ERROR_NOT_READY"
    700 "CUDA_ERROR_LAUNCH_FAILED"
    701 "CUDA_ERROR_LAUNCH_OUT_OF_RESOURCES"
    702 "CUDA_ERROR_LAUNCH_TIMEOUT"
    703 "CUDA_ERROR_LAUNCH_INCOMPATIBLE_TEXTURING"
    704 "CUDA_ERROR_PEER_ACCESS_ALREADY_ENABLED"
    705 "CUDA_ERROR_PEER_ACCESS_NOT_ENABLED"
    708 "CUDA_ERROR_PRIMARY_CONTEXT_ACTIVE"
    709 "CUDA_ERROR_CONTEXT_IS_DESTROYED"
    710 "CUDA_ERROR_ASSERT"
    999 "CUDA_ERROR_UNKNOWN"
    ))

(defun get-error-string (n)
  (or (getf +error-strings+ n)
      (error "invalid CUDA driver API error No.: ~A" n)))