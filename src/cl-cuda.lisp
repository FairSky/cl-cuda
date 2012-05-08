#|
  This file is a part of cl-cuda project.
  Copyright (c) 2012 Masayuki Takagi (kamonama@gmail.com)
|#

(in-package :cl-cuda)


;;; load CUDA driver API

(define-foreign-library libcuda
  (t (:default "/usr/local/cuda/lib/libcuda")))
(use-foreign-library libcuda)


;;; Types

(defctype cu-result :unsigned-int)
(defctype cu-device :int)
(defctype cu-context :pointer)
(defctype cu-module :pointer)
(defctype cu-function :pointer)
(defctype cu-stream :pointer)
(defctype cu-device-ptr :unsigned-int)
(defctype size-t :unsigned-int)


;;; Functions

;; cuInit
(defcfun (cu-init "cuInit") cu-result (flags :unsigned-int))

;; cuDeviceGet
(defcfun (cu-device-get "cuDeviceGet") cu-result
  (device (:pointer cu-device))
  (ordinal :int))

;; cuDeviceGetCount
(defcfun (cu-device-get-count "cuDeviceGetCount") cu-result
  (count (:pointer :int)))

;; cuDeviceComputeCapability
(defcfun (cu-device-compute-capability "cuDeviceComputeCapability") cu-result
  (major (:pointer :int))
  (minor (:pointer :int))
  (dev cu-device))

;; cuDeviceGetName
(defcfun (cu-device-get-name "cuDeviceGetName") cu-result
  (name :string)
  (len :int)
  (dev cu-device))

;; cuCtxCreate
(defcfun (cu-ctx-create "cuCtxCreate") cu-result
  (pctx (:pointer cu-context))
  (flags :unsigned-int)
  (dev cu-device))

;; cuCtxDestroy
(defcfun (cu-ctx-destroy "cuCtxDestroy") cu-result
  (pctx cu-context))

;; cuMemAlloc
(defcfun (cu-mem-alloc "cuMemAlloc") cu-result
  (dptr (:pointer cu-device-ptr))
  (bytesize size-t))

;; cuMemFree
(defcfun (cu-mem-free "cuMemFree") cu-result
  (dptr cu-device-ptr))

;; cuMemcpyHtoD
(defcfun (cu-memcpy-host-to-device "cuMemcpyHtoD")
         cu-result
         (dst-device cu-device-ptr)
         (src-host :pointer)
         (byte-count size-t))

;; cuMemcpyDtoH
(defcfun (cu-memcpy-device-to-host "cuMemcpyDtoH")
         cu-result
         (dst-host :pointer)
         (src-device cu-device-ptr)
         (byte-count size-t))

;; cuModuleLoad
(defcfun (cu-module-load "cuModuleLoad")
         cu-result
         (module (:pointer cu-module))
         (fname :string))

;; cuModuleUnload
(defcfun (cu-module-unload "cuModuleUnload")
         cu-result
         (module cu-module))

;; cuModuleGetFunction
(defcfun (cu-module-get-function "cuModuleGetFunction")
         cu-result
         (hfunc (:pointer cu-function))
         (hmod cu-module)
         (name :string))

;; cuLaunchKernel
(defcfun (cu-launch-kernel "cuLaunchKernel")
         cu-result
         (f cu-function)
         (grid-dim-x :unsigned-int)
         (grid-dim-y :unsigned-int)
         (grid-dim-z :unsigned-int)
         (block-dim-x :unsigned-int)
         (block-dim-y :unsigned-int)
         (block-dim-z :unsigned-int)
         (shared-mem-bytes :unsigned-int)
         (hstream cu-stream)
         (kernel-params (:pointer :pointer))
         (extra (:pointer :pointer)))


;;; Constants
(defvar +cuda-success+ 0)


;;; Helpers
(defun check-cuda-errors (err)
  (when (/= +cuda-success+ err)
    (error (format nil "check-cuda-errors: Driver API error = ~A ~%" err))))

(defmacro with-cuda-context (args &body body)
  (destructuring-bind (dev-id) args
    (let ((flags 0))
      (with-gensyms (device ctx)
        `(with-foreign-objects ((,device 'cu-device)
                                (,ctx 'cu-context))
           (check-cuda-errors (cu-init 0))
           (check-cuda-errors (cu-device-get ,device ,dev-id))
           (check-cuda-errors (cu-ctx-create ,ctx ,flags
                                             (mem-ref ,device 'cu-device)))
           (unwind-protect
             (progn ,@body)
             (progn
               (kernel-manager-unload *kernel-manager*)
               (check-cuda-errors (cu-ctx-destroy
                                   (mem-ref ,ctx 'cu-context))))))))))

(defmacro with-cuda-memory-block (args &body body)
  (destructuring-bind (dptr size) args
    `(with-foreign-object (,dptr 'cu-device-ptr)
       (check-cuda-errors (cu-mem-alloc ,dptr ,size))
       (unwind-protect
            (progn ,@body)
         (check-cuda-errors (cu-mem-free (mem-ref ,dptr 'cu-device-ptr)))))))

(defmacro with-cuda-memory-blocks (bindings &body body)
  (if bindings
      `(with-cuda-memory-block ,(car bindings)
         (with-cuda-memory-blocks ,(cdr bindings)
           ,@body))
      `(progn ,@body)))


;;; defkernel

(defmacro with-module-and-function (args &body body)
  (destructuring-bind (hfunc module function) args
    (with-gensyms (module-name func-name hmodule)
      `(with-foreign-string (,module-name ,module)
         (with-foreign-string (,func-name ,function)
           (with-foreign-objects ((,hmodule 'cu-module)
                                  (,hfunc 'cu-function))
             (check-cuda-errors (cu-module-load ,hmodule ,module-name))
             (check-cuda-errors
              (cu-module-get-function ,hfunc (mem-ref ,hmodule 'cu-module)
                                      ,func-name))
             ,@body))))))

(defmacro with-non-pointer-arguments (bindings &body body)
  (if bindings
      (labels ((ptr-type-pair (binding)
                 (destructuring-bind (_ var-ptr type) binding
                   (declare (ignorable _))
                   (list var-ptr type)))
               (foreign-pointer-setf (binding)
                 (destructuring-bind (var var-ptr type) binding
                   `(setf (mem-ref ,var-ptr ,type) ,var))))
        `(with-foreign-objects (,@(mapcar #'ptr-type-pair bindings))
           ,@(mapcar #'foreign-pointer-setf bindings)
           ,@body))
      `(progn ,@body)))

(defmacro with-kernel-arguments (args &body body)
  (let ((var (car args))
        (ptrs (cdr args)))
    `(with-foreign-object (,var :pointer 4)
       ,@(loop for ptr in ptrs
            for i from 0
            collect `(setf (mem-aref ,var :pointer ,i) ,ptr))
       ,@body)))

(defun kernel-defun (mgr mgr-symbol name)
  (let ((kargs (kernel-manager-function-arg-bindings mgr name)))
    (with-gensyms (hfunc args)
      `(defun ,name (,@(kernel-arg-names kargs) &key grid-dim block-dim)
         (let ((,hfunc (ensure-kernel-function-loaded ,mgr-symbol ',name)))
           (with-non-pointer-arguments
               ,(kernel-arg-foreign-pointer-bindings kargs)
             (with-kernel-arguments
                 (,args ,@(kernel-arg-names-as-pointer kargs))
               (destructuring-bind
                     (grid-dim-x grid-dim-y grid-dim-z) grid-dim
               (destructuring-bind
                     (block-dim-x block-dim-y block-dim-z) block-dim
                 (check-cuda-errors
                  (cu-launch-kernel (mem-ref ,hfunc 'cu-function)
                                    grid-dim-x grid-dim-y grid-dim-z
                                    block-dim-x block-dim-y block-dim-z
                                    0 (null-pointer)
                                    ,args (null-pointer))))))))))))

(defmacro defkernel (name arg-bindings fname &rest body)
;  (check-kernel-function arg-bindings body)
  (kernel-manager-define-function *kernel-manager* name arg-bindings fname body)
  (kernel-defun *kernel-manager* '*kernel-manager* name))


;;; kernel-arg

(defun non-pointer-type-p (type)
  (assert (valid-type-p type))
  (find type '(int float)))

(defun pointer-type-p (type)
  (assert (valid-type-p type))
  (find type '(int* float*)))

(defun valid-type-p (type)
  (find type '(int int* float float*)))

(defvar +cffi-type-table+ '(int :int
                            float :float))

(defun cffi-type (type)
  (if (pointer-type-p type)
      'cu-device-ptr
      (getf +cffi-type-table+ type)))

(defun kernel-arg-names (arg-bindings)
  ;; ((a float*) (b float*) (c float*) (n int)) → (a b c n)
  (mapcar #'car arg-bindings))

(defun kernel-arg-names-as-pointer (arg-bindings)
  ;; ((a float*) (b float*) (c float*) (n int)) → (a b c n-ptr)
  (mapcar #'arg-name-as-pointer arg-bindings))

(defun arg-name-as-pointer (arg-binding)
  ; (a float*) -> a, (n int) -> n-ptr
  (destructuring-bind (var type) arg-binding
    (if (non-pointer-type-p type)
        (var-ptr var)
        var)))

(defun kernel-arg-foreign-pointer-bindings (arg-bindings)
  ; ((a float*) (b float*) (c float*) (n int)) → ((n n-ptr :int))
  (mapcar #'foreign-pointer-binding
    (remove-if-not #'arg-binding-with-non-pointer-type-p arg-bindings)))

(defun foreign-pointer-binding (arg-binding)
  (destructuring-bind (var type) arg-binding
    (list var (var-ptr var) (cffi-type type))))

(defun arg-binding-with-non-pointer-type-p (arg-binding)
  (non-pointer-type-p (cadr arg-binding)))

(defun var-ptr (var)
  (symbolicate var "-PTR"))


;;; kernel-manager

(defun make-kernel-manager ()
  (list (make-module-info) (make-hash-table)))

(defmacro module-info (mgr)
  `(car ,mgr))

(defmacro function-table (mgr)
  `(cadr ,mgr))

(defun function-info (mgr name)
  (or (gethash name (function-table mgr))
      (error (format nil "undefined kernel function: ~A" name))))

(defun (setf function-info) (info mgr name)
  (setf (gethash name (function-table mgr)) info))

(defmacro kernel-manager-module-handle (mgr)
  `(module-handle (module-info ,mgr)))

(defmacro kernel-manager-module-path (mgr)
  `(module-path (module-info ,mgr)))

(defmacro kernel-manager-module-compilation-needed (mgr)
  `(module-compilation-needed (module-info ,mgr)))

(defun kernel-manager-function-exists-p (mgr name)
  (multiple-value-bind (_ p) (gethash name (function-table mgr))
    (declare (ignorable _))
    p))

(defmacro kernel-manager-function-name (mgr name)
  `(function-name (function-info ,mgr ,name)))

(defmacro kernel-manager-function-handle (mgr name)
  `(function-handle (function-info ,mgr ,name)))

(defmacro kernel-manager-function-arg-bindings (mgr name)
  `(function-arg-bindings (function-info ,mgr ,name)))

(defmacro kernel-manager-function-c-name (mgr name)
  `(function-c-name (function-info ,mgr ,name)))

(defmacro kernel-manager-function-code (mgr name)
  `(function-code (function-info ,mgr ,name)))

(defun kernel-manager-define-function (mgr name arg-bindings fname body)
  (if (kernel-manager-function-exists-p mgr name)
      (when (function-modified-p (function-info mgr name) arg-bindings body)
        (setf (kernel-manager-function-arg-bindings mgr name) arg-bindings)
        (setf (kernel-manager-function-code mgr name) body)
        (setf (kernel-manager-module-compilation-needed mgr) t))
      (setf (function-info mgr name)
            (make-function-info name arg-bindings fname body))))

(defun function-modified-p (info arg-bindings code)
  (or (nequal arg-bindings (function-arg-bindings info))
      (nequal code (function-code info))))

(defun nequal (&rest args)
  (not (apply #'equal args)))

(defun %kernel-manager-as-list (mgr)
  (let ((ret))
    (maphash #'(lambda (key val)
                 (push (cons key val) ret))
             (function-table mgr))
    (list (module-info mgr) ret)))

(defun kernel-manager-load-function (mgr name)
  (unless (kernel-manager-module-handle mgr)
    (error "kernel module is not loaded yet."))
  (when (kernel-manager-function-handle mgr name)
    (error "kernel function \"~A\" is already loaded." name))
  (let ((hmodule (kernel-manager-module-handle mgr))
        (hfunc (foreign-alloc 'cu-function))
        (fname (kernel-manager-function-c-name mgr name)))
    (check-cuda-errors
     (cu-module-get-function hfunc (mem-ref hmodule 'cu-module) fname))
    (setf (kernel-manager-function-handle mgr name) hfunc)))

(defun kernel-manager-load-module (mgr)
  (when (kernel-manager-module-handle mgr)
    (error "kernel module is already loaded."))
  (unless (no-kernel-functions-loaded-p mgr)
    (error "some kernel functions are already loaded."))
  (let ((hmodule (foreign-alloc 'cu-module))
        (path (kernel-manager-module-path mgr)))
    (check-cuda-errors (cu-module-load hmodule path))
    (setf (kernel-manager-module-handle mgr) hmodule)))

(defun no-kernel-functions-loaded-p (mgr)
  "return t if no kernel functions are loaded."
  (notany #'(lambda (key)
              (kernel-manager-function-handle mgr key))
          (hash-table-keys (function-table mgr))))

(defun kernel-manager-unload (mgr)
  (swhen (kernel-manager-module-handle mgr)
    (check-cuda-errors (cu-module-unload (mem-ref it 'cu-module))))
  (free-function-handles mgr)
  (free-module-handle mgr))

(defun free-module-handle (mgr)
  (swhen (kernel-manager-module-handle mgr)
    (foreign-free it)
    (setf it nil)))

(defun free-function-handles (mgr)
  (maphash-values #'free-function-handle (function-table mgr)))

(defun free-function-handle (info)
  (swhen (function-handle info)
    (foreign-free it)
    (setf it nil)))

(defvar +temporary-path-template+ "/tmp/cl-cuda")
(defvar +nvcc-path+ "/usr/local/cuda/bin/nvcc")

(defun kernel-manager-compile (mgr)
  (when (kernel-manager-module-handle mgr)
    (error "kernel module is already loaded."))
  (unless (no-kernel-functions-loaded-p mgr)
    (error "some kernel functions are already loaded."))
  (let* ((temp-path (osicat-posix:mktemp +temporary-path-template+))
         (cu-path (concatenate 'string temp-path ".cu"))
         (ptx-path (concatenate 'string temp-path ".ptx")))
;    (kernel-manager-output-kernel-code mgr cu-path)
;    (compile-kernel-module cu-path ptx-path)
    (compile-kernel-module "/Developer/GPU Computing/C/src/vectorAddDrv/vectorAdd_kernel.cu" ptx-path)
    (setf (kernel-manager-module-path mgr) ptx-path)
    (setf (kernel-manager-module-compilation-needed mgr) nil)
    (values)))

(defun compile-kernel-module (cu-path ptx-path)
  (output-nvcc-command cu-path ptx-path)
  (with-output-to-string (out)
    (let ((p (sb-ext:run-program +nvcc-path+ `("-ptx" "-o" ,ptx-path ,cu-path)
                                 :error out)))
      (unless (= 0 (sb-ext:process-exit-code p))
        (error (format nil "nvcc exits with code: ~A~%~A"
                       (sb-ext:process-exit-code p)
                       (get-output-stream-string out))))))
  (values))

(defun output-nvcc-command (cu-path ptx-path)
  (format t "nvcc -ptx -o ~A ~A~%" cu-path ptx-path))

(defun kernel-manager-kernel-code (mgr)
  (declare (ignorable mgr))
  (error "Not implemented yet."))

(defun kernel-manager-output-kernel-code (mgr path)
  (declare (ignorable mgr path))
  (error "Not implemented yet."))


;;; module-info

(defun make-module-info ()
  (list nil nil t))

(defmacro module-handle (info)
  `(car ,info))

(defmacro module-path (info)
  `(cadr ,info))

(defmacro module-compilation-needed (info)
  `(caddr ,info))


;;; function-info ::= (name hfunc arg-bindings c-name code)

(defun make-function-info (name arg-bindings c-name code)
  (list name nil arg-bindings c-name code))

(defmacro function-name (info)
  `(car ,info))

(defmacro function-handle (info)
  `(cadr ,info))

(defmacro function-arg-bindings (info)
  `(caddr ,info))

(defmacro function-c-name (info)
  `(cadddr ,info))  ; fix later to give c style name using lisp style name

(defmacro function-code (info)
  `(car (cddddr ,info)))


;;; ensuring kernel manager

(defun ensure-kernel-function-loaded (mgr name)
  (ensure-kernel-module-loaded mgr)
  (or (kernel-manager-function-handle mgr name)
      (kernel-manager-load-function mgr name)))

(defun ensure-kernel-module-loaded (mgr)
  (ensure-kernel-module-compiled mgr)
  (or (kernel-manager-module-handle mgr)
      (kernel-manager-load-module mgr)))

(defun ensure-kernel-module-compiled (mgr)
  (when (kernel-manager-module-compilation-needed mgr)
    (kernel-manager-compile mgr))
  (values))


;;; *kernel-manager*

(defvar *kernel-manager*
  (make-kernel-manager))
