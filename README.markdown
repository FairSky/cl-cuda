# Cl-Cuda

Cl-cuda is a library to use Nvidia CUDA in Common Lisp programs. You can write CUDA kernel functions using the cl-cuda kernel description language which has Common Lisp-like syntax.

Cl-cuda is in very early stage of development. Any feedbacks are welcome.

## Example

Following is a part of vector addition example using cl-cuda which is based on the CUDA SDK's "vectorAdd" sample.

Kernel functions are simply written with `defkernel` macro and the cl-cuda kernel description language which has Common Lisp-like syntax.

Once kernel functions are defined, they can be launched as if ordinal Common Lisp functions except that they are followed by `:grid-dim` and `:block-dim` keyword parameters which provide the dimensions of the grid and block.

For the whole code, please see examples/vector-add.lisp.

    (defun random-init ...)
    (defun verivy-result ...)

    (defkernel vec-add-kernel (void ((a float*) (b float*) (c float*) (n int)))
      (let ((i (+ (* block-dim-x block-idx-x) thread-idx-x)))
        (if (< i n)
            (set (aref c i)
                 (+ (aref a i) (aref b i))))))
    
    (defun main ()
      (let ((dev-id 0)
            (n 1024)
            (threads-per-block 256)
            (blocks-per-grid (/ n threads-per-block)))
        (with-cuda-context (dev-id)
          (with-memory-blocks ((a 'float n)
                               (b 'float n)
                               (c 'float n))
            (random-init a n)
            (random-init b n)
            (memcpy-host-to-device a b)
            (vec-add-kernel a b c n
                            :grid-dim (list blocks-per-grid 1 1)
                            :block-dim (list threads-per-block 1 1))
            (memcpy-device-to-host c)
            (verify-result a b c n)))))

## Usage

I will write some usage later. For now, please see the examples directory.

## Installation

Since cl-cuda is not available in Quicklisp distribution yet, please use Quicklisp's local-projects feature.

    $ cd ~/quicklisp/local-projects
    $ git clone git://github.com/takagi/cl-cuda.git

Then use the `(ql:quickload :cl-cuda)` from `REPL` to load it.

Please notice that if you use slime-repl on OS X, you must load cl-cuda on inferior-lisp buffer instead of slime-repl buffer because OS X can only load libcuda library which is used in cl-cuda through CFFI from the main thread, otherwise an unexpected connection break down will happen.

Before using cl-cuda, you must specify where `libcuda` dynamic library is and where `nvcc` compiler is on your environment. Please change the related part of src/cl-cuda.lisp. I will make better way to specify them later.

I will write more about installation later.

## Rquirements

* NVIDIA CUDA-enabled GPU
* CUDA Toolkit, CUDA Drivers and CUDA SDK need to be installed
* SBCL Common Lisp compiler, because cl-cuda uses some sbcl extensions to run nvcc compiler externally. I will fix it later to make it possible to be used on other Common Lisp implementations. For now, if you want to use cl-cuda on those implementations other than SBCL, you can rewrite the related part of src/cl-cuda.lisp to suit your environment. It is only a few lines.

## API

### init-cuda-context

### release-cuda-context

### with-cuda-context

### alloc-memory-block

### free-memory-block

### with-memory-block

### mem-aref, (setf mem-aref)

### memcpy-host-to-device

### memcpy-device-to-host

## Kernel Definition Language

### DEFKERNEL macro

### IF statement

Syntax:

    IF test-form then-form [else-form]

Example:

    (if (= a 0)
        (return 0)
        (return 1))

Compiled:

    if (a == 0) {
      return 0;
    } else {
      return 1;
    }

### LET statement

### DO statement

Syntax:

    DO ({(var init-form step-form}*) (test-form) statement*

Example:

    (do ((a 0 (+ a 1))
         (b 0 (+ b 1)))
        ((> a 15))
      (do-some-statement))

Compiled:

    for ( int a = 0, int b = 0; ! (a > 15); a = a + 1, b = b + 1 )
    {
      do_some_statement ();
    }

### WITH-SHARED-MEMORY statement

Syntax:

    WITH-SHARED-MEMORY ({(var type size*)}*) statement*

Example:

    (with-shared-memory ((a int 16)
                         (b float 16 16))
      (return))

Compiled:

    {
      __shared__ int a[16];
      __shared__ float b[16][16];
      return;
    }

### SET statement

### PROGN statement

Syntax:

    PROGN statement*

Example:

    (progn
      (do-some-statement)
      (do-more-statement))

Compiled:

    do_some_statement ();
    do_more_statement ();

### RETURN statement

Syntax:

    RETURN [return-form]

Example:

    (return 0)

Compiled:

    return 0;

### SYNCTHREADS statement

Syntax:

    SYNCTHREADS

Example:

    (syncthreads)

Compiled:

    __syncthreads();

## Author

* Masayuki Takagi (kamonama@gmail.com)

## Copyright

Copyright (c) 2012 Masayuki Takagi (kamonama@gmail.com)

# License

Licensed under the LLGPL License.

