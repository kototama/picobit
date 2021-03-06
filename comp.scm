;;;; File: "comp.scm", Time-stamp: <2009-08-21 23:41:38 feeley>

;;;; Copyright (C) 2004-2009 by Marc Feeley and Vincent St-Amour
;;;; All Rights Reserved.

(define gen-instruction
  (lambda (instr nb-pop nb-push ctx)
    (let* ((env
            (context-env ctx))
           (stk
            (stack-extend #f
                          nb-push
                          (stack-discard nb-pop
                                         (env-local env)))))
      (context-add-instr (context-change-env ctx (env-change-local env stk))
                         instr))))

(define gen-entry
  (lambda (nparams rest? ctx)
    (gen-instruction (list 'entry nparams rest?) 0 0 ctx)))

(define gen-push-constant
  (lambda (val ctx)
    (gen-instruction (list 'push-constant val) 0 1 ctx)))

(define gen-push-unspecified
  (lambda (ctx)
    (gen-push-constant #f ctx)))

(define gen-push-local-var
  (lambda (var ctx)
;    (pp (list var: var local: (stack-slots (env-local (context-env ctx))) (env-closed (context-env ctx))))
    (let ((i (find-local-var var (context-env ctx))))
      (if (>= i 0)
          (gen-push-stack i ctx)
          (gen-push-stack
	   (+ (- -1 i)
	      (length (stack-slots (env-local (context-env ctx))))) ctx)))))

(define gen-push-stack
  (lambda (pos ctx)
    (gen-instruction (list 'push-stack pos) 0 1 ctx)))

(define gen-push-global
  (lambda (var ctx)
    (gen-instruction (list 'push-global var) 0 1 ctx)))

(define gen-set-global
  (lambda (var ctx)
    (gen-instruction (list 'set-global var) 1 0 ctx)))

(define gen-call
  (lambda (nargs ctx)
    (gen-instruction (list 'call nargs) (+ nargs 1) 1 ctx)))

(define gen-jump
  (lambda (nargs ctx)
    (gen-instruction (list 'jump nargs) (+ nargs 1) 1 ctx)))

(define gen-call-toplevel
  (lambda (nargs id ctx)
    (gen-instruction (list 'call-toplevel id) nargs 1 ctx)))

(define gen-jump-toplevel
  (lambda (nargs id ctx)
    (gen-instruction (list 'jump-toplevel id) nargs 1 ctx)))

(define gen-goto
  (lambda (label ctx)
    (gen-instruction (list 'goto label) 0 0 ctx)))

(define gen-goto-if-false
  (lambda (label-false label-true ctx)
    (gen-instruction (list 'goto-if-false label-false label-true) 1 0 ctx)))

(define gen-closure
  (lambda (label-entry ctx)
    (gen-instruction (list 'closure label-entry) 1 1 ctx)))

(define gen-prim
  (lambda (id nargs unspec-result? ctx)
    (gen-instruction
     (list 'prim id)
     nargs
     (if unspec-result? 0 1)
     ctx)))

(define gen-shift
  (lambda (n ctx)
    (if (> n 0)
        (gen-instruction (list 'shift) 1 0 (gen-shift (- n 1) ctx))
        ctx)))

(define gen-pop
  (lambda (ctx)
    (gen-instruction (list 'pop) 1 0 ctx)))

(define gen-return
  (lambda (ctx)
    (let ((ss (stack-size (env-local (context-env ctx)))))
      (gen-instruction (list 'return) ss 0 ctx))))

;-----------------------------------------------------------------------------

(define child1
  (lambda (node)
    (car (node-children node))))

(define child2
  (lambda (node)
    (cadr (node-children node))))

(define child3
  (lambda (node)
    (caddr (node-children node))))

(define comp-none
  (lambda (node ctx)

    (cond ((or (cst? node)
               (ref? node)
               (prc? node))
           ctx)

          ((def? node)
           (let ((var (def-var node)))
             (if (toplevel-prc-with-non-rest-correct-calls? var)
                 (comp-prc (child1 node) #f ctx)
                 (if (var-needed? var)
                     (let ((ctx2 (comp-push (child1 node) ctx)))
                       (gen-set-global (var-id var) ctx2))
                     (comp-none (child1 node) ctx)))))

          ((set? node)
           (let ((var (set-var node)))
             (if (var-needed? var)
                 (let ((ctx2 (comp-push (child1 node) ctx)))
                   (gen-set-global (var-id var) ctx2))
                 (comp-none (child1 node) ctx))))

          ((if? node)
           (let* ((ctx2
                   (context-make-label ctx))
                  (label-then
                   (context-last-label ctx2))
                  (ctx3
                   (context-make-label ctx2))
                  (label-else
                   (context-last-label ctx3))
                  (ctx4
                   (context-make-label ctx3))
                  (label-then-join
                   (context-last-label ctx4))
                  (ctx5
                   (context-make-label ctx4))
                  (label-else-join
                   (context-last-label ctx5))
                  (ctx6
                   (context-make-label ctx5))
                  (label-join
                   (context-last-label ctx6))
                  (ctx7
                   (comp-test (child1 node) label-then label-else ctx6))
                  (ctx8
                   (gen-goto
                    label-else-join
                    (comp-none (child3 node)
                               (context-change-env2
                                (context-add-bb ctx7 label-else)
                                #f))))
                  (ctx9
                   (gen-goto
                    label-then-join
                    (comp-none (child2 node)
                               (context-change-env
                                (context-add-bb ctx8 label-then)
                                (context-env2 ctx7)))))
                  (ctx10
                   (gen-goto
                    label-join
                    (context-add-bb ctx9 label-else-join)))
                  (ctx11
                   (gen-goto
                    label-join
                    (context-add-bb ctx10 label-then-join)))
                  (ctx12
                   (context-add-bb ctx11 label-join)))
             ctx12))

          ((call? node)
           (comp-call node 'none ctx))

          ((seq? node)
           (let ((children (node-children node)))
             (if (null? children)
                 ctx
                 (let loop ((lst children)
                            (ctx ctx))
                   (if (null? (cdr lst))
                       (comp-none (car lst) ctx)
                       (loop (cdr lst)
                             (comp-none (car lst) ctx)))))))

          (else
           (compiler-error "unknown expression type" node)))))

(define comp-tail
  (lambda (node ctx)

    (cond ((or (cst? node)
               (ref? node)
               (def? node)
               (set? node)
               (prc? node)
;               (call? node)
               )
           (gen-return (comp-push node ctx)))

          ((if? node)
           (let* ((ctx2
                   (context-make-label ctx))
                  (label-then
                   (context-last-label ctx2))
                  (ctx3
                   (context-make-label ctx2))
                  (label-else
                   (context-last-label ctx3))
                  (ctx4
                   (comp-test (child1 node) label-then label-else ctx3))
                  (ctx5
                   (comp-tail (child3 node)
                              (context-change-env2
                               (context-add-bb ctx4 label-else)
                               #f)))
                  (ctx6
                   (comp-tail (child2 node)
                              (context-change-env
                               (context-add-bb ctx5 label-then)
                               (context-env2 ctx4)))))
             ctx6))

          ((call? node)
           (comp-call node 'tail ctx))

          ((seq? node)
           (let ((children (node-children node)))
             (if (null? children)
                 (gen-return (gen-push-unspecified ctx))
                 (let loop ((lst children)
                            (ctx ctx))
                   (if (null? (cdr lst))
                       (comp-tail (car lst) ctx)
                       (loop (cdr lst)
                             (comp-none (car lst) ctx)))))))

          (else
           (compiler-error "unknown expression type" node)))))

(define comp-push
  (lambda (node ctx)

    '(
    (display "--------------\n")
    (pp (node->expr node))
    (pp env)
    (pp stk)
     )

    (cond ((cst? node)
           (let ((val (cst-val node)))
             (gen-push-constant val ctx)))

          ((ref? node)
           (let ((var (ref-var node)))
             (if (var-global? var)
                 (if (null? (var-defs var))
                     (compiler-error "undefined variable:" (var-id var))
		     (let ((val (child1 (car (var-defs var)))))
		       (if (and (not (mutable-var? var))
				(cst? val)) ;; immutable global, counted as cst
			   (gen-push-constant (cst-val val) ctx)
			   (gen-push-global (var-id var) ctx))))
                 (gen-push-local-var (var-id var) ctx))))

          ((or (def? node)
               (set? node))
           (gen-push-unspecified (comp-none node ctx)))

          ((if? node)
           (let* ((ctx2
                   (context-make-label ctx))
                  (label-then
                   (context-last-label ctx2))
                  (ctx3
                   (context-make-label ctx2))
                  (label-else
                   (context-last-label ctx3))
                  (ctx4
                   (context-make-label ctx3))
                  (label-then-join
                   (context-last-label ctx4))
                  (ctx5
                   (context-make-label ctx4))
                  (label-else-join
                   (context-last-label ctx5))
                  (ctx6
                   (context-make-label ctx5))
                  (label-join
                   (context-last-label ctx6))
                  (ctx7
                   (comp-test (child1 node) label-then label-else ctx6))
                  (ctx8
                   (gen-goto
                    label-else-join
                    (comp-push (child3 node)
                               (context-change-env2
                                (context-add-bb ctx7 label-else)
                                #f))))
                  (ctx9
                   (gen-goto
                    label-then-join
                    (comp-push (child2 node)
                               (context-change-env
                                (context-add-bb ctx8 label-then)
                                (context-env2 ctx7)))))
                  (ctx10
                   (gen-goto
                    label-join
                    (context-add-bb ctx9 label-else-join)))
                  (ctx11
                   (gen-goto
                    label-join
                    (context-add-bb ctx10 label-then-join)))
                  (ctx12
                   (context-add-bb ctx11 label-join)))
             ctx12))

          ((prc? node)
           (comp-prc node #t ctx))

          ((call? node)
           (comp-call node 'push ctx))

          ((seq? node)
           (let ((children (node-children node)))
             (if (null? children)
                 (gen-push-unspecified ctx)
                 (let loop ((lst children)
                            (ctx ctx))
                   (if (null? (cdr lst))
                       (comp-push (car lst) ctx)
                       (loop (cdr lst)
                             (comp-none (car lst) ctx)))))))

          (else
           (compiler-error "unknown expression type" node)))))

(define (build-closure label-entry vars ctx)

  (define (build vars ctx)
    (if (null? vars)
        (gen-push-constant '() ctx)
        (gen-prim '#%cons
                  2
                  #f
                  (build (cdr vars)
                         (gen-push-local-var (car vars) ctx)))))

  (if (null? vars)
      (gen-closure label-entry
                   (gen-push-constant '() ctx))
      (gen-closure label-entry
                   (build vars ctx))))

(define comp-prc
  (lambda (node closure? ctx)
    (let* ((ctx2
            (context-make-label ctx))
           (label-entry
            (context-last-label ctx2))
           (ctx3
            (context-make-label ctx2))
           (label-continue
            (context-last-label ctx3))
           (body-env
            (prc->env node))
           (ctx4
            (if closure?
                (build-closure label-entry (env-closed body-env) ctx3)
                ctx3))
           (ctx5
            (gen-goto label-continue ctx4))
           (ctx6
            (gen-entry (length (prc-params node))
                       (prc-rest? node)
                       (context-add-bb (context-change-env ctx5
                                                           body-env)
                                       label-entry)))
           (ctx7
            (comp-tail (child1 node) ctx6)))
      (prc-entry-label-set! node label-entry)
      (context-add-bb (context-change-env ctx7 (context-env ctx5))
                      label-continue))))

(define comp-call
  (lambda (node reason ctx)
    (let* ((op (child1 node))
           (args (cdr (node-children node)))
           (nargs (length args)))
      (let loop ((lst args)
                 (ctx ctx))
        (if (pair? lst)

            (let ((arg (car lst)))
              (loop (cdr lst)
                    (comp-push arg ctx)))

            (cond ((and (ref? op)
                        (var-primitive (ref-var op)))
                   (let* ((var (ref-var op))
                          (id (var-id var))
                          (primitive (var-primitive var))
                          (prim-nargs (primitive-nargs primitive)))

                     (define use-result
                       (lambda (ctx2)
                         (cond ((eq? reason 'tail)
                                (gen-return
                                 (if (primitive-unspecified-result? primitive)
                                     (gen-push-unspecified ctx2)
                                     ctx2)))
                               ((eq? reason 'push)
                                (if (primitive-unspecified-result? primitive)
                                    (gen-push-unspecified ctx2)
                                    ctx2))
                               (else
                                (if (primitive-unspecified-result? primitive)
                                    ctx2
                                    (gen-pop ctx2))))))

                     (use-result
                      (if (primitive-inliner primitive)
                          ((primitive-inliner primitive) ctx)
                          (if
			   (not (= nargs prim-nargs))
			   (compiler-error
			    "primitive called with wrong number of arguments"
			    id)
			   (gen-prim
			    id
			    prim-nargs
			    (primitive-unspecified-result? primitive)
			    ctx))))))
		  
		  
                  ((and (ref? op)
                        (toplevel-prc-with-non-rest-correct-calls?
			 (ref-var op)))
                   =>
                   (lambda (prc)
                     (cond ((eq? reason 'tail)
                            (gen-jump-toplevel nargs prc ctx))
                           ((eq? reason 'push)
                            (gen-call-toplevel nargs prc ctx))
                           (else
                            (gen-pop (gen-call-toplevel nargs prc ctx))))))

                  (else
                   (let ((ctx2 (comp-push op ctx)))
                     (cond ((eq? reason 'tail)
                            (gen-jump nargs ctx2))
                           ((eq? reason 'push)
                            (gen-call nargs ctx2))
                           (else
                            (gen-pop (gen-call nargs ctx2))))))))))))

(define comp-test
  (lambda (node label-true label-false ctx)
    (cond ((cst? node)
           (let ((ctx2
                  (gen-goto
                   (let ((val (cst-val node)))
                     (if val
                         label-true
                         label-false))
                   ctx)))
             (context-change-env2 ctx2 (context-env ctx2))))

          ((or (ref? node)
               (def? node)
               (set? node)
               (if? node)
               (call? node)
               (seq? node))
           (let* ((ctx2
                   (comp-push node ctx))
                  (ctx3
                   (gen-goto-if-false label-false label-true ctx2)))
             (context-change-env2 ctx3 (context-env ctx3))))

          ((prc? node)
           (let ((ctx2
                  (gen-goto label-true ctx)))
             (context-change-env2 ctx2 (context-env ctx2))))

          (else
           (compiler-error "unknown expression type" node)))))

;-----------------------------------------------------------------------------

(define toplevel-prc?
  (lambda (var)
    (and (not (mutable-var? var))
         (let ((d (var-defs var)))
           (and (pair? d)
                (null? (cdr d))
                (let ((val (child1 (car d))))
                  (and (prc? val)
                       val)))))))

(define toplevel-prc-with-non-rest-correct-calls?
  (lambda (var)
    (let ((prc (toplevel-prc? var)))
      (and prc
           (not (prc-rest? prc))
           (every (lambda (r)
                    (let ((parent (node-parent r)))
                      (and (call? parent)
                           (eq? (child1 parent) r)
                           (= (length (prc-params prc))
                              (- (length (node-children parent)) 1)))))
                  (var-refs var))
           prc))))

(define mutable-var?
  (lambda (var)
    (not (null? (var-sets var)))))

(define global-fv
  (lambda (node)
    (list->varset
     (keep var-global?
           (varset->list (fv node))))))

(define non-global-fv
  (lambda (node)
    (list->varset
     (keep (lambda (x) (not (var-global? x)))
           (varset->list (fv node))))))

(define fv
  (lambda (node)
    (cond ((cst? node)
           (varset-empty))
          ((ref? node)
           (let ((var (ref-var node)))
             (varset-singleton var)))
          ((def? node)
           (let ((var (def-var node))
                 (val (child1 node)))
             (varset-union
              (varset-singleton var)
              (fv val))))
          ((set? node)
           (let ((var (set-var node))
                 (val (child1 node)))
             (varset-union
              (varset-singleton var)
              (fv val))))
          ((if? node)
           (let ((a (list-ref (node-children node) 0))
                 (b (list-ref (node-children node) 1))
                 (c (list-ref (node-children node) 2)))
             (varset-union-multi (list (fv a) (fv b) (fv c)))))
          ((prc? node)
           (let ((body (list-ref (node-children node) 0)))
             (varset-difference
              (fv body)
              (build-params-varset (prc-params node)))))
          ((call? node)
           (varset-union-multi (map fv (node-children node))))
          ((seq? node)
           (varset-union-multi (map fv (node-children node))))
          (else
           (compiler-error "unknown expression type" node)))))

(define build-params-varset
  (lambda (params)
    (list->varset params)))

(define mark-needed-global-vars!
  (lambda (global-env node)

    (define readyq
      (env-lookup global-env '#%readyq))

    (define mark-var!
      (lambda (var)
        (if (and (var-global? var)
                 (not (var-needed? var))
		 ;; globals that obey the following conditions are considered
		 ;; to be constants
		 (not (and (not (mutable-var? var))
			   ;; to weed out primitives, which have no definitions
			   (> (length (var-defs var)) 0)
			   (cst? (child1 (car (var-defs var)))))))
            (begin
              (var-needed?-set! var #t)
              (for-each
               (lambda (def)
                 (let ((val (child1 def)))
                   (if (side-effect-less? val)
                       (mark! val))))
               (var-defs var))
              (if (eq? var readyq)
                  (begin
                    (mark-var!
                     (env-lookup global-env '#%start-first-process))
                    (mark-var!
                     (env-lookup global-env '#%exit))))))))

    (define side-effect-less?
      (lambda (node)
        (or (cst? node)
            (ref? node)
            (prc? node))))

    (define mark!
      (lambda (node)
        (cond ((cst? node))
              ((ref? node)
               (let ((var (ref-var node)))
                 (mark-var! var)))
              ((def? node)
               (let ((var (def-var node))
                     (val (child1 node)))
                 (if (not (side-effect-less? val))
                     (mark! val))))
              ((set? node)
               (let ((var (set-var node))
                     (val (child1 node)))
                 (mark! val)))
              ((if? node)
               (let ((a (list-ref (node-children node) 0))
                     (b (list-ref (node-children node) 1))
                     (c (list-ref (node-children node) 2)))
                 (mark! a)
                 (mark! b)
                 (mark! c)))
              ((prc? node)
               (let ((body (list-ref (node-children node) 0)))
                 (mark! body)))
              ((call? node)
               (for-each mark! (node-children node)))
              ((seq? node)
               (for-each mark! (node-children node)))
              (else
               (compiler-error "unknown expression type" node)))))

    (mark! node)
))

;-----------------------------------------------------------------------------

;; Variable sets

(define (varset-empty)              ; return the empty set
  '())

(define (varset-singleton x)        ; create a set containing only 'x'
  (list x))

(define (list->varset lst)          ; convert list to set
  lst)

(define (varset->list set)          ; convert set to list
  set)

(define (varset-size set)           ; return cardinality of set
  (list-length set))

(define (varset-empty? set)         ; is 'x' the empty set?
  (null? set))

(define (varset-member? x set)      ; is 'x' a member of the 'set'?
  (and (not (null? set))
       (or (eq? x (car set))
           (varset-member? x (cdr set)))))

(define (varset-adjoin set x)       ; add the element 'x' to the 'set'
  (if (varset-member? x set) set (cons x set)))

(define (varset-remove set x)       ; remove the element 'x' from 'set'
  (cond ((null? set)
         '())
        ((eq? (car set) x)
         (cdr set))
        (else
         (cons (car set) (varset-remove (cdr set) x)))))

(define (varset-equal? s1 s2)       ; are 's1' and 's2' equal sets?
  (and (varset-subset? s1 s2)
       (varset-subset? s2 s1)))

(define (varset-subset? s1 s2)      ; is 's1' a subset of 's2'?
  (cond ((null? s1)
         #t)
        ((varset-member? (car s1) s2)
         (varset-subset? (cdr s1) s2))
        (else
         #f)))

(define (varset-difference set1 set2) ; return difference of sets
  (cond ((null? set1)
         '())
        ((varset-member? (car set1) set2)
         (varset-difference (cdr set1) set2))
        (else
         (cons (car set1) (varset-difference (cdr set1) set2)))))

(define (varset-union set1 set2)    ; return union of sets
  (define (union s1 s2)
    (cond ((null? s1)
           s2)
          ((varset-member? (car s1) s2)
           (union (cdr s1) s2))
          (else
           (cons (car s1) (union (cdr s1) s2)))))
  (if (varset-smaller? set1 set2)
    (union set1 set2)
    (union set2 set1)))

(define (varset-intersection set1 set2) ; return intersection of sets
  (define (intersection s1 s2)
    (cond ((null? s1)
           '())
          ((varset-member? (car s1) s2)
           (cons (car s1) (intersection (cdr s1) s2)))
          (else
           (intersection (cdr s1) s2))))
  (if (varset-smaller? set1 set2)
    (intersection set1 set2)
    (intersection set2 set1)))

(define (varset-intersects? set1 set2) ; do sets 'set1' and 'set2' intersect?
  (not (varset-empty? (varset-intersection set1 set2))))

(define (varset-smaller? set1 set2)
  (if (null? set1)
    (not (null? set2))
    (if (null? set2)
      #f
      (varset-smaller? (cdr set1) (cdr set2)))))

(define (varset-union-multi sets)
  (if (null? sets)
    (varset-empty)
    (n-ary varset-union (car sets) (cdr sets))))

(define (n-ary function first rest)
  (if (null? rest)
    first
    (n-ary function (function first (car rest)) (cdr rest))))

;------------------------------------------------------------------------------

(define code->vector
  (lambda (code)
    (let ((v (make-vector (+ (code-last-label code) 1))))
      (for-each
       (lambda (bb)
         (vector-set! v (bb-label bb) bb))
       (code-rev-bbs code))
      v)))

(define bbs->ref-counts
  (lambda (bbs)
    (let ((ref-counts (make-vector (vector-length bbs) 0)))

      (define visit
        (lambda (label)
          (let ((ref-count (vector-ref ref-counts label)))
            (vector-set! ref-counts label (+ ref-count 1))
            (if (= ref-count 0)
                (let* ((bb (vector-ref bbs label))
                       (rev-instrs (bb-rev-instrs bb)))
                  (for-each
                   (lambda (instr)
                     (let ((opcode (car instr)))
                       (cond ((eq? opcode 'goto)
                              (visit (cadr instr)))
                             ((eq? opcode 'goto-if-false)
                              (visit (cadr instr))
                              (visit (caddr instr)))
                             ((or (eq? opcode 'closure)
                                  (eq? opcode 'call-toplevel)
                                  (eq? opcode 'jump-toplevel))
                              (visit (cadr instr))))))
                   rev-instrs))))))

      (visit 0)

      ref-counts)))

(define resolve-toplevel-labels!
  (lambda (bbs)
    (let loop ((i 0))
      (if (< i (vector-length bbs))
          (let* ((bb (vector-ref bbs i))
                 (rev-instrs (bb-rev-instrs bb)))
            (bb-rev-instrs-set!
             bb
             (map (lambda (instr)
                    (let ((opcode (car instr)))
                      (cond ((eq? opcode 'call-toplevel)
                             (list opcode
                                   (prc-entry-label (cadr instr))))
                            ((eq? opcode 'jump-toplevel)
                             (list opcode
                                   (prc-entry-label (cadr instr))))
                            (else
                             instr))))
                  rev-instrs))
            (loop (+ i 1)))))))

(define tighten-jump-cascades!
  (lambda (bbs)
    (let ((ref-counts (bbs->ref-counts bbs)))

      (define resolve
        (lambda (label)
          (let* ((bb (vector-ref bbs label))
                 (rev-instrs (bb-rev-instrs bb)))
            (and (or (null? (cdr rev-instrs))
                     (= (vector-ref ref-counts label) 1))
                 rev-instrs))))

      (let loop1 ()
        (let loop2 ((i 0)
                    (changed? #f))
          (if (< i (vector-length bbs))
              (if (> (vector-ref ref-counts i) 0)
                  (let* ((bb (vector-ref bbs i))
                         (rev-instrs (bb-rev-instrs bb))
                         (jump (car rev-instrs))
                         (opcode (car jump)))
                    (cond ((eq? opcode 'goto)
                           (let* ((label (cadr jump))
                                  (jump-replacement (resolve label)))
                             (if jump-replacement
                                 (begin
                                   (vector-set!
                                    bbs
                                    i
                                    (make-bb (bb-label bb)
                                             (append jump-replacement
                                                     (cdr rev-instrs))))
                                   (loop2 (+ i 1)
                                          #t))
                                 (loop2 (+ i 1)
                                        changed?))))
                          ((eq? opcode 'goto-if-false)
                           (let* ((label-then (cadr jump))
                                  (label-else (caddr jump))
                                  (jump-then-replacement (resolve label-then))
                                  (jump-else-replacement (resolve label-else)))
                             (if (and jump-then-replacement
                                      (null? (cdr jump-then-replacement))
                                      jump-else-replacement
                                      (null? (cdr jump-else-replacement))
                                      (or (eq? (caar jump-then-replacement)
					       'goto)
                                          (eq? (caar jump-else-replacement)
					       'goto)))
                                 (begin
                                   (vector-set!
                                    bbs
                                    i
                                    (make-bb
				     (bb-label bb)
				     (cons
				      (list
				       'goto-if-false
				       (if (eq? (caar jump-then-replacement)
						'goto)
					   (cadar jump-then-replacement)
					   label-then)
				       (if (eq? (caar jump-else-replacement)
						'goto)
					   (cadar jump-else-replacement)
					   label-else))
				      (cdr rev-instrs))))
                                   (loop2 (+ i 1)
                                          #t))
                                 (loop2 (+ i 1)
                                        changed?))))
                          (else
                           (loop2 (+ i 1)
                                  changed?))))
                  (loop2 (+ i 1)
                         changed?))
              (if changed?
                  (loop1))))))))

(define remove-useless-bbs!
  (lambda (bbs)
    (let ((ref-counts (bbs->ref-counts bbs)))
      (let loop1 ((label 0) (new-label 0))
        (if (< label (vector-length bbs))
            (if (> (vector-ref ref-counts label) 0)
                (let ((bb (vector-ref bbs label)))
                  (vector-set!
                   bbs
                   label
                   (make-bb new-label (bb-rev-instrs bb)))
                  (loop1 (+ label 1) (+ new-label 1)))
                (loop1 (+ label 1) new-label))
            (renumber-labels bbs ref-counts new-label))))))

(define renumber-labels
  (lambda (bbs ref-counts n)
    (let ((new-bbs (make-vector n)))
      (let loop2 ((label 0))
        (if (< label (vector-length bbs))
            (if (> (vector-ref ref-counts label) 0)
                (let* ((bb (vector-ref bbs label))
                       (new-label (bb-label bb))
                       (rev-instrs (bb-rev-instrs bb)))

                  (define fix
                    (lambda (instr)

                      (define new-label
                        (lambda (label)
                          (bb-label (vector-ref bbs label))))

                      (let ((opcode (car instr)))
                        (cond ((eq? opcode 'closure)
                               (list 'closure
                                     (new-label (cadr instr))))
                              ((eq? opcode 'call-toplevel)
                               (list 'call-toplevel
                                     (new-label (cadr instr))))
                              ((eq? opcode 'jump-toplevel)
                               (list 'jump-toplevel
                                     (new-label (cadr instr))))
                              ((eq? opcode 'goto)
                               (list 'goto
                                     (new-label (cadr instr))))
                              ((eq? opcode 'goto-if-false)
                               (list 'goto-if-false
                                     (new-label (cadr instr))
                                     (new-label (caddr instr))))
                              (else
                               instr)))))

                  (vector-set!
                   new-bbs
                   new-label
                   (make-bb new-label (map fix rev-instrs)))
                  (loop2 (+ label 1)))
                (loop2 (+ label 1)))
            new-bbs)))))

(define reorder!
  (lambda (bbs)
    (let* ((done (make-vector (vector-length bbs) #f)))

      (define unscheduled?
        (lambda (label)
          (not (vector-ref done label))))

      (define label-refs
        (lambda (instrs todo)
          (if (pair? instrs)
              (let* ((instr (car instrs))
                     (opcode (car instr)))
                (cond ((or (eq? opcode 'closure)
                           (eq? opcode 'call-toplevel)
                           (eq? opcode 'jump-toplevel))
                       (label-refs (cdr instrs) (cons (cadr instr) todo)))
                      (else
                       (label-refs (cdr instrs) todo))))
              todo)))

      (define schedule-here
        (lambda (label new-label todo cont)
          (let* ((bb (vector-ref bbs label))
                 (rev-instrs (bb-rev-instrs bb))
                 (jump (car rev-instrs))
                 (opcode (car jump))
                 (new-todo (label-refs rev-instrs todo)))
            (vector-set! bbs label (make-bb new-label rev-instrs))
            (vector-set! done label #t)
            (cond ((eq? opcode 'goto)
                   (let ((label (cadr jump)))
                     (if (unscheduled? label)
                         (schedule-here label
                                        (+ new-label 1)
                                        new-todo
                                        cont)
                         (cont (+ new-label 1)
                               new-todo))))
                  ((eq? opcode 'goto-if-false)
                   (let ((label-then (cadr jump))
                         (label-else (caddr jump)))
                     (cond ((unscheduled? label-else)
                            (schedule-here label-else
                                           (+ new-label 1)
                                           (cons label-then new-todo)
                                           cont))
                           ((unscheduled? label-then)
                            (schedule-here label-then
                                           (+ new-label 1)
                                           new-todo
                                           cont))
                           (else
                            (cont (+ new-label 1)
                                  new-todo)))))
                  (else
                   (cont (+ new-label 1)
                         new-todo))))))

      (define schedule-somewhere
        (lambda (label new-label todo cont)
          (schedule-here label new-label todo cont)))

      (define schedule-todo
        (lambda (new-label todo)
          (if (pair? todo)
              (let ((label (car todo)))
                (if (unscheduled? label)
                    (schedule-somewhere label
                                        new-label
                                        (cdr todo)
                                        schedule-todo)
                    (schedule-todo new-label
                                   (cdr todo)))))))


      (schedule-here 0 0 '() schedule-todo)

      (renumber-labels bbs
                       (make-vector (vector-length bbs) 1)
                       (vector-length bbs)))))

(define linearize-old
  (lambda (bbs)
    (let loop ((label (- (vector-length bbs) 1))
               (lst '()))
      (if (>= label 0)
          (let* ((bb (vector-ref bbs label))
                 (rev-instrs (bb-rev-instrs bb))
                 (jump (car rev-instrs))
                 (opcode (car jump)))
            (loop (- label 1)
                  (append
                   (list label)
                   (reverse
                    (cond ((eq? opcode 'goto)
                           (if (= (cadr jump) (+ label 1))
                               (cdr rev-instrs)
                               rev-instrs))
                          ((eq? opcode 'goto-if-false)
                           (cond ((= (caddr jump) (+ label 1))
                                  (cons (list 'goto-if-false (cadr jump))
                                        (cdr rev-instrs)))
                                 ((= (cadr jump) (+ label 1))
                                  (cons (list 'goto-if-not-false (caddr jump))
                                        (cdr rev-instrs)))
                                 (else
                                  (cons (list 'goto (caddr jump))
                                        (cons (list 'goto-if-false (cadr jump))
                                              (cdr rev-instrs))))))
                          (else
                           rev-instrs)))
                   lst)))
          lst))))

(define linearize
  (lambda (bbs)

    (define rev-code '())

    (define pos 0)

    (define (emit x)
      (set! pos (+ pos 1))
      (set! rev-code (cons x rev-code)))

    (define todo (cons '() '()))

    (define dumped (make-vector (vector-length bbs) #f))

    (define (get fallthrough-to-next?)
      (if (pair? (cdr todo))
          (if fallthrough-to-next?
              (let* ((label-pos (cadr todo))
                     (label (car label-pos))
                     (rest (cddr todo)))
                (if (not (pair? rest))
                    (set-car! todo todo))
                (set-cdr! todo rest)
                label)
              (let loop ((x (cdr todo)) (best-label-pos #f))
                #;
                (if (pair? x)
                    (if (not (vector-ref dumped (car (car x))))
                        (pp (car x))))
                (if (pair? x)
                    (loop (cdr x)
                          (if (vector-ref dumped (car (car x)))
                              best-label-pos
                              (if (or (not best-label-pos)
                                      (> (cdr (car x)) (cdr best-label-pos)))
                                  (car x)
                                  best-label-pos)))
                    (if (pair? best-label-pos)
                        (car best-label-pos)
                        #f))))
          #f))

    (define (next)
      (let loop ((x (cdr todo)))
        (if (pair? x)
            (let* ((label-pos (car x))
                   (label (car label-pos)))
              (if (not (vector-ref dumped label))
                  label
                  (loop (cdr x))))
            #f)))

    (define (schedule! label tail?)
      (let ((label-pos (cons label pos)))
        (if tail?
            (let ((cell (cons label-pos '())))
              (set-cdr! (car todo) cell)
              (set-car! todo cell))
            (let ((cell (cons label-pos (cdr todo))))
              (set-cdr! todo cell)
              (if (eq? (car todo) todo)
                  (set-car! todo cell))))))

    (define (dump)
      (let loop ((fallthrough-to-next? #t))
        (let ((label (get fallthrough-to-next?)))
          (if label
              (if (not (vector-ref dumped label))
                  (begin
                    (vector-set! dumped label #t)
                    (loop (dump-bb label)))
                  (loop fallthrough-to-next?))))))

    (define (dump-bb label)
      (let* ((bb (vector-ref bbs label))
             (rev-instrs (bb-rev-instrs bb))
             (jump (car rev-instrs))
             (opcode (car jump)))
        (emit label)
        (for-each
         (lambda (instr)
           (case (car instr)
             ((closure call-toplevel)
              (schedule! (cadr instr) #t)))
           (emit instr))
         (reverse (cdr rev-instrs)))
        (cond ((eq? opcode 'goto)
               (schedule! (cadr jump) #f)
               (if (not (equal? (cadr jump) (next)))
                   (begin
                     (emit jump)
                     #f)
                   #t))
              ((eq? opcode 'goto-if-false)
               (schedule! (cadr jump) #f)
               (schedule! (caddr jump) #f)
               (cond ((equal? (caddr jump) (next))
                      (emit (list 'goto-if-false (cadr jump)))
                      #t)
                     ((equal? (cadr jump) (next))
                      (emit (list 'prim '#%not))
                      (emit (list 'goto-if-false (caddr jump)))
                      #t)
                     (else
                      (emit (list 'goto-if-false (cadr jump)))
                      (emit (list 'goto (caddr jump)))
                      #f)))
              (else
               (case (car jump)
                 ((jump-toplevel)
                  (schedule! (cadr jump) #f)
                  ;; it is not correct to remove jump-toplevel when label is next
                  (if #t ;; (not (equal? (cadr jump) (next)))
                      (begin
                        (emit jump)
                        #f)
                      #t))
                 (else
                  (emit jump)
                  #f))))))

    (set-car! todo todo) ;; make fifo

    (schedule! 0 #f)

    (dump)

    (reverse rev-code)))

(define optimize-code
  (lambda (code)
    (let ((bbs (code->vector code)))
      (resolve-toplevel-labels! bbs)
      (tighten-jump-cascades! bbs)
      (let ((bbs (remove-useless-bbs! bbs)))
        (reorder! bbs)))))
