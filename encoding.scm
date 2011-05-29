;;;; File: "encoding.scm", Time-stamp: <2009-08-22 14:39:05 feeley>

;;;; Copyright (C) 2004-2009 by Marc Feeley and Vincent St-Amour
;;;; All Rights Reserved.

(include "encoding-arduino.scm")
(include "encoding-default.scm")

(define min-fixnum-encoding 3)
(define min-fixnum -1)
(define max-fixnum 255)
(define min-rom-encoding (+ min-fixnum-encoding (- max-fixnum min-fixnum) 1))
(define min-ram-encoding 512)
(define max-ram-encoding 703) ;; 1279
(define min-vec-encoding 704) ;; 1280
(define max-vec-encoding 895) ;; 2047

(define code-start #x4000)

(define (predef-constants) (list))

(define (predef-globals) (list))

(define (encode-direct obj)
  (cond ((eq? obj #f)
         0)
        ((eq? obj #t)
         1)
        ((eq? obj '())
         2)
        ((and (integer? obj)
              (exact? obj)
              (>= obj min-fixnum)
              (<= obj max-fixnum))
         (+ obj (- min-fixnum-encoding min-fixnum)))
        (else
         #f)))

(define (translate-constant obj)
  (if (char? obj)
      (char->integer obj)
      obj))

(define (encode-constant obj constants)
  (let ((o (translate-constant obj)))
    (let ((e (encode-direct o)))
      (if e
          e
          (let ((x (assoc o constants)))
            (if x
                (vector-ref (cdr x) 0)
                (compiler-error "unknown object" obj)))))))

;; TODO actually, seem to be in a pair, scheme object in car, vector in cdr
;; constant objects are represented by vectors
;; 0 : encoding (ROM address) TODO really the ROM address ?
;; 1 : TODO asm label constant ?
;; 2 : number of occurences of this constant in the code
;; 3 : pointer to content, used at encoding time
(define (add-constant obj constants from-code? cont)
  (let ((o (translate-constant obj)))
    (let ((e (encode-direct o)))
      (if e
          (cont constants)
          (let ((x (assoc o constants)))
            (if x
                (begin
                  (if from-code?
                      (vector-set! (cdr x) 2 (+ (vector-ref (cdr x) 2) 1)))
                  (cont constants))
                (let* ((descr
                        (vector #f
                                (asm-make-label 'constant)
                                (if from-code? 1 0)
                                #f))
                       (new-constants
                        (cons (cons o descr)
                              constants)))
                  (cond ((pair? o)
                         (add-constants (list (car o) (cdr o))
                                        new-constants
                                        cont))
                        ((symbol? o)
                         (cont new-constants))
                        ((string? o)
                         (let ((chars (map char->integer (string->list o))))
                           (vector-set! descr 3 chars)
                           (add-constant chars
                                         new-constants
                                         #f
                                         cont)))
                        ((vector? o) ; ordinary vectors are stored as lists
                         (let ((elems (vector->list o)))
                           (vector-set! descr 3 elems)
                           (add-constant elems
                                         new-constants
                                         #f
                                         cont)))
			((u8vector? o)			 
			 (let ((elems (u8vector->list o)))
			   (vector-set! descr 3 elems)
			   (add-constant elems
					 new-constants
					 #f
					 cont)))
			((and (number? o) (exact? o))
			 ; (pp (list START-ENCODING: o))
			 (let ((hi (arithmetic-shift o -16)))
			   (vector-set! descr 3 hi)
			   ;; recursion will stop once we reach 0 or -1 as the
			   ;; high part, which will be matched by encode-direct
			   (add-constant hi
					 new-constants
					 #f
					 cont)))
                        (else
                         (cont new-constants))))))))))

(define (add-constants objs constants cont)
  (if (null? objs)
      (cont constants)
      (add-constant (car objs)
                    constants
                    #f
                    (lambda (new-constants)
                      (add-constants (cdr objs)
                                     new-constants
                                     cont)))))

(define (add-global var globals cont)
  (let ((x (assq var globals)))
    (if x	
        (begin
	  ;; increment reference counter
	  (vector-set! (cdr x) 1 (+ (vector-ref (cdr x) 1) 1))
	  (cont globals))
        (let ((new-globals
               (cons (cons var (vector (length globals) 1))
                     globals)))
	  (cont new-globals)))))

(define (sort-constants constants)
  (let ((csts
         (sort-list constants
                    (lambda (x y)
                      (> (vector-ref (cdr x) 2)
                         (vector-ref (cdr y) 2))))))
    (let loop ((i min-rom-encoding)
               (lst csts))
      (if (null? lst)
	  ;; constants can use all the rom addresses up to 256 constants since
	  ;; their number is encoded in a byte at the beginning of the bytecode
          (if (or (> i min-ram-encoding) (> (- i min-rom-encoding) 256))
	      (compiler-error "too many constants")
	      csts)
          (begin
            (vector-set! (cdr (car lst)) 0 i)
            (loop (+ i 1)
                  (cdr lst)))))))

(define (sort-globals globals) ;; TODO a lot in common with sort-constants, ABSTRACT
  (let ((glbs
	 (sort-list globals
		    (lambda (x y)
		      (> (vector-ref (cdr x) 1)
			 (vector-ref (cdr y) 1))))))
    (let loop ((i 0)
	       (lst glbs))
      (if (null? lst)
	  (if (> i 256) ;; the number of globals is encoded on a byte
	      (compiler-error "too many global variables")
	      glbs)	  
	  (begin
	    (vector-set! (cdr (car lst)) 0 i)
	    (loop (+ i 1)
		  (cdr lst)))))))

(define assemble
  (lambda (code hex-filename)
    (let loop1 ((lst code)
                (constants (predef-constants))
                (globals (predef-globals))
                (labels (list)))
      (if (pair? lst)

          (let ((instr (car lst)))
            (cond ((number? instr)
                   (loop1 (cdr lst)
                          constants
                          globals
                          (cons (cons instr (asm-make-label 'label))
                                labels)))
                  ((eq? (car instr) 'push-constant)
                   (add-constant (cadr instr)
                                 constants
                                 #t
                                 (lambda (new-constants)
                                   (loop1 (cdr lst)
                                          new-constants
                                          globals
                                          labels))))
                  ((memq (car instr) '(push-global set-global))
                   (add-global (cadr instr)
                               globals
                               (lambda (new-globals)
                                 (loop1 (cdr lst)
                                        constants
                                        new-globals
                                        labels))))
                  (else
                   (loop1 (cdr lst)
                          constants
                          globals
                          labels))))

          (let ((constants (sort-constants constants))
 		(globals   (sort-globals   globals)))

            (define (label-instr label opcode-rel4 opcode-rel8 opcode-rel12 opcode-abs16 opcode-sym)
;;;;;;;;;;;;;;;;;              (if (eq? opcode-sym 'goto) (pp (list 'goto label)))
              (asm-at-assembly
	       ;; if the distance from pc to the label fits in a single byte,
	       ;; a short instruction is used, containing a relative address
	       ;; if not, the full 16-bit label is used
	       (lambda (self)
                 (let ((dist (- (asm-label-pos label) (+ self 1))))
                   (and opcode-rel4
                        (<= 0 dist 15) ;; TODO go backwards too ?
                        1)))
	       (lambda (self)
                 (let ((dist (- (asm-label-pos label) (+ self 1))))
                   (if stats?
                       (let ((key (list '---rel-4bit opcode-sym)))
                         (let ((n (table-ref instr-table key 0)))
                           (table-set! instr-table key (+ n 1)))))
                   (asm-8 (+ opcode-rel4 dist))))

	       (lambda (self)
                 (let ((dist (+ 128 (- (asm-label-pos label) (+ self 2)))))
                   (and opcode-rel8
                        (<= 0 dist 255)
                        2)))
	       (lambda (self)
                 (let ((dist (+ 128 (- (asm-label-pos label) (+ self 2)))))
                   (if stats?
                       (let ((key (list '---rel-8bit opcode-sym)))
                         (let ((n (table-ref instr-table key 0)))
                           (table-set! instr-table key (+ n 1)))))
                   (asm-8 opcode-rel8)
                   (asm-8 dist)))

	       (lambda (self)
                 (let ((dist (+ 2048 (- (asm-label-pos label) (+ self 2)))))
                   (and opcode-rel12
                        (<= 0 dist 4095)
                        2)))
	       (lambda (self)
                 (let ((dist (+ 2048 (- (asm-label-pos label) (+ self 2)))))
                   (if stats?
                       (let ((key (list '---rel-12bit opcode-sym)))
                         (let ((n (table-ref instr-table key 0)))
                           (table-set! instr-table key (+ n 1)))))
                   (asm-8 (+ opcode-rel12 (quotient dist 256)))
                   (asm-8 (modulo dist 256))))

               (lambda (self)
		 3)
               (lambda (self)
		 (let ((pos (- (asm-label-pos label) code-start)))
                   (if stats?
                       (let ((key (list '---abs-16bit opcode-sym)))
                         (let ((n (table-ref instr-table key 0)))
                           (table-set! instr-table key (+ n 1)))))
                   (asm-8 opcode-abs16)
                   (asm-8 (quotient pos 256))
                   (asm-8 (modulo pos 256))))))

            (define (push-constant n)
              (if (<= n 31)
                  (begin
                    (if stats?
                        (let ((key '---push-constant-1byte))
                          (let ((n (table-ref instr-table key 0)))
                            (table-set! instr-table key (+ n 1)))))
                    (asm-8 (+ #x00 n)))
                  (begin
                    (if stats?
                        (let ((key '---push-constant-2bytes))
                          (let ((n (table-ref instr-table key 0)))
                            (table-set! instr-table key (+ n 1)))))
                    (asm-8 (+ #xa0 (quotient n 256)))
		    (asm-8 (modulo n 256)))))

            (define (push-stack n)
              (if (> n 31)
                  (compiler-error "stack is too deep")
                  (asm-8 (+ #x20 n))))

            (define (push-global n)
	      (if (<= n 15)
                  (begin
                    (if stats?
                        (let ((key '---push-global-1byte))
                          (let ((n (table-ref instr-table key 0)))
                            (table-set! instr-table key (+ n 1)))))
                    (asm-8 (+ #x40 n)))
		  (begin
                    (if stats?
                        (let ((key '---push-global-2bytes))
                          (let ((n (table-ref instr-table key 0)))
                            (table-set! instr-table key (+ n 1)))))
                    (asm-8 #x8e)
                    (asm-8 n))))

            (define (set-global n)
              (if (<= n 15)
	          (begin
                    (if stats?
                        (let ((key '---set-global-1byte))
                          (let ((n (table-ref instr-table key 0)))
                            (table-set! instr-table key (+ n 1)))))
                    (asm-8 (+ #x50 n)))
		  (begin
                    (if stats?
                        (let ((key '---set-global-2bytes))
                          (let ((n (table-ref instr-table key 0)))
                            (table-set! instr-table key (+ n 1)))))
                    (asm-8 #x8f)
                    (asm-8 n))))

            (define (call n)
              (if (> n 15)
	          (compiler-error "call has too many arguments")
	          (asm-8 (+ #x60 n))))

            (define (jump n)
              (if (> n 15)
                  (compiler-error "call has too many arguments")
                  (asm-8 (+ #x70 n))))

            (define optimize! #f);;;;;;;;;;;;;;;;;;;;;
;            (define optimize! 0);;;;;;;;;;;;;;;;;;;;;

            (define (call-toplevel label)
              (label-instr label
                           #f ;; saves 36 (22)
                           #xb5 ;; saves 60, 78 (71)
                           #f ;; saves 150, 168 (161)
                           #xb0
                           'call-toplevel))

            (define (jump-toplevel label)
              (label-instr label
                           #x80 ;; saves 62 (62)
                           #xb6 ;; saves 45, 76 (76)
                           #f ;; saves 67, 98 (98)
                           #xb1
                           'jump-toplevel))

            (define (goto label)
              (label-instr label
                           #f ;; saves 0 (2)
                           #xb7 ;; saves 21, 21 (22)
                           #f ;; saves 30, 30 (31)
                           #xb2
                           'goto))

            (define (goto-if-false label)
              (label-instr label
                           #x90 ;; saves 54 (44)
                           #xb8 ;; saves 83, 110 (105)
                           #f ;; saves 109, 136 (131)
                           #xb3
                           'goto-if-false))

            (define (closure label)
              (label-instr label
                           #f ;; saves 50 (48)
                           #f ;; #xb9 ;; #f;; does not work!!! #xb9 ;; saves 27, 52 (51) TODO
                           #f ;; saves 34, 59 (58)
                           #xb4
                           'closure))

            ;; (define (prim n)
            ;;   (asm-8 (+ #xc0 n)))

            ;; (define (prim.number?)         (prim 0))
            ;; (define (prim.+)               (prim 1))
            ;; (define (prim.-)               (prim 2))
            ;; (define (prim.mul-non-neg)     (prim 3))
            ;; (define (prim.quotient)        (prim 4))
            ;; (define (prim.remainder)       (prim 5))
            ;; (define (prim.=)               (prim 7))
            ;; (define (prim.<)               (prim 8))
            ;; (define (prim.>)               (prim 10))
            ;; (define (prim.pair?)           (prim 12))
            ;; (define (prim.cons)            (prim 13))
            ;; (define (prim.car)             (prim 14))
            ;; (define (prim.cdr)             (prim 15))
            ;; (define (prim.set-car!)        (prim 16))
            ;; (define (prim.set-cdr!)        (prim 17))
            ;; (define (prim.null?)           (prim 18))
            ;; (define (prim.eq?)             (prim 19))
            ;; (define (prim.not)             (prim 20))
            ;; (define (prim.get-cont)        (prim 21))
            ;; (define (prim.graft-to-cont)   (prim 22))
            ;; (define (prim.return-to-cont)  (prim 23))
            ;; (define (prim.halt)            (prim 24))
            ;; (define (prim.symbol?)         (prim 25))
            ;; (define (prim.string?)         (prim 26))
            ;; (define (prim.string->list)    (prim 27))
            ;; (define (prim.list->string)    (prim 28))
	    ;; (define (prim.make-u8vector)   (prim 29))
	    ;; (define (prim.u8vector-ref)    (prim 30))
	    ;; (define (prim.u8vector-set!)   (prim 31))
            ;; (define (prim.print)           (prim 32))
            ;; (define (prim.clock)           (prim 33))
            ;; (define (prim.motor)           (prim 34))
            ;; (define (prim.led)             (prim 35))
	    ;; (define (prim.led2-color)      (prim 36))
	    ;; (define (prim.getchar-wait)    (prim 37))
	    ;; (define (prim.putchar)         (prim 38))
	    ;; (define (prim.beep)            (prim 39))
	    ;; (define (prim.adc)             (prim 40))
	    ;; (define (prim.u8vector?)       (prim 41))
	    ;; (define (prim.sernum)          (prim 42))
	    ;; (define (prim.u8vector-length) (prim 43))
            ;; (define (prim.shift)           (prim 45))
            ;; (define (prim.pop)             (prim 46))
            ;; (define (prim.return)          (prim 47))
	    ;; (define (prim.boolean?)        (prim 48))
	    ;; (define (prim.network-init)    (prim 49))
	    ;; (define (prim.network-cleanup) (prim 50))
	    ;; (define (prim.receive-packet-to-u8vector) (prim 51))
	    ;; (define (prim.send-packet-from-u8vector)  (prim 52))
	    ;; (define (prim.ior)             (prim 53))
	    ;; (define (prim.xor)             (prim 54))

            (define prim->number (if (equal? arch 'arduino)
                                     arduino-prim->number
                                     default-prim->number))
            
            (define big-endian? #f)

            (define stats? #t)
            (define instr-table (make-table))

            (asm-begin! code-start #f)

            (asm-8 #xfb)
            (asm-8 #xd7)
            (asm-8 (length constants))
            (asm-8 (length globals))

            '(pp (list constants: constants globals: globals))

            (for-each
             (lambda (x)
               (let* ((descr (cdr x))
                      (label (vector-ref descr 1))
                      (obj (car x)))
                 (asm-label label)
		 ;; see the vm source for a description of encodings
		 ;; TODO have comments here to explain encoding, at least magic number that give the type
                 (cond ((and (integer? obj) (exact? obj))
			(let ((hi (encode-constant (vector-ref descr 3)
						   constants)))
			  ; (pp (list ENCODE: (vector-ref descr 3) to: hi lo: obj))
			  (asm-8 (+ 0 (arithmetic-shift hi -8))) ;; TODO -5 has low 16 at 00fb, should be fffb, 8 bits ar lost
			  (asm-8 (bitwise-and hi  #xff)) ; pointer to hi
			  (asm-8 (arithmetic-shift obj -8)) ; bits 8-15
			  (asm-8 (bitwise-and obj #xff)))) ; bits 0-7
                       ((pair? obj)
			(let ((obj-car (encode-constant (car obj) constants))
			      (obj-cdr (encode-constant (cdr obj) constants)))
			  (asm-8 (+ #x80 (arithmetic-shift obj-car -8)))
			  (asm-8 (bitwise-and obj-car #xff))
			  (asm-8 (+ 0 (arithmetic-shift obj-cdr -8)))
			  (asm-8 (bitwise-and obj-cdr #xff))))
                       ((symbol? obj)
                        (asm-8 #x80)
                        (asm-8 0)
                        (asm-8 #x20)
                        (asm-8 0))
                       ((string? obj)
			(let ((obj-enc (encode-constant (vector-ref descr 3)
							constants)))
			  (asm-8 (+ #x80 (arithmetic-shift obj-enc -8)))
			  (asm-8 (bitwise-and obj-enc #xff))
			  (asm-8 #x40)
			  (asm-8 0)))
                       ((vector? obj) ; ordinary vectors are stored as lists
			(let* ((elems (vector-ref descr 3))
			       (obj-car (encode-constant (car elems)
							 constants))
			       (obj-cdr (encode-constant (cdr elems)
							 constants)))
			  (asm-8 (+ #x80 (arithmetic-shift obj-car -8)))
			  (asm-8 (bitwise-and obj-car #xff))
			  (asm-8 (+ 0 (arithmetic-shift obj-cdr -8)))
			  (asm-8 (bitwise-and obj-cdr #xff))))
		       ((u8vector? obj)
			(let ((obj-enc (encode-constant (vector-ref descr 3)
							constants))
			      (l (length (vector-ref descr 3))))
			  ;; length is stored raw, not encoded as an object
			  ;; however, the bytes of content are encoded as
			  ;; fixnums
			  (asm-8 (+ #x80 (arithmetic-shift l -8)))
			  (asm-8 (bitwise-and l #xff))
			  (asm-8 (+ #x60 (arithmetic-shift obj-enc -8)))
			  (asm-8 (bitwise-and obj-enc #xff))))
                       (else
                        (compiler-error "unknown object type" obj)))))
             constants)

            ;;(pp code);;;;;;;;;;;;

            (let loop2 ((lst code))
              (if (pair? lst)
                  (let ((instr (car lst)))

                    (if stats?
                        (if (not (number? instr))
                            (let ((key (car instr)))
                              (let ((n (table-ref instr-table key 0)))
                                (table-set! instr-table key (+ n 1))))))

                    (cond ((number? instr)
                           (let ((label (cdr (assq instr labels))))
                             (asm-label label)))

                          ((eq? (car instr) 'entry)
                           (let ((np (cadr instr))
                                 (rest? (caddr instr)))
                             (asm-8 (if rest? (- np) np))))

                          ((eq? (car instr) 'push-constant)
                           (let ((n (encode-constant (cadr instr) constants)))
                             (push-constant n)))

                          ((eq? (car instr) 'push-stack)
                           (push-stack (cadr instr)))

                          ((eq? (car instr) 'push-global)
                           (push-global (vector-ref
					 (cdr (assq (cadr instr) globals))
					 0)))

                          ((eq? (car instr) 'set-global)
			   (set-global (vector-ref
					(cdr (assq (cadr instr) globals))
					0)))

                          ((eq? (car instr) 'call)
                           (call (cadr instr)))

                          ((eq? (car instr) 'jump)
                           (jump (cadr instr)))

                          ((eq? (car instr) 'call-toplevel)
                           (let ((label (cdr (assq (cadr instr) labels))))
                             (call-toplevel label)))

                          ((eq? (car instr) 'jump-toplevel)
                           (let ((label (cdr (assq (cadr instr) labels))))
                             (jump-toplevel label)))

                          ((eq? (car instr) 'goto)
                           (let ((label (cdr (assq (cadr instr) labels))))
                             (goto label)))

                          ((eq? (car instr) 'goto-if-false)
                           (let ((label (cdr (assq (cadr instr) labels))))
                             (goto-if-false label)))

                          ((eq? (car instr) 'closure)
                           (let ((label (cdr (assq (cadr instr) labels))))
                             (closure label)))

                          ((eq? (car instr) 'prim)
                           (prim->number (cadr instr)))

                          ((eq? (car instr) 'return)
                           (prim->number 'return))

                          ((eq? (car instr) 'pop)
                           (prim->number 'pop))

                          ((eq? (car instr) 'shift)
                           (prim->number 'shift))

                          (else
                           (compiler-error "unknown instruction" instr)))

                    (loop2 (cdr lst)))))

            (asm-assemble)

            (if stats?
                (pretty-print
                 (sort-list (table->list instr-table)
                            (lambda (x y) (> (cdr x) (cdr y))))))

;;;;;;;;;            (asm-display-listing ##stdout-port);;;;;;;;;;;;;
            (asm-write-hex-file hex-filename)

            (asm-end!))))))
