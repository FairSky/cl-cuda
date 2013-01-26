#|
  This file is a part of cl-cuda project.
  Copyright (c) 2012 Masayuki Takagi (kamonama@gmail.com)
|#

(in-package :cl-user)
(defpackage cl-cuda
  (:use :cl :alexandria :anaphora :cl-pattern)
  (:export :*show-messages*             ; configuration
           :with-cuda-context           ; CUDA context
           :init-cuda-context
           :release-cuda-context
           :synchronize-context
           :with-memory-blocks          ; Memory Block
           :alloc-memory-block
           :free-memory-block
           :memory-block-vertex-buffer-object
           :mem-aref
           :memcpy-host-to-device
           :memcpy-device-to-host
           :create-timer                ; Timer
           :destroy-timer
           :with-timer
           :start-timer
           :stop-and-synchronize-timer
           :get-elapsed-time
           :float3 :make-float3         ; Built-in Vector Types
           :float3-p
           :float3-x :float3-y :float3-z :float3-=
           :float4 :make-float4
           :float4-p
           :float4-x :float4-y :float4-z :float4-w :float4-=
           :defkernel :defkernelmacro   ; Kernel Description Language
           :void :int :int* :float :float*
           :float3 :float3* :float4 :float4*
           :grid-dim-x :grid-dim-y :grid-dim-z
           :block-dim-x :block-dim-y :block-dim-z
           :block-idx-x :block-idx-y :block-idx-z
           :thread-idx-x :thread-idx-y :thread-idx-z
           :with-shared-memory :syncthreads
           :rsqrtf                      ; Built-in functions
           :print-kernel-manager        ; Utilities for the default kernel manager
           :clear-kernel-manager
           :expand-macro :expand-macro-1
           ))
