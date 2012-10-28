#|
  This file is a part of cl-cuda project.
  Copyright (c) 2012 Masayuki Takagi (kamonama@gmail.com)
|#

(in-package :cl-user)
(defpackage cl-cuda
  (:use :cl :alexandria :anaphora :cl-pattern)
  (:export :cu-result                   ; Types
           :cu-device
           :cu-context
           :cu-module
           :cu-function
           :cu-stream
           :cu-device-ptr
           :cu-event
           :cu-event-default         ; Enums
           :cu-event-blocking-sync
           :cu-event-disable-timing
           :cu-event-interprocess
           :cu-init                     ; Functions
           :cu-device-get
           :cu-device-get-count
           :cu-device-compute-capability
           :cu-device-get-name
           :cu-ctx-create
           :cu-ctx-synchronize
           :cu-ctx-destroy
           :cu-mem-alloc
           :cu-mem-free
           :cu-memcpy-host-to-device
           :cu-memcpy-device-to-host
           :cu-module-load
           :cu-module-get-function
           :cu-launch-kernel
           :cu-event-create
           :cu-event-destroy
           :cu-event-elapsed-time
           :cu-event-query
           :cu-event-record
           :cu-event-synchronize
           :+cuda-success+              ; Constants
           :check-cuda-errors           ; Helpers
           :*show-messages*
           :with-cuda-context
           :init-cuda-context
           :release-cuda-context
           :with-memory-blocks          ; Memory Block
           :alloc-memory-block
           :free-memory-block
           :mem-aref
           :memcpy-host-to-device
           :memcpy-device-to-host
           :float3 :make-float3         ; Built-in Vector Types
           :float3-p
           :float3-x :float3-y :float3-z :float3-=
           :float4 :make-float4
           :float4-p
           :float4-x :float4-y :float4-z :float4-w :float4-=
           :rsqrtf                      ; Built-in functions
           :defkernel                   ; defkernel
           :void :int :int* :float :float*
           :float3 :float3* :float4 :float4*
           :grid-dim-x :grid-dim-y :grid-dim-z
           :block-dim-x :block-dim-y :block-dim-z
           :block-idx-x :block-idx-y :block-idx-z
           :thread-idx-x :thread-idx-y :thread-idx-z
           :for :with-shared-memory :syncthreads
           ))
