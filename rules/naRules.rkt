#lang racket
(require redex/reduction-semantics)
(require "../core/syntax.rkt")
(require "../core/coreLang.rkt")
(require "../core/coreUtils.rkt")
(require "../core/graphUtils.rkt")
(provide define-naRules define-naReadRules define-naWriteStuckRules)

(define-syntax-rule (define-naReadRules lang)
  (begin

  (reduction-relation
   lang #:domain ξ

   (-->  ((in-hole E (read na ι σ-dd)) auxξ)
        (normalize
         ((in-hole E (ret μ-value)) auxξ_new))
        "read-na"
        (where η       (getη     auxξ))
        (where σ-tree  (getReadσ-tree auxξ))
        (where σ_read  (getByPath (pathE E) σ-tree))
        (where τ       (getLastTimestamp ι η))
        (where μ-value (getValueByCorrectTimestamp ι τ η))

        (where path (pathE E))
        (where auxξ_new (addReadNode τ (read na ι μ-value) path auxξ))
        
        (side-condition (term (seeLast ι η (frontMerge σ-dd σ_read))))
        (side-condition (term (nonNegativeτ τ)))))))

(define-syntax-rule (define-naWriteStuckRules lang defaultState)
  (begin

  (reduction-relation
   lang #:domain ξ

   (--> ((in-hole E (write WM ι μ-value)) auxξ)
        (stuck defaultState)
        "write-na-stuck"
        (where path (pathE E))
        (where σ_read (getReadσ path auxξ))
        (where σ_na   (getσNA auxξ))

        (where τ_cur  (fromMaybe -1 (lookup ι σ_read)))
        (where τ_na   (fromMaybe -1 (lookup ι σ_na)))
        (side-condition (< (term τ_cur) (term τ_na))))
        #|
        (where η        (getη     auxξ))
        (where σ-tree        (getReadσ-tree auxξ))
        (where σ_read   (getByPath (pathE E) σ-tree))
        (side-condition (term (dontSeeLast ι η σ_read)))
        |#
   
   (--> ((in-hole E (read RM ι σ-dd)) auxξ)
        (stuck defaultState)
        "read-na-stuck"
        (where path   (pathE E))
        (where σ_read (getReadσ path auxξ))
        (where σ_na   (getσNA auxξ))

        (where τ_cur  (fromMaybe -1 (lookup ι (frontMerge σ-dd σ_read))))
        (where τ_na   (fromMaybe -1 (lookup ι σ_na)))
        (side-condition (or (< (term τ_cur) (term τ_na))
                            (term (negativeτ τ_cur)))))
        #|
        (where η      (getη     auxξ))
        (where σ-tree      (getReadσ-tree auxξ))
        (where σ_read (getByPath (pathE E) σ-tree))
        (side-condition
         (or (term (dontSeeLast ι η σ_read))
             (term (negativeτ (getLastTimestamp ι η)))))
        |#

#|
Reading from NA write can't give any information, because a thread executing
a corresponding read action should be acknowledged (Wna happens-before R) about the NA
record (so as about a synchronization front stored in it).
|#
   (-->  ((in-hole E (write na ι μ-value)) auxξ    )
        (normalize
         ((in-hole E (ret μ-value))        auxξ_new))
        "write-na"
        (where η      (getη     auxξ))
        (where σ-tree      (getReadσ-tree auxξ))
        (where path   (pathE E))
        
        (where τ       (getNextTimestamp ι η))
        (where σ-tree_new   (updateByFront path ((ι τ)) σ-tree))

        (where auxξ_upd_front (updateState (Read σ-tree) (Read σ-tree_new) auxξ))
        (where η_new          (updateCell  ι μ-value ((ι τ)) η))
        (where auxξ_upd_η     (updateState η η_new auxξ_upd_front))

        (where σ_na           (getσNA auxξ))
        (where σ_na_new       (updateFront ι τ σ_na))
        (where auxξ_upd_na    (updateState (NA σ_na) (NA σ_na_new) auxξ_upd_η))

        (where auxξ_new       (addWriteNode (write na ι μ-value τ) path auxξ_upd_na))

        (where σ_read   (getByPath path σ-tree))
        (side-condition (term (seeLast ι η σ_read)))
        (side-condition (term (ι-not-in-α-tree ι path auxξ)))))))

(define-syntax-rule (define-naRules lang defaultState)
  (begin

  (union-reduction-relations
   (define-naReadRules lang)
   (define-naWriteStuckRules lang defaultState))))
