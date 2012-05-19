#|
  This file is a part of cl-cuda project.
  Copyright (c) 2012 Masayuki Takagi (kamonama@gmail.com)
|#

(in-package :cl-user)
(defpackage cl-cuda-examples-asd
  (:use :cl :asdf))
(in-package :cl-cuda-examples-asd)

(defsystem cl-cuda-examples
  :author "Masayuki Takagi"
  :license "LLGPL"
  :depends-on (:cl-cuda
               :imago
               :cl-stopwatch)
  :components ((:module "examples"
                :serial t
                :components
                ((:file "diffuse0")
                 (:file "vector-add"))))
  :perform (load-op :after (op c) (asdf:clear-system c)))
