#|
  This file is a part of cl-cuda project.
  Copyright (c) 2012 Masayuki Takagi (kamonama@gmail.com)
|#

(in-package :cl-cuda-test)

(setf *test-result-output* *standard-output*)

(plan nil)


;;; test cuInit
(diag "test cuInit")
(cu-init 0)


;;; test cuDeviceGet
(diag "test cuDeviceGet")
(let ((dev-id 0))
  (cffi:with-foreign-object (device 'cu-device)
    (setf (cffi:mem-ref device :int) 42)
    (cu-device-get device dev-id)
    (format t "CUDA device handle: ~A~%" (cffi:mem-ref device 'cu-device))))


;;; test cuDeviceGetCount
(diag "test cuDeviceGetCount")
(cffi:with-foreign-object (count :int)
  (cu-device-get-count count)
  (format t "CUDA device count: ~A~%" (cffi:mem-ref count :int)))


;;; test cuDeviceComputeCapability
(diag "test cuDeviceComputeCapability")
(let ((dev-id 0))
  (cffi:with-foreign-objects ((major :int)
                              (minor :int)
                              (device 'cu-device))
    (cu-device-get device dev-id)
    (cu-device-compute-capability major minor (cffi:mem-ref device 'cu-device))
    (format t "CUDA device compute capability: ~A.~A~%"
              (cffi:mem-ref major :int) (cffi:mem-ref minor :int))))


;;; test cuDeviceGetName
(diag "test cuDeviceGetName")
(let ((dev-id 0))
  (cffi:with-foreign-object (device 'cu-device)
  (cffi:with-foreign-pointer-as-string ((name size) 255)
    (cu-device-get device dev-id)
    (cu-device-get-name name size (cffi:mem-ref device 'cu-device))
    (format t "CUDA device name: ~A~%" (cffi:foreign-string-to-lisp name)))))


;;; test cuCtxCreate/cuCtxDestroy
(diag "test cuCtxCreate/cuCtxDestroy")
(let ((flags 0)
      (dev-id 0))
  (cffi:with-foreign-objects ((pctx 'cu-context)
                              (device 'cu-device))
    (cu-device-get device dev-id)
    (cu-ctx-create pctx flags (cffi:mem-ref device 'cu-device))
    (cu-ctx-destroy (cffi:mem-ref pctx 'cu-context))))


;;; test cuMemAlloc/cuMemFree
(diag "test cuMemAlloc/cuMemFree")
(let ((flags 0)
      (dev-id 0))
  (cffi:with-foreign-objects ((device 'cu-device)
                              (pctx 'cu-context)
                              (dptr 'cu-device-ptr))
    (cu-device-get device dev-id)
    (cu-ctx-create pctx flags (cffi:mem-ref device 'cu-device))
    (cu-mem-alloc dptr 1024)
    (cu-mem-free (cffi:mem-ref dptr 'cu-device-ptr))
    (cu-ctx-destroy (cffi:mem-ref pctx 'cu-context))))


;;; test cuMemAlloc/cuMemFree using with-cuda-context
(diag "test cuMemAlloc/cuMemFree using with-cuda-context")
(let ((dev-id 0))
  (with-cuda-context (dev-id)
    (cffi:with-foreign-object (dptr 'cu-device-ptr)
      (cu-mem-alloc dptr 1024)
      (cu-mem-free (cffi:mem-ref dptr 'cu-device-ptr)))))


;;; test cuMemAlloc/cuMemFree using with-cuda-context and with-cuda-mem-block
(diag "test cuMemAlloc/cuMemFree using with-cuda-context and with-cuda-mem-block")
(let ((dev-id 0))
  (with-cuda-context (dev-id)
    (cl-cuda::with-cuda-memory-block (dptr 1024))))


;;; test cuMemAlloc/cuMemFree using with-cuda-context and with-cuda-mem-blocks
(diag "test cuMemAlloc/cuMemFree using with-cuda-context and with-cuda-mem-blocks")
(let ((dev-id 0))
  (with-cuda-context (dev-id)
    (cl-cuda::with-cuda-memory-blocks ((dptr1 1024)
                                       (dptr2 1024)))))


;;; test cuMemcpyHtoD/cuMemcpyDtoH
(diag "test cuMemcpyHtoD/cuMemcpyDtoH")
(let ((dev-id 0)
      (size 1024))
  (with-cuda-context (dev-id)
    (cffi:with-foreign-object (hptr :float size)
      (cl-cuda::with-cuda-memory-block (dptr size)
        (cu-memcpy-host-to-device (cffi:mem-ref dptr 'cu-device-ptr) hptr size)
        (cu-memcpy-device-to-host hptr (cffi:mem-ref dptr 'cu-device-ptr) size)))))


;;; test cuModuleLoad
(diag "test cuModuleLoad")
(let ((dev-id 0))
  (cffi:with-foreign-string (fname "/Developer/GPU Computing/C/src/vectorAddDrv/data/vectorAdd_kernel.ptx")
    (with-cuda-context (dev-id)
      (cffi:with-foreign-object (module 'cu-module)
        (cu-module-load module fname)
        (format t "CUDA module \"vectorAdd_kernel.ptx\" is loaded.~%")))))


;;; test cuModuleGetFunction
(diag "test cuModuleGetFunction")
(let ((dev-id 0))
  (cffi:with-foreign-string (fname "/Developer/GPU Computing/C/src/vectorAddDrv/data/vectorAdd_kernel.ptx")
    (cffi:with-foreign-string (name "VecAdd_kernel")
      (with-cuda-context (dev-id)
        (cffi:with-foreign-objects ((module 'cu-module)
                                    (hfunc 'cu-function))
          (cu-module-load module fname)
          (cu-module-get-function hfunc (cffi:mem-ref module 'cu-module) name))))))


;;; test memory blocks

(diag "test memory blocks")

(let ((dev-id 0))
  (with-cuda-context (dev-id)
    (let (blk)
      (ok (setf blk (cl-cuda::alloc-memory-block 'int 1024)))
      (cl-cuda::free-memory-block blk))
    (is-error (cl-cuda::alloc-memory-block 'void 1024) simple-error)
    (is-error (cl-cuda::alloc-memory-block 'int* 1024) simple-error)
    (is-error (cl-cuda::alloc-memory-block 'int (* 1024 1024 256))
              simple-error)
    (is-error (cl-cuda::alloc-memory-block 'int 0) simple-error)
    (is-error (cl-cuda::alloc-memory-block 'int -1) type-error)))

(let ((dev-id 0))
  (with-cuda-context (dev-id)
    (with-memory-blocks ((blk 'int 1024))
      (ok (cl-cuda::memory-block-cffi-ptr blk))
      (ok (cl-cuda::memory-block-device-ptr blk))
      (is (cl-cuda::memory-block-type blk) 'int)
      (is (cl-cuda::memory-block-cffi-type blk) :int)
      (is (cl-cuda::memory-block-length blk) 1024)
      (is (cl-cuda::memory-block-bytes blk) (* 1024 4))
      (is (cl-cuda::memory-block-element-bytes blk) 4))))

(let ((dev-id 0))
  (with-cuda-context (dev-id)
    ;; int array
    (with-memory-blocks ((x 'int 1))
      (setf (mem-aref x 0) 1)
      (is (mem-aref x 0) 1))
    ;; float array
    (with-memory-blocks ((x 'float 1))
      (setf (mem-aref x 0) 1.0)
      (is (mem-aref x 0) 1.0))
    ;; float3 array
    (with-memory-blocks ((x 'float3 1))
      (setf (mem-aref x 0) (make-float3 1.0 1.0 1.0))
      (is (mem-aref x 0) (make-float3 1.0 1.0 1.0) :test #'float3-=))
    ;; float4 array
    (with-memory-blocks ((x 'float4 1))
      (setf (mem-aref x 0) (make-float4 1.0 1.0 1.0 1.0))
      (is (mem-aref x 0) (make-float4 1.0 1.0 1.0 1.0) :test #'float4-=))
    ;; error cases
    (with-memory-blocks ((x 'int 1))
      (is-error (mem-aref x -1) simple-error)
      (is-error (setf (mem-aref x -1) 0) simple-error)
      (is-error (mem-aref x 1) simple-error)
      (is-error (setf (mem-aref x 1) 0) simple-error))))

(defkernel test-memcpy (void ((x int*) (y float*)))
  (set (aref x 0) (+ (aref x 0) 1))
  (set (aref y 0) (+ (aref y 0) 1.0)))

(let ((dev-id 0))
  (with-cuda-context (dev-id)
    (with-memory-blocks ((x 'int 1)
                         (y 'float 1))
      (setf (mem-aref x 0) 1)
      (setf (mem-aref y 0) 1.0)
      (memcpy-host-to-device x y)
      (test-memcpy x y :grid-dim '(1 1 1)
                       :block-dim '(1 1 1))
      (memcpy-device-to-host x y)
      (is (mem-aref x 0) 2)
      (is (mem-aref y 0) 2.0))))


;;; test kernel-defun

(diag "test kernel-defun")

(is (cl-cuda::vector-type-length 'float3) 3)
(is-error (cl-cuda::vector-type-length 'float) simple-error)
(is-error (cl-cuda::vector-type-length 'float3*) simple-error)

(is (cl-cuda::vector-type-base-type 'float3) 'float)
(is-error (cl-cuda::vector-type-base-type 'float) simple-error)
(is-error (cl-cuda::vector-type-base-type 'float3*) simple-error)

(is (cl-cuda::vector-type-selector-symbol 'float3 'cl-cuda::x) 'float3-x)
(is-error (cl-cuda::vector-type-selector-symbol 'float 'cl-cuda::x)
          simple-error)
(is-error (cl-cuda::vector-type-selector-symbol 'float3 'cl-cuda::a)
          simple-error)

(is (cl-cuda::vector-type-selector-symbols)
    '(float3-x float3-y float3-z
      float4-x float4-y float4-z float4-w))

(is (cl-cuda::foreign-pointer-setf-vector-type 'x 'x-ptr 'float3)
    '(progn
      (setf (cffi:foreign-slot-value x-ptr 'float3 'cl-cuda::x) (float3-x x))
      (setf (cffi:foreign-slot-value x-ptr 'float3 'cl-cuda::y) (float3-y x))
      (setf (cffi:foreign-slot-value x-ptr 'float3 'cl-cuda::z) (float3-z x))))

(is-expand
  (cl-cuda::with-non-pointer-arguments ((n n-ptr :int)
                                        (x x-ptr :float)
                                        (a a-ptr float3))
    nil)
  (cffi:with-foreign-objects ((n-ptr :int)
                              (x-ptr :float)
                              (a-ptr 'float3))
    (setf (cffi:mem-ref n-ptr :int) n)
    (setf (cffi:mem-ref x-ptr :float) x)
    (progn
      (setf (cffi:foreign-slot-value a-ptr 'float3 'cl-cuda::x) (float3-x a))
      (setf (cffi:foreign-slot-value a-ptr 'float3 'cl-cuda::y) (float3-y a))
      (setf (cffi:foreign-slot-value a-ptr 'float3 'cl-cuda::z) (float3-z a)))
    nil))

(is-expand
 (cl-cuda::with-kernel-arguments (args
                                  (cl-cuda::memory-block-device-ptr a)
                                  (cl-cuda::memory-block-device-ptr b)
                                  (cl-cuda::memory-block-device-ptr c)
                                  n-ptr)
   nil)
 (cffi:with-foreign-object (args :pointer 4)
   (setf (cffi:mem-aref args :pointer 0) (cl-cuda::memory-block-device-ptr a))
   (setf (cffi:mem-aref args :pointer 1) (cl-cuda::memory-block-device-ptr b))
   (setf (cffi:mem-aref args :pointer 2) (cl-cuda::memory-block-device-ptr c))
   (setf (cffi:mem-aref args :pointer 3) n-ptr)
   nil))

(is (cl-cuda::kernel-arg-names
      '((a float*) (b float*) (c float*) (n int) (x float3)))
    '(a b c n x))

(is (cl-cuda::kernel-arg-names-as-pointer
      '((a float*) (b float*) (c float*) (n int) (x float3)))
    '((cl-cuda::memory-block-device-ptr a)
      (cl-cuda::memory-block-device-ptr b)
      (cl-cuda::memory-block-device-ptr c)
      n-ptr x-ptr))

(is (cl-cuda::kernel-arg-foreign-pointer-bindings
      '((a float*) (b float*) (c float*) (n int) (x float3)))
    '((n n-ptr :int) (x x-ptr float3)))


;;; test defkernel

(defkernel let1 (void ())
  (let ((i 0))
    (return))
  (let ((i 0))))

(defun test-let1 ()
  (let ((dev-id 0))
    (with-cuda-context (dev-id)
      (let1 :grid-dim (list 1 1 1)
            :block-dim (list 1 1 1)))))

(defkernel use-one (void ())
  (let ((i (one)))
    (return)))

(defkernel one (int ())
  (return 1))

(defun test-one ()
  (let ((dev-id 0))
    (with-cuda-context (dev-id)
      (use-one :grid-dim (list 1 1 1)
               :block-dim (list 1 1 1)))))

(defkernel argument (void ((i int)))
  (let ((j i))
    (return)))

(defun test-argument ()
  (let ((dev-id 0))
    (with-cuda-context (dev-id)
      (argument 1 :grid-dim (list 1 1 1)
                  :block-dim (list 1 1 1)))))

(defkernel kernel-float3 (void ((ary float*) (x float3)))
  (set (aref ary 0) (+ (float3-x x) (float3-y x) (float3-z x))))

(let ((dev-id 0)
      (x (make-float3 1.0 2.0 3.0)))
  (with-cuda-context (dev-id)
    (with-memory-blocks ((a 'float 1))
      (setf (mem-aref a 0) 1.0)
      (memcpy-host-to-device a)
      (kernel-float3 a x :grid-dim '(1 1 1)
                         :block-dim '(1 1 1))
      (memcpy-device-to-host a)
      (is (mem-aref a 0) 6.0))))


;;; test valid-type-p

(diag "test valid-type-p")

(is (cl-cuda::basic-type-p 'void) t)
(is (cl-cuda::basic-type-p 'int) t)
(is (cl-cuda::basic-type-p 'float) t)

(is (cl-cuda::vector-type-p 'float3) t)
(is (cl-cuda::vector-type-p 'float4) t)
(is (cl-cuda::vector-type-p 'float5) nil)

(is (cl-cuda::valid-type-p 'void) t)
(is (cl-cuda::valid-type-p 'int) t)
(is (cl-cuda::valid-type-p 'float) t)
(is (cl-cuda::valid-type-p 'double) nil)
(is (cl-cuda::valid-type-p 'float3) t)
(is (cl-cuda::valid-type-p 'float4) t)
(is (cl-cuda::valid-type-p 'float*) t)
(is (cl-cuda::valid-type-p 'float**) t)
(is (cl-cuda::valid-type-p '*float**) nil)

(is (cl-cuda::pointer-type-p 'int) nil)
(is (cl-cuda::pointer-type-p 'float*) t)
(is (cl-cuda::pointer-type-p 'float3*) t)
(is (cl-cuda::pointer-type-p 'float4*) t)
(is (cl-cuda::pointer-type-p '*float*) nil)

(is (cl-cuda::non-pointer-type-p 'int) t)
(is (cl-cuda::non-pointer-type-p 'float*) nil)
(is (cl-cuda::non-pointer-type-p 'float3*) nil)
(is (cl-cuda::non-pointer-type-p 'float4*) nil)
(is (cl-cuda::non-pointer-type-p '*float3*) nil)

(is (cl-cuda::add-star 'int -1) 'int)
(is (cl-cuda::add-star 'int 0) 'int)
(is (cl-cuda::add-star 'int 1) 'int*)
(is (cl-cuda::add-star 'int 2) 'cl-cuda::int**)

(is (cl-cuda::remove-star 'int) 'int)
(is (cl-cuda::remove-star 'int*) 'int)
(is (cl-cuda::remove-star 'int**) 'int)

(is (cl-cuda::type-dimension 'int) 0)
(is (cl-cuda::type-dimension 'int*) 1)
(is (cl-cuda::type-dimension 'int**) 2)
(is (cl-cuda::type-dimension 'int***) 3)

(is-error (cl-cuda::cffi-type 'void) simple-error)
(is (cl-cuda::cffi-type 'int) :int)
(is (cl-cuda::cffi-type 'float) :float)
(is (cl-cuda::cffi-type 'float3) 'float3)
(is (cl-cuda::cffi-type 'float4) 'float4)
(is (cl-cuda::cffi-type 'float*) 'cu-device-ptr)
(is (cl-cuda::cffi-type 'float3*) 'cu-device-ptr)
(is (cl-cuda::cffi-type 'float4*) 'cu-device-ptr)

(is (cl-cuda::size-of 'void) 0)
(is (cl-cuda::size-of 'int) 4)
(is (cl-cuda::size-of 'float) 4)
(is (cl-cuda::size-of 'float3) 12)
(is (cl-cuda::size-of 'float4) 16)
(is (cl-cuda::size-of 'int*) 4)
(is (cl-cuda::size-of 'int**) 4)
(is (cl-cuda::size-of 'int***) 4)


;;; test kernel definition

(diag "test kernel definition")

(is (cl-cuda::empty-kernel-definition) '(nil nil))

(is (cl-cuda::define-kernel-function 'foo 'void '() '((return))
      (cl-cuda::empty-kernel-definition))
    '(((foo void () ((return)))) ()))

(is-error (cl-cuda::define-kernel-constant 'foo 1
            (cl-cuda::empty-kernel-definition))
          simple-error)

(is (cl-cuda::undefine-kernel-function 'foo
      (cl-cuda::define-kernel-function 'foo 'void '() '((return))
        (cl-cuda::empty-kernel-definition)))
    (cl-cuda::empty-kernel-definition))

(is-error (cl-cuda::undefine-kernel-function 'foo
            (cl-cuda::empty-kernel-definition))
          simple-error)

(is-error (cl-cuda::undefine-kernel-constant 'foo
            (cl-cuda::define-kernel-constant 'foo 1
              (cl-cuda::empty-kernel-definition)))
          simple-error)

(is-error (cl-cuda::undefine-kernel-constant 'foo
            (cl-cuda::empty-kernel-definition))
          simple-error)

(let ((def (cl-cuda::empty-kernel-definition)))
  (is (cl-cuda::kernel-function-exists-p 'foo def) nil))

(let ((def (cl-cuda::define-kernel-function 'foo 'void '() '()
             (cl-cuda::empty-kernel-definition))))
  (is (cl-cuda::kernel-function-exists-p 'foo def) t))

(let ((def (cl-cuda::define-kernel-function 'foo 'void '() '((return))
             (cl-cuda::empty-kernel-definition))))
  (is (cl-cuda::kernel-function-name 'foo def) 'foo)
  (is (cl-cuda::kernel-function-c-name 'foo def) "foo")
  (is (cl-cuda::kernel-function-return-type 'foo def) 'void)
  (is (cl-cuda::kernel-function-arg-bindings 'foo def) '())
  (is (cl-cuda::kernel-function-body 'foo def) '((return))))

(let ((def (cl-cuda::empty-kernel-definition)))
  (is-error (cl-cuda::kernel-function-name 'foo def) simple-error))

(let ((def (cl-cuda::empty-kernel-definition)))
  (is (cl-cuda::kernel-function-names def) nil))

(let ((def (cl-cuda::define-kernel-function 'foo 'void '() '((return))
             (cl-cuda::define-kernel-function 'bar 'int '() '((return 1))
               (cl-cuda::empty-kernel-definition)))))
  (is (cl-cuda::kernel-function-names def) '(foo bar)))


;;; test compile-kernel-definition

(diag "test compile-kernel-definition")

(let ((def (cl-cuda::define-kernel-function 'foo 'void '() '((return))
             (cl-cuda::empty-kernel-definition)))
      (c-code (cl-cuda::unlines "extern \"C\" __global__ void foo ();"
                                ""
                                "__global__ void foo ()"
                                "{"
                                "  return;"
                                "}"
                                "")))
  (is (cl-cuda::compile-kernel-definition def) c-code))


;;; test compile-kernel-function-prototype

(diag "test compile-kernel-function-prototype")

(let ((def (cl-cuda::define-kernel-function 'foo 'void '() '((return))
             (cl-cuda::empty-kernel-definition)))
      (c-code (cl-cuda::unlines "extern \"C\" __global__ void foo ();")))
  (is (cl-cuda::compile-kernel-function-prototype 'foo def) c-code))


;;; test compile-kernel-function

(diag "test compile-kernel-function")

(let ((def (cl-cuda::define-kernel-function 'foo 'void '() '((return))
             (cl-cuda::empty-kernel-definition)))
      (c-code (cl-cuda::unlines "__global__ void foo ()"
                                "{"
                                "  return;"
                                "}"
                                "")))
  (is (cl-cuda::compile-kernel-function 'foo def) c-code))


;;; test compile-function-specifier (not implemented)



;;; test compile-type (not implemented)



;;; test compile-identifier

(diag "test compile-identifier")

(is (cl-cuda::compile-identifier 'x) "x")
(is (cl-cuda::compile-identifier 'vec-add-kernel) "vec_add_kernel")
(is (cl-cuda::compile-identifier 'VecAdd_kernel) "vecadd_kernel")


;;; test compile-if

(diag "test compile-if")

(let ((lisp-code '(if 1
                      (return)
                      (return)))
      (c-code (cl-cuda::unlines "if (1) {"
                                "  return;"
                                "} else {"
                                "  return;"
                                "}")))
  (is (cl-cuda::compile-if lisp-code nil nil) c-code))

(let ((lisp-code '(if 1
                      (progn
                        (return 0)
                        (return 0))))
      (c-code (cl-cuda::unlines "if (1) {"
                                "  return 0;"
                                "  return 0;"
                                "}")))
  (is (cl-cuda::compile-if lisp-code nil nil) c-code))


;;; test compile-let  

(diag "test compile-let")

(let ((lisp-code '(let ((i 0))
                    (return)
                    (return)))
      (c-code (cl-cuda::unlines "{"
                                "  int i = 0;"
                                "  return;"
                                "  return;"
                                "}")))
  (is (cl-cuda::compile-let lisp-code nil nil) c-code))


;;; test compile-for

(diag "test compile-for")

(is (cl-cuda::for-p '(for ((a 0 15 1)
                           (b 0 15 1)))) t)
(is (cl-cuda::for-bindings '(for ((a 0 15 1)
                                  (b 0 15 1)))) '((a 0 15 1) (b 0 15 1)))
(is (cl-cuda::for-vars '(for ((a 0 15 1)
                              (b 0 15 1)))) '(a b))
(is (cl-cuda::for-begins '(for ((a 0 15 1)
                               (b 0 15 1)))) '(0 0))
(is (cl-cuda::for-ends '(for ((a 0 15 1)
                              (b 0 15 1)))) '(15 15))
(is (cl-cuda::for-steps '(for ((a 0 15 1)
                               (b 0 15))) nil nil) '(1 1))
(is (cl-cuda::for-statements '(for ((a 0 15))
                                (return))) '((return)))

(let ((lisp-code '(for ((a 0 15 1)
                        (b 0 15))
                    (+ a b)))
      (c-code (cl-cuda::unlines "for ( int a = 0, int b = 0; a <= 15, b <= 15; a += 1, b += 1 )"
                                "{"
                                "  (a + b);"
                                "}")))
  (is (cl-cuda::compile-for-begin-part lisp-code nil nil)
      "int a = 0, int b = 0")
  (is (cl-cuda::compile-for-end-part lisp-code nil nil)
      "a <= 15, b <= 15")
  (is (cl-cuda::compile-for-step-part lisp-code nil nil)
      "a += 1, b += 1")
  (is (cl-cuda::compile-for lisp-code nil nil) c-code))

(is-error (cl-cuda::compile-for '(for (())) nil nil) simple-error)
(is-error (cl-cuda::compile-for '(for ((a))) nil nil) simple-error)
(is-error (cl-cuda::compile-for '(for ((a 0))) nil nil) simple-error)

(let ((lisp-code '(for ((a 0.0 15.0))))
      (c-code (cl-cuda::unlines "for ( float a = 0.0; a <= 15.0; a += 1.0 )"
                                "{"
                                ""
                                "}")))
  (is (cl-cuda::compile-for lisp-code nil nil) c-code))


;;; test compile-with-shared-memory

(diag "test compile-with-shared-memory")

(is (cl-cuda::with-shared-memory-p '(with-shared-memory ((a float 16))
                                      (return)))
    t)
(is (cl-cuda::with-shared-memory-p '(with-shared-memory () (return))) t)
(is (cl-cuda::with-shared-memory-p '(with-shared-memory ())) t)
(is (cl-cuda::with-shared-memory-p '(with-shared-memory)) t)

(let ((lisp-code '(with-shared-memory ((a int 16)
                                       (b float 16 16))
                   (return)))
      (c-code (cl-cuda::unlines "{"
                                "  __shared__ int a[16];"
                                "  __shared__ float b[16][16];"
                                "  return;"
                                "}")))
  (is (cl-cuda::compile-with-shared-memory lisp-code nil nil) c-code))

(let ((lisp-code '(with-shared-memory () (return)))
      (c-code (cl-cuda::unlines "{"
                                "  return;"
                                "}")))
  (is (cl-cuda::compile-with-shared-memory lisp-code nil nil) c-code))

(let ((lisp-code '(with-shared-memory ()))
      (c-code (cl-cuda::unlines "{"
                                ""
                                "}")))
  (is (cl-cuda::compile-with-shared-memory lisp-code nil nil) c-code))

(is-error (cl-cuda::compile-with-shared-memory '(with-shared-memory) nil nil)
          simple-error)

(let ((lisp-code '(with-shared-memory ((a float))
                    (return)))
      (c-code (cl-cuda::unlines "{"
                                "  __shared__ float a;"
                                "  return;"
                                "}")))
  (is (cl-cuda::compile-with-shared-memory lisp-code nil nil) c-code))

(let ((lisp-code '(with-shared-memory (a float)
                    (return))))
  (is-error (cl-cuda::compile-with-shared-memory lisp-code nil nil)
            simple-error))

(let ((lisp-code '(with-shared-memory ((a float 16 16))
                    (set (aref a 0 0) 1.0)))
      (c-code (cl-cuda::unlines "{"
                                "  __shared__ float a[16][16];"
                                "  a[0][0] = 1.0;"
                                "}")))
  (is (cl-cuda::compile-with-shared-memory lisp-code nil nil) c-code))

(let ((lisp-code '(with-shared-memory ((a float 16 16))
                    (set (aref a 0) 1.0))))
  (is-error (cl-cuda::compile-with-shared-memory lisp-code nil nil)
            simple-error))


;;; test compile-set

(diag "test compile-set")

(is (cl-cuda::set-p '(set x 1)) t)
(is (cl-cuda::set-p '(set (aref x i) 1)) t)

(cl-cuda::with-type-environment (type-env ((x int)))
  (is (cl-cuda::compile-set '(set x 1) type-env nil) "x = 1;"))

(cl-cuda::with-type-environment (type-env ((x int*)))
  (is (cl-cuda::compile-set '(set (aref x 0) 1) type-env nil) "x[0] = 1;"))

(cl-cuda::with-type-environment (type-env ((x float3)))
  (is (cl-cuda::compile-set '(set (float3-x x) 1.0) type-env nil) "x.x = 1.0;"))


;;; test compile-place (not implemented)

 

;;; test compile-progn (not implemented)



;;; test compile-return (not implemented)



;;; test compile-syncthreads

(diag "test compile-syncthreads")

(is (cl-cuda::syncthreads-p '(syncthreads)) t)

(is (cl-cuda::compile-syncthreads '(syncthreads)) "__syncthreads();")


;;; test compile-function

(diag "test compile-function")

(is (cl-cuda::built-in-function-p '(+ 1 1)) t)
(is (cl-cuda::built-in-function-p '(- 1 1)) t)
(is (cl-cuda::built-in-function-p '(foo 1 1)) nil)

(is (cl-cuda::function-candidates '+)
    '(((int int) int "+")
      ((float float) float "+")))
(is-error (cl-cuda::function-candidates 'foo)
          simple-error)

(is (cl-cuda::built-in-function-infix-p '+) t)
(is (cl-cuda::built-in-function-infix-p 'expt) nil)
(is-error (cl-cuda::built-in-function-infix-p 'foo) simple-error)

(is (cl-cuda::built-in-function-prefix-p '+) nil)
(is (cl-cuda::built-in-function-prefix-p 'expt) t)
(is-error (cl-cuda::built-in-function-prefix-p 'foo) simple-error)

(is (cl-cuda::function-p 'a) nil)
(is (cl-cuda::function-p '()) nil)
(is (cl-cuda::function-p '1) nil)
(is (cl-cuda::function-p '(foo)) t)
(is (cl-cuda::function-p '(+ 1 1)) t)
(is (cl-cuda::function-p '(foo 1 1)) t)

(is-error (cl-cuda::function-operator 'a) simple-error)
(is (cl-cuda::function-operator '(foo)) 'foo)
(is (cl-cuda::function-operator '(+ 1 1)) '+)
(is (cl-cuda::function-operator '(foo 1 1)) 'foo)

(is-error (cl-cuda::function-operands 'a) simple-error)
(is (cl-cuda::function-operands '(foo)) '())
(is (cl-cuda::function-operands '(+ 1 1)) '(1 1))
(is (cl-cuda::function-operands '(foo 1 1)) '(1 1))

(is-error (cl-cuda::compile-function 'a nil nil) simple-error)
(let ((def (cl-cuda::define-kernel-function 'foo 'void '() '()
             (cl-cuda::empty-kernel-definition))))
  (is (cl-cuda::compile-function '(foo) nil def :statement-p t) "foo ();"))
(is (cl-cuda::compile-function '(+ 1 1) nil nil) "(1 + 1)")
(is (cl-cuda::compile-function '(+ 1 1 1) nil nil) "((1 + 1) + 1)")
(is-error (cl-cuda::compile-function '(foo 1 1) nil nil) simple-error)
(let ((def (cl-cuda::define-kernel-function 'foo 'void '((x int) (y int)) '()
             (cl-cuda::empty-kernel-definition))))
  (is (cl-cuda::compile-function '(foo 1 1) nil def :statement-p t)
      "foo (1, 1);")
  (is-error (cl-cuda::compile-function '(foo 1 1 1) nil def :statement-p t)
            simple-error))

(is (cl-cuda::compile-function '(float3 1.0 1.0 1.0) nil nil)
    "make_float3 (1.0, 1.0, 1.0)")
(is (cl-cuda::compile-function '(float4 1.0 1.0 1.0 1.0) nil nil)
    "make_float4 (1.0, 1.0, 1.0, 1.0)")


;;; test built-in arithmetic functions

(diag "test built-in arithmetic functions")

(is (cl-cuda::compile-function '(+ 1 1) nil nil) "(1 + 1)")
(is (cl-cuda::compile-function '(+ 1 1 1) nil nil) "((1 + 1) + 1)")
(is (cl-cuda::compile-function '(+ 1.0 1.0 1.0) nil nil) "((1.0 + 1.0) + 1.0)")
(is-error (cl-cuda::compile-function '(+ 1 1 1.0) nil nil) simple-error)
(is-error (cl-cuda::compile-function '(+) nil nil) simple-error)
(is-error (cl-cuda::compile-function '(+ 1) nil nil) simple-error)

(is (cl-cuda::built-in-arithmetic-function-valid-type-p '+ '() nil nil) nil)
(is (cl-cuda::built-in-arithmetic-function-valid-type-p '+ '(1 1) nil nil) t)
(is (cl-cuda::built-in-arithmetic-function-valid-type-p '+ '(1.0 1.0) nil nil)
    t)
(is (cl-cuda::built-in-arithmetic-function-valid-type-p '+ '(1 1.0) nil nil)
    nil)
(is-error (cl-cuda::built-in-arithmetic-function-valid-type-p 'foo '() nil nil)
          simple-error)

(is-error (cl-cuda::built-in-arithmetic-function-return-type '+ '() nil nil)
          simple-error)
(is (cl-cuda::built-in-arithmetic-function-return-type '+ '(1 1) nil nil) 'int)
(is (cl-cuda::built-in-arithmetic-function-return-type '+ '(1.0 1.0) nil nil)
    'float)
(is-error
 (cl-cuda::built-in-arithmetic-function-return-type '+ '(1 1.0) nil nil)
 simple-error)
(is-error (cl-cuda::built-in-arithmetic-function-return-type 'foo '() nil nil)
          simple-error)


;;; test compile-literal (not implemented)



;;; test compile-cuda-dimension (not implemented)



;;; test compile-variable-reference

(diag "test compile-variable-reference")

(is (cl-cuda::variable-reference-p 'x) t)
(is (cl-cuda::variable-reference-p 1) nil)
(is (cl-cuda::variable-reference-p '(aref x)) t)
(is (cl-cuda::variable-reference-p '(aref x i)) t)
(is (cl-cuda::variable-reference-p '(aref x i i)) t)
(is (cl-cuda::variable-reference-p '(aref x i i i)) t)
(is (cl-cuda::variable-reference-p '(float3-x x)) t)
(is (cl-cuda::variable-reference-p '(float3-y x)) t)
(is (cl-cuda::variable-reference-p '(float3-z x)) t)
(is (cl-cuda::variable-reference-p '(float4-x x)) t)
(is (cl-cuda::variable-reference-p '(float4-y x)) t)
(is (cl-cuda::variable-reference-p '(float4-z x)) t)
(is (cl-cuda::variable-reference-p '(float4-w x)) t)

(is-error (cl-cuda::compile-variable-reference 'x nil nil) simple-error)

(cl-cuda::with-type-environment (type-env ((x int)))
  (is (cl-cuda::compile-variable-reference 'x type-env nil) "x")
  (is-error (cl-cuda::compile-variable-reference '(aref x) type-env nil)
            simple-error)
  (is-error (cl-cuda::compile-variable-reference '(aref x 0) type-env nil)
            simple-error))

(cl-cuda::with-type-environment (type-env ((x int*)))
  (is (cl-cuda::compile-variable-reference 'x type-env nil) "x")
  (is (cl-cuda::compile-variable-reference '(aref x 0) type-env nil) "x[0]")
  (is-error (cl-cuda::compile-variable-reference '(aref x 0 0) type-env nil)
            simple-error))

(cl-cuda::with-type-environment (type-env ((x int**)))
  (is (cl-cuda::compile-variable-reference 'x type-env nil) "x")
  (is-error (cl-cuda::compile-variable-reference '(aref x 0) type-env nil)
            simple-error)
  (is (cl-cuda::compile-variable-reference '(aref x 0 0) type-env nil)
      "x[0][0]"))

(cl-cuda::with-type-environment (type-env ((x float3)))
  (is (cl-cuda::compile-variable-reference '(float3-x x) type-env nil) "x.x")
  (is (cl-cuda::compile-variable-reference '(float3-y x) type-env nil) "x.y")
  (is (cl-cuda::compile-variable-reference '(float3-z x) type-env nil) "x.z"))

(cl-cuda::with-type-environment (type-env ((x float4)))
  (is (cl-cuda::compile-variable-reference '(float4-x x) type-env nil) "x.x")
  (is (cl-cuda::compile-variable-reference '(float4-y x) type-env nil) "x.y")
  (is (cl-cuda::compile-variable-reference '(float4-z x) type-env nil) "x.z")
  (is (cl-cuda::compile-variable-reference '(float4-w x) type-env nil) "x.w"))


;;; test type-of-expression

(diag "test type-of-expression")

(is (cl-cuda::type-of-expression '1 nil nil) 'int)
(is (cl-cuda::type-of-expression '1.0 nil nil) 'float)

(is (cl-cuda::type-of-literal '1) 'int)
(is (cl-cuda::type-of-literal '1.0) 'float)
(is-error (cl-cuda::type-of-literal '1.0d0) simple-error)

(is (cl-cuda::type-of-function '(+ 1 1) nil nil) 'int)
(let ((def (cl-cuda::define-kernel-function 'foo 'int '((x int) (y int)) '()
             (cl-cuda::empty-kernel-definition))))
  (is (cl-cuda::type-of-function '(foo 1 1) nil def) 'int))

(is (cl-cuda::type-of-function '(+ 1 1 1) nil nil) 'int)
(is (cl-cuda::type-of-function '(+ 1.0 1.0 1.0) nil nil) 'float)
(is-error (cl-cuda::type-of-function '(+ 1 1 1.0) nil nil) simple-error)
(is (cl-cuda::type-of-function '(expt 1.0 1.0) nil nil) 'float)

(is (cl-cuda::type-of-expression 'cl-cuda::grid-dim-x nil nil) 'int)
(is (cl-cuda::type-of-expression 'cl-cuda::grid-dim-y nil nil) 'int)
(is (cl-cuda::type-of-expression 'cl-cuda::grid-dim-z nil nil) 'int)
(is (cl-cuda::type-of-expression 'cl-cuda::block-idx-x nil nil) 'int)
(is (cl-cuda::type-of-expression 'cl-cuda::block-idx-y nil nil) 'int)
(is (cl-cuda::type-of-expression 'cl-cuda::block-idx-z nil nil) 'int)
(is (cl-cuda::type-of-expression 'cl-cuda::block-dim-x nil nil) 'int)
(is (cl-cuda::type-of-expression 'cl-cuda::block-dim-y nil nil) 'int)
(is (cl-cuda::type-of-expression 'cl-cuda::block-dim-z nil nil) 'int)
(is (cl-cuda::type-of-expression 'cl-cuda::thread-idx-x nil nil) 'int)
(is (cl-cuda::type-of-expression 'cl-cuda::thread-idx-y nil nil) 'int)
(is (cl-cuda::type-of-expression 'cl-cuda::thread-idx-z nil nil) 'int)

(is-error (cl-cuda::type-of-variable-reference 'x nil) simple-error)

(cl-cuda::with-type-environment (type-env ((x int)))
  (is (cl-cuda::type-of-variable-reference 'x type-env) 'int)
  (is-error (cl-cuda::type-of-variable-reference '(aref x) type-env)
            simple-error))

(cl-cuda::with-type-environment (type-env ((x int*)))
  (is (cl-cuda::type-of-variable-reference 'x type-env) 'int*)
  (is (cl-cuda::type-of-variable-reference '(aref x 0) type-env) 'int)
  (is-error (cl-cuda::type-of-variable-reference '(aref x 0 0) type-env)
            simple-error))

(cl-cuda::with-type-environment (type-env ((x int**)))
  (is (cl-cuda::type-of-variable-reference 'x type-env) 'int**)
  (is-error (cl-cuda::type-of-variable-reference '(aref x 0) type-env)
            simple-error)
  (is (cl-cuda::type-of-variable-reference '(aref x 0 0) type-env) 'int))

(cl-cuda::with-type-environment (type-env ((x float3)))
  (is (cl-cuda::type-of-variable-reference '(float3-x x) type-env) 'float)
  (is (cl-cuda::type-of-variable-reference '(float3-y x) type-env) 'float)
  (is (cl-cuda::type-of-variable-reference '(float3-z x) type-env) 'float))

(cl-cuda::with-type-environment (type-env ((x float4)))
  (is (cl-cuda::type-of-variable-reference '(float4-x x) type-env) 'float)
  (is (cl-cuda::type-of-variable-reference '(float4-y x) type-env) 'float)
  (is (cl-cuda::type-of-variable-reference '(float4-z x) type-env) 'float)
  (is (cl-cuda::type-of-variable-reference '(float4-w x) type-env) 'float))


;;; test utilities

(is (cl-cuda::cl-cuda-symbolicate 'a) 'cl-cuda::a)
(is (cl-cuda::cl-cuda-symbolicate 'a 'b) 'cl-cuda::ab)


(finalize)
