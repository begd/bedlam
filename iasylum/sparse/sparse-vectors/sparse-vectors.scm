;; Code taken from Chicken Scheme v4 repository - see meta file in same directory as this.

; Copyright (c) 1993-2007 by Richard Kelsey and Jonathan Rees. See file COPYING.

; Hilbert vectors are like vectors that grow as large as they need to.
; That is, they can be indexed by arbitrarily large nonnegative integers.

; The implementation allows for arbitrarily large gaps by arranging
; the entries in a tree.

; So-called because they live in an infinite-dimensional vector
; space...

(require-extension (lib iasylum/sparse/sparse-vectors/sparse-vectors-utils))

(module iasylum/sparse/sparse-vectors/sparse-vectors

	(make-sparse-vector
	 sparse-vector?
	 sparse-vector-ref
	 sparse-vector-set!
	 sparse-vector->list)
        
(import logicops)
(define bitwise-and logand)
  
; (import scheme chicken data-structures extras )

(define hilbert-log)
(define hilbert-node-size)
(define hilbert-mask)
(define minus-hilbert-log)

(define-record-type sparse-vector
  (make-hilbert height root default)
  sparse-vector?
  (height hilbert-height set-hilbert-height!)
  (root hilbert-root set-hilbert-root!)
  (default hilbert-default set-hilbert-default!))

;; (define-record-printer (sparse-vector x p)  (fprintf p "#~s" (sparse-vector->list x)) )

(define-record hilbert-default value)

(define (make-sparse-vector . rest)
  (let-optionals rest ((default #f))
    (make-hilbert 1 (make-vector hilbert-node-size (make-hilbert-default default)) 
		  (make-hilbert-default default))))

(define (sparse-vector-ref1 hilbert index)
  (let recur ((height (hilbert-height hilbert))
	      (index index))
    (if (= height 1)
	(let ((root (hilbert-root hilbert)))
	  (if (< index (vector-length root))
	      (vector-ref root index)
	      (hilbert-default hilbert)))
	(let ((node (recur (- height 1)
			   (arithmetic-shift index minus-hilbert-log))))
	  (if (vector? node)
	      (vector-ref node (bitwise-and index hilbert-mask))
	      (hilbert-default hilbert))))))

(define (sparse-vector-ref hilbert index)
  (let ((val (sparse-vector-ref1 hilbert index)))
    (if (hilbert-default? val)
	(hilbert-default-value val)
	val)))
	       
(define (sparse-vector-set! hilbert index value)
  (vector-set!
   (let recur ((height (hilbert-height hilbert))
	       (index index))
     (if (= height 1)
	 (make-higher-if-necessary hilbert index)
	 (let ((index (arithmetic-shift index minus-hilbert-log)))
	   (make-node-if-necessary
	    (recur (- height 1) index)
	    (bitwise-and index hilbert-mask)
	    (hilbert-default hilbert)))))
   (bitwise-and index hilbert-mask)
   value))

(define (make-higher-if-necessary hilbert index)
  (if (< index hilbert-node-size)
      (hilbert-root hilbert)
      (let ((new-root (make-vector hilbert-node-size (hilbert-default hilbert))))
	(vector-set! new-root 0 (hilbert-root hilbert))
	(set-hilbert-root! hilbert new-root)
	(set-hilbert-height! hilbert (+ (hilbert-height hilbert) 1))
	(let ((index (arithmetic-shift index minus-hilbert-log)))
	  (make-node-if-necessary (make-higher-if-necessary hilbert index)
				  (bitwise-and index hilbert-mask)
				  (hilbert-default hilbert))))))

(define (make-node-if-necessary node index default)
  (let ((v (vector-ref node index)))
    (if (vector? v) v
	(let ((new (make-vector hilbert-node-size default)))
	  (vector-set! node index new)
	  new))))

; For debugging

(define (sparse-vector->list h)
  (let recur ((node (hilbert-root h))
              (height (hilbert-height h))
              (more '(y)))
    (if (= height 0)
        (if (or (vector? node) (pair? more))
            (cons (if (hilbert-default? node) (hilbert-default-value node) node) more)
            '())
        (do ((i (- hilbert-node-size 1) (- i 1))
             (more more (recur (if (vector? node)
				   (let ((val (vector-ref node i)))
				     (if (hilbert-default? val)
					 (hilbert-default-value val)
					 val))
                                   (hilbert-default h))
                               (- height 1) more)))
            ((< i 0) more)))))
(set! hilbert-log 8)
(set! hilbert-node-size (arithmetic-shift 1 hilbert-log))
(set! hilbert-mask (- hilbert-node-size 1))
(set! minus-hilbert-log (- 0 hilbert-log))

)