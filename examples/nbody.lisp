#|
  This file is a part of cl-cuda project.
  Copyright (c) 2012 Masayuki Takagi (kamonama@gmail.com)
|#

#|
  This file is based on the CUDA SDK's "nbody" sample.
|#

(in-package :cl-user)
(defpackage cl-cuda-examples.nbody
  (:use :cl
        :cl-cuda)
  (:export :main))
(in-package :cl-cuda-examples.nbody)


;;;
;;; Kernel functions
;;;

(defkernel body-body-interaction (float3 ((ai float3) (bi float4) (bj float4)))
  (let ((r (float3 (- (float4-x bj) (float4-x bi))
                   (- (float4-y bj) (float4-y bi))
                   (- (float4-z bj) (float4-z bi))))
        (softening-squared (* 0.1 0.1))
        (dist-sqr (+ (* (float3-x r) (float3-x r))
                     (* (float3-y r) (float3-y r))
                     (* (float3-z r) (float3-z r))
                     softening-squared))
        (inv-dist (rsqrtf dist-sqr))
        (inv-dist-cube (* inv-dist inv-dist inv-dist))
        (s (* (float4-w bj) inv-dist-cube)))
    (set (float3-x ai) (+ (float3-x ai) (* (float3-x r) s)))
    (set (float3-y ai) (+ (float3-y ai) (* (float3-y r) s)))
    (set (float3-z ai) (+ (float3-z ai) (* (float3-z r) s)))
    (return ai)))

(defkernel gravitation (float3 ((ipos float4) (accel float3) (shared-pos float4*)))
;  (with-shared-memory ((shared-pos float4 256))
    (for ((j 0 (- block-dim-x 1)))
      (set accel (body-body-interaction accel ipos (aref shared-pos j))));)
  (return accel))

(defkernel wrap (int ((x int) (m int)))
  (if (< x m)
      (return x)
      (return (- x m))))

(defkernel compute-body-accel (float3 ((body-pos float4) (positions float4*)
                                       (num-bodies int)))
  (with-shared-memory ((shared-pos float4 256))
    (let ((acc (float3 0.0 0.0 0.0))
          (p block-dim-x)
          (n num-bodies)
          (num-tiles (/ n p)))
      (for ((tile 0 (- num-tiles 1)))
        (let ((idx (+ (* (wrap (+ block-idx-x tile) grid-dim-x) p)
                      thread-idx-x)))
          (set (aref shared-pos thread-idx-x) (aref positions idx)))
        (syncthreads)
        (set acc (gravitation body-pos acc shared-pos))
        (syncthreads))
      (return acc))))

(defkernel integrate-bodies (void ((new-pos float4*) (old-pos float4*) (vel float4*)
                                   (delta-time float) (damping float)
                                   (total-num-bodies int)))
  (let ((index (+ (* block-idx-x block-dim-x) thread-idx-x)))
    (if (>= index total-num-bodies)
        (return))
    (let ((position (aref old-pos index))
          (accel (compute-body-accel position old-pos total-num-bodies))
          (velocity (aref vel index)))
      (set (float4-x velocity) (+ (float4-x velocity)
                                  (* (float3-x accel) delta-time)))
      (set (float4-y velocity) (+ (float4-y velocity)
                                  (* (float3-y accel) delta-time)))
      (set (float4-z velocity) (+ (float4-z velocity)
                                  (* (float3-z accel) delta-time)))
      
      (set (float4-x velocity) (* (float4-x velocity) damping))
      (set (float4-y velocity) (* (float4-y velocity) damping))
      (set (float4-z velocity) (* (float4-z velocity) damping))
      
      (set (float4-x position) (+ (float4-x position)
                                  (* (float4-x velocity) delta-time)))
      (set (float4-y position) (+ (float4-y position)
                                  (* (float4-y velocity) delta-time)))
      (set (float4-z position) (+ (float4-z position)
                                  (* (float4-z velocity) delta-time)))
      
      (set (aref new-pos index) position)
      (set (aref vel index) velocity))))


;;;
;;; cl-glut window subclass
;;;

(defclass nbody-window (glut:window)
  ((new-pos :initform nil)
   (old-pos :initform nil)
   (vel :initform nil)
   (delta-time :initform 0)
   (damping :initform 0)
   (num-bodies :initform 0)
   (p :initform 0))
  (:default-initargs :width 640 :height 480 :pos-x 100 :pos-y 100
                     :mode '(:double :rgb) :title "nbody"))


;;;
;;; cl-glut event handlers
;;;

(defmethod glut:display-window :before ((w nbody-window))
  (gl:enable :depth-test)
  (gl:clear-color 0 0 0 0)
  (nbody-demo-init))

(defmethod glut:display-window :after ((w nbody-window))
  (nbody-demo-release))

(defmethod glut:display ((w nbody-window))
  (with-slots (new-pos old-pos vel delta-time damping num-bodies p) w
    ;; update simulation
    (nbody-demo-update-simulation new-pos old-pos vel delta-time damping num-bodies p)
    (rotatef new-pos old-pos)
    ;; clear buffers
    (gl:clear :color-buffer :depth-buffer-bit)
    ;; view transform
    (gl:matrix-mode :modelview)
    (gl:load-identity)
    (gl:translate 0.0 0.0 -100.0)
    (gl:rotate 0.0 1.0 0.0 0.0)
    (gl:rotate 0.0 0.0 1.0 0.0)
    ;; display bodies
    (nbody-demo-display new-pos num-bodies)
    ;; swap buffers
    (glut:swap-buffers)
    ;; display frame rate
    (display-frame-rate num-bodies)))

(defmethod glut:reshape ((w nbody-window) width height)
  ;; configure on projection mode
  (gl:matrix-mode :projection)
  (gl:load-identity)
  (glu:perspective 60.0 (/ width height) 0.1 1000.0)
  ;; configure on model-view mode
  (gl:matrix-mode :modelview)
  (gl:viewport 0 0 width height))

(defmethod glut:idle ((w nbody-window))
  (glut:post-redisplay))


;;;
;;; Performance measurement functions
;;;

(defvar *flops-per-interaction* 20)

(defun compute-perf-stats (num-bodies elapsed-time fps-count iterations)
  (let ((milliseconds (/ elapsed-time fps-count)))
    (let* ((ifps (/ 1.0 (/ milliseconds 1000.0)))
           (interactions-per-second (/ (* num-bodies num-bodies iterations)
                                       (/ milliseconds 1000)
                                       1.0e9))
           (gflops (* interactions-per-second *flops-per-interaction*)))
      (values ifps interactions-per-second gflops))))

(let ((fps-count 0)
      (fps-limit 5)
      (template "CUDA N-Body (~A bodies): ~,1F fps | ~,1F BIPS | ~,1F GFLOP/s | single precision~%"))
  (defun display-frame-rate (num-bodies)
    (incf fps-count)
    (when (>= fps-count fps-limit)
      (multiple-value-bind (ifps interactions-per-second gflops)
          (compute-perf-stats num-bodies (get-elapsed-time) fps-count 1)
        (glut:set-window-title
          (format nil template num-bodies ifps interactions-per-second gflops))
        (setf fps-count 0)
        (setf fps-limit (max ifps 1.0))))))


;;;
;;; Timing functions
;;;

(let (start-event stop-event)

  (defun create-timer-events ()
    (setf start-event (cffi:foreign-alloc 'cu-event)
          stop-event (cffi:foreign-alloc 'cu-event))
    (cu-event-create start-event cu-event-default)
    (cu-event-create stop-event cu-event-default))
  
  (defun destroy-timer-events ()
    (cu-event-destroy (cffi:mem-ref start-event 'cu-event))
    (cu-event-destroy (cffi:mem-ref stop-event 'cu-event))
    (cffi:foreign-free start-event)
    (cffi:foreign-free stop-event))

  (defun start-timer ()
    (cu-event-record (cffi:mem-ref start-event 'cu-event)
                     (cffi:null-pointer)))

  (defun stop-and-synchronize-timer ()
    (cu-event-record (cffi:mem-ref stop-event 'cu-event)
                     (cffi:null-pointer))
    (cu-event-synchronize (cffi:mem-ref stop-event 'cu-event)))

  (defun get-elapsed-time ()
    (let (milliseconds)
      (cffi:with-foreign-object (pmilliseconds :float)
        (stop-and-synchronize-timer)
        (cu-event-elapsed-time pmilliseconds
                               (cffi:mem-ref start-event 'cu-event)
                               (cffi:mem-ref stop-event 'cu-event))
        (start-timer)
        (setf milliseconds (cffi:mem-ref pmilliseconds :float)))
      milliseconds)))

(defmacro with-cuda-timer (&body body)
  `(unwind-protect
        (progn
          (create-timer-events)
          ,@body)
     (destroy-timer-events)))


;;;
;;; NBodyDemo
;;;

(defun nbody-demo-init ()
  (particle-renderer-init)
  (nbody-demo-reset-renderer))

(defun nbody-demo-release ()
  (particle-renderer-release))

(defun nbody-demo-reset-renderer ()
  (particle-renderer-set-base-color #(1.0 0.6 0.3 1.0)))

(defun nbody-demo-update-simulation (new-pos old-pos vel delta-time damping num-bodies p)
  (integrate-nbody-system new-pos old-pos vel delta-time damping num-bodies p))

(defun nbody-demo-display (pos num-bodies)
  ; (particle-renderer-set-spirte-size ...)
  (memcpy-device-to-host pos)
  (particle-renderer-set-positions pos num-bodies)
  (particle-renderer-display))


;;;
;;; Particle Renderer
;;;

(defun unlines (&rest string-list)
  "Concatenates a list of strings and puts newlines between the elements."
  (format nil "~{~A~%~}" string-list))

(defparameter +vertex-shader+
  (unlines "void main()                                                            "
           "{                                                                      "
           "    float pointSize = 500.0 * gl_Point.size;                           "
           "    vec4 vert = gl_Vertex;                                             "
           "    vert.w = 1.0;                                                      "
           "    vec3 pos_eye = vec3 (gl_ModelViewMatrix * vert);                   "
           "    gl_PointSize = max(1.0, pointSize / (1.0 - pos_eye.z));            "
           "    gl_TexCoord[0] = gl_MultiTexCoord0;                                "
           ;"    gl_TexCoord[1] = gl_MultiTexCoord1;                                "
           "    gl_Position = ftransform();                                        "
           "    gl_FrontColor = gl_Color;                                          "
           "    gl_FrontSecondaryColor = gl_SecondaryColor;                        "
           "}                                                                      "))

(defparameter +pixel-shader+
  (unlines "uniform sampler2D splatTexture;                                        "
           "void main()                                                            "
           "{                                                                      "
           "    vec4 color2 = gl_SecondaryColor;                                   "
           "    vec4 color = (0.6 + 0.4 * gl_Color) * texture2D(splatTexture, gl_TexCoord[0].st);"
           "    gl_FragColor =                                                     "
           "         color * color2;" ;mix(vec4(0.1, 0.0, 0.0, color.w), color2, color.w);"
           "}                                                                      "))

(let ((m-pos           nil)
      (m-num-particles 0  )
      ;(m-point-size    1.0)
      (m-sprite-size   2.0)
      (m-vertex-shader nil)
      (m-pixel-shader  nil)
      (m-program       nil)
      (m-texture       0)
      (m-texture-data  (cffi:null-pointer))
      ;(m-pbo           nil)
      ;(m-vbo-color     nil)
      (m-base-color    #(0.0 0.0 0.0 0.0)))
  
  (defun particle-renderer-init ()
    (init-gl))
  
  (defun particle-renderer-release ()
    (cffi:foreign-free m-texture-data))
  
  (defun particle-renderer-set-positions (pos num-particles)
    (setf m-pos pos)
    (setf m-num-particles num-particles))
  
  (defun particle-renderer-set-base-color (color)
    (setf m-base-color (make-array 4))
    (dotimes (i 4)
      (setf (aref m-base-color i) (aref color i))))
  
  (defun particle-renderer-set-colors (color num-particles)
    (declare (ignore color num-particles))
    (not-implemented))
  
  (defun particle-renderer-set-pbo (pbo num-particles)
    (declare (ignore pbo num-particles))
    (not-implemented))
  
  (defun particle-renderer-display ()
    ; mode = PARTICLE_POINTS
    ;(gl:color 1.0 1.0 1.0)
    ;(gl:point-size m-point-size)
    ;(draw-points)
    ; mode = PARTICLE_SPRITES
    (gl:enable :point-sprite)
    (gl:tex-env :point-sprite :coord-replace :true)
    (gl:enable :vertex-program-point-size-nv)
    (gl:point-size m-sprite-size)
    (gl:blend-func :src-alpha :one)
    (gl:enable :blend)
    (gl:depth-mask :false)
    
    (gl:use-program m-program)
    (gl:uniformi (gl:get-uniform-location m-program "splatTexture") 0)
    
    (gl:active-texture :texture0-arb)
    (gl:bind-texture :texture-2d m-texture)
    
    (gl:color 1.0 1.0 1.0)
    (gl:secondary-color (aref m-base-color 0) (aref m-base-color 1) (aref m-base-color 2))
    
    (draw-points)
    
    (gl:use-program 0)
    
    (gl:disable :point-sprite-arb)
    (gl:disable :blend)
    (gl:depth-mask :true))
  
  (defun particle-renderer-set-point-size (size)
    (declare (ignore size))
    (not-implemented))
  
  (defun particle-renderer-set-sprite-size (size)
    (declare (ignore size))
    (not-implemented))
  
  (defun particle-renderer-reset-pbo ()
    (not-implemented))
  
  (defun init-gl ()
    ;; create shader objects
    (setf m-vertex-shader (gl:create-shader :vertex-shader))
    (setf m-pixel-shader (gl:create-shader :fragment-shader))
    ;; set shader source codes
    (gl:shader-source m-vertex-shader +vertex-shader+)
    (gl:shader-source m-pixel-shader +pixel-shader+)
    ;; compile source codes
    (gl:compile-shader m-vertex-shader)
    (gl:compile-shader m-pixel-shader)
    ;; create an empty program object
    (setf m-program (gl:create-program))
    ;; attach shader objects to program object
    (gl:attach-shader m-program m-vertex-shader)
    (gl:attach-shader m-program m-pixel-shader)
    ;; link program object
    (gl:link-program m-program)
    ;; create texture
    (create-texture 32))
  
  (defun eval-hermite (pa pb va vb u)
    (let ((u2 (* u u))
          (u3 (* u u u)))
      (let ((b0 (+ (- (* 2 u3) (* 3 u2)) 1))
            (b1 (+ (* -2 u3) (* 3 u2)))
            (b2 (+ (- u3 (* 2 u2)) u))
            (b3 (- u3 u)))
        (+ (* b0 pa) (* b1 pb) (* b2 va) (* b3 vb)))))
  
  (defun create-gaussian-map (b n)
    (cffi:with-foreign-object (m :float (* 2 n n))
      (let (xx y2 dist
            (incr (/ 2.0 n))
            (i 0)
            (j 0)
            (yy -1.0))
        (dotimes (y n)
          (incf yy incr)
          (setf y2 (* yy yy))
          (setf xx -1.0)
          (dotimes (x n)
            (incf xx incr)
            (incf i  2)
            (incf j  4)
            (setf dist (min (sqrt (+ (* xx xx) y2)) 1.0))
            (setf (cffi:mem-aref m :float i)      (eval-hermite 1.0 0 0 0 dist)
                  (cffi:mem-aref m :float (1+ i)) (cffi:mem-aref m :float i))
            (setf (cffi:mem-aref b :unsigned-char j)       (truncate (* (cffi:mem-aref m :float i) 255))
                  (cffi:mem-aref b :unsigned-char (+ j 1)) (truncate (* (cffi:mem-aref m :float i) 255))
                  (cffi:mem-aref b :unsigned-char (+ j 2)) (truncate (* (cffi:mem-aref m :float i) 255))
                  (cffi:mem-aref b :unsigned-char (+ j 3)) (truncate (* (cffi:mem-aref m :float i) 255))))))))
  
  (defun create-texture (resolution)
    (setf m-texture-data (cffi:foreign-alloc :unsigned-char :count (* 4 resolution resolution)))
    (create-gaussian-map m-texture-data resolution)
    (setf m-texture (first (gl:gen-textures 1)))
    (gl:bind-texture :texture-2d m-texture)
    (gl:tex-parameter :texture-2d :generate-mipmap :true)
    (gl:tex-parameter :texture-2d :texture-min-filter :linear-mipmap-linear)
    (gl:tex-parameter :texture-2d :texture-mag-filter :linear)
    (gl:tex-image-2d :texture-2d 0 :rgba8 resolution resolution 0
                     :rgba :unsigned-byte m-texture-data))
  
  (defun draw-points ()
    (gl:begin :points)
    (dotimes (i m-num-particles)
      (let ((p (mem-aref m-pos i)))
        (gl:vertex (float4-x p) (float4-y p) (float4-z p))))
    (gl:end)))


;;;
;;; main
;;;

(defun divided-point (inner outer k)
  (+ inner (* (- outer inner) k)))

(defun norm-float3 (x)
  (assert (float3-p x))
  (sqrt (+ (* (float3-x x) (float3-x x))
           (* (float3-y x) (float3-y x))
           (* (float3-z x) (float3-z x)))))

(defun normalize-float3 (x)
  (assert (float3-p x))
  (let ((r (norm-float3 x)))
    (if (< 1.0e-6 r)
        (make-float3 (/ (float3-x x) r)
                     (/ (float3-y x) r)
                     (/ (float3-z x) r))
        x)))

(defun cross (v0 v1)
  (assert (and (float3-p v0) (float3-p v1)))
  (make-float3 (- (* (float3-y v0) (float3-z v1))
                  (* (float3-z v0) (float3-y v1)))
               (- (* (float3-z v0) (float3-x v1))
                  (* (float3-x v0) (float3-z v1)))
               (- (* (float3-x v0) (float3-y v1))
                  (* (float3-y v0) (float3-x v1)))))

(defun randomize-bodies (pos vel cluster-scale velocity-scale num-bodies)
  (let* ((scale cluster-scale)
         (vscale (* scale velocity-scale))
         (inner (* 2.5 scale))
         (outer (* 4.0 scale)))
    (dotimes (i num-bodies)
      (let ((point (normalize-float3 (make-float3 (- (random 1.0) 0.5)
                                                  (- (random 1.0) 0.5)
                                                  (- (random 1.0) 0.5))))
            (k (divided-point inner outer (random 1.0))))
        (setf (mem-aref pos i) (make-float4 (* (float3-x point) k)
                                            (* (float3-y point) k)
                                            (* (float3-z point) k)
                                            1.0)))
      (let* ((axis (make-float3 0.0 0.0 1.0))
             (vv (cross (make-float3 (float4-x (mem-aref pos i))
                                     (float4-y (mem-aref pos i))
                                     (float4-z (mem-aref pos i)))
                        axis)))
        (setf (mem-aref vel i) (make-float4 (* (float3-x vv) vscale)
                                            (* (float3-y vv) vscale)
                                            (* (float3-z vv) vscale)
                                            1.0))))))

(defun reset (pos vel cluster-scale velocity-scale num-bodies)
  (randomize-bodies pos vel cluster-scale velocity-scale num-bodies))

(defun integrate-nbody-system (new-pos old-pos vel delta-time damping num-bodies p)
  (let ((grid-dim (list (ceiling (/ num-bodies p)) 1 1))
        (block-dim (list p 1 1)))
    (integrate-bodies new-pos old-pos vel delta-time damping num-bodies
                      :grid-dim grid-dim
                      :block-dim block-dim)))

(defun main ()
  (let ((dev-id 0)
        (num-bodies 2048)
        (cluster-scale 1.56)
        (velocity-scale 2.64)
        (delta-time 0.016)
        (damping 1.0)
        (p 256)
        (window (make-instance 'nbody-window)))
    (with-cuda-context (dev-id)
      (with-memory-blocks ((new-pos 'float4 num-bodies)
                           (old-pos 'float4 num-bodies)
                           (vel 'float4 num-bodies))
      (with-cuda-timer
        ;; set values to slots of the nbody window
        (setf (slot-value window 'new-pos) new-pos
              (slot-value window 'old-pos) old-pos
              (slot-value window 'vel) vel
              (slot-value window 'delta-time) delta-time
              (slot-value window 'damping) damping
              (slot-value window 'num-bodies) num-bodies
              (slot-value window 'p) p)
        ;; reset position and velocity of bodies
        (reset old-pos vel cluster-scale velocity-scale num-bodies)
        ;; copy position and velocity on host memory to device memory
        (memcpy-host-to-device old-pos vel)
        ;; start CUDA timer
        (start-timer)
        ;; start glut main loop
        (glut:display-window window))))))

(defun not-implemented ()
  (error "not implemented."))
