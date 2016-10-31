#lang racket
(require redex/reduction-semantics)
(require "../core/syntax.rkt")
(require "../core/coreLang.rkt")
(require "../core/coreUtils.rkt")
(provide define-rlxRules define-rlxReadRules define-rlxWriteRules define-rlxCasRules)

(define-syntax-rule (define-rlxReadRules lang)
  (begin

  (reduction-relation
   lang #:domain ξ
   
   (-->  ((in-hole E (read  rlx ι)) auxξ)
        (normalize
         ((in-hole E (ret μ-value)) auxξ_new))
        "read-rlx"
        (where η         (getη     auxξ))
        (where σ-tree    (getReadσ-tree auxξ))
        (where path      (pathE E))
        (where  (in-hole El (τ μ-value σ)) (getCellHistory ι η))

        (where σ-tree_new      (updateByFront path ((ι τ)) σ-tree))
        (where auxξ_σ-tree_new (updateState (Read σ-tree) (Read σ-tree_new) auxξ))
        (where auxξ_new        (updateAcqFront path σ auxξ_σ-tree_new))

        (where σ_read   (getByPath path σ-tree))
        (side-condition (term (correctτ τ ι σ_read)))))))

(define-metafunction coreLang
  getσ_relFront : ι path auxξ -> σ
  [(getσ_relFront ι path (any_0 ... (RelFront χ-tree) any_1 ...))
   (getσReleaseToWrite ι (getByPath path χ-tree))]
  [(getσ_relFront ι path auxξ) ()])

(define-syntax-rule (define-rlxWriteRulesWOcas lang)
  (begin

  (reduction-relation
   lang #:domain ξ
   
   (--> ((in-hole E (fence acq)) auxξ)
        ((in-hole E (ret 0    )) auxξ_new)
        "fence-acq"

        (where path     (pathE E))
        (side-condition (term (is-α-empty path auxξ)))
        (where auxξ_new (synchronizeCurAcqFronts path auxξ)))
   
   (--> ((in-hole E (fence rel)) auxξ)
        ((in-hole E (ret 0    )) auxξ_new)
        "fence-rel"

        (where path     (pathE E))
        (side-condition (term (is-α-empty path auxξ)))
        (where auxξ_new (synchronizeCurReleaseFronts path auxξ)))

   (-->  ((in-hole E (write rlx ι μ-value)) auxξ)
        (normalize
         ((in-hole E (ret μ-value))         auxξ_new))
        "write-rlx"
        (where η       (getη auxξ))
        (where σ-tree_read  (getReadσ-tree auxξ))
        (where path    (pathE E))

        (where τ                  (getNextTimestamp ι η))
        (where σ_delta            ((ι τ)))
        (where σ-tree_read_new    (updateByFront path σ_delta σ-tree_read))
        (where auxξ_upd_read      (updateState (Read σ-tree_read) (Read σ-tree_read_new) auxξ))
        (where auxξ_upd_acq       (updateAcqFront path σ_delta auxξ_upd_read))

        (where σ_ToWrite  (updateFront ι τ (getσ_relFront ι path auxξ)))
        (where η_new      (updateCell  ι μ-value σ_ToWrite η))
        (where auxξ_upd_η (updateState η η_new auxξ_upd_acq))

        (where σ_write    (getWriteσ path auxξ))
        (where auxξ_upd_γ (dupRelWriteRestrictions ι τ σ_write auxξ_upd_η))
        (where auxξ_new   auxξ_upd_γ)

        (side-condition (term (are∀PostReadsRlx  path auxξ)))
        (side-condition (term (ι-not-in-α-tree ι path auxξ))))
)))

(define-syntax-rule (define-rlxCasRules lang)
  (begin

  (reduction-relation
   lang #:domain ξ

   (-->  ((in-hole E (cas SM rlx ι μ-value_expected μ-value_new)) auxξ)
        (normalize
         ((in-hole E (ret μ-value                              )) auxξ_new))
        "cas-fail-rlx"
        (where η                          (getη     auxξ))
        (where σ-tree                     (getReadσ-tree auxξ))
        (where path                       (pathE E))
        (where (in-hole El (τ μ-value σ)) (getCellHistory ι η))

        (where auxξ_upd_acq  (updateAcqFront path σ auxξ))
        
        (where σ-tree_new (updateByFront path ((ι τ)) σ-tree))
        (where auxξ_new   (updateState (Read σ-tree) (Read σ-tree_new) auxξ_upd_acq))

        (where σ_read   (getReadσ path auxξ))
        (side-condition (equal? (term τ) (term (getLastTimestamp ι η))))
        ;(side-condition (term (correctτ τ ι σ_read))) ; <- Previous condition implies it.
        (side-condition (not (equal? (term μ-value)
                                     (term μ-value_expected))))
        (side-condition (term (is-α-empty path auxξ)))
        ;; (side-condition (not (term (isRestrictedByγ_auxξ ι τ rlx auxξ))))
        (side-condition (not (term (isRestrictedByγ_auxξ ι τ acq auxξ))))
        (side-condition (not (term (hasιInObservedWrites path ι auxξ)))))
   
   (-->  ((in-hole E (cas rlx FM ι μ-value_expected μ-value_new)) auxξ)
        (normalize
         ((in-hole E (ret μ-value_expected                     )) auxξ_new))
        "cas-succ-rlx"
        (where η        (getη auxξ))
        (where σ-tree   (getReadσ-tree auxξ))
        (where path     (pathE E))

        (where τ_last        (getLastTimestamp ι η))
        (where τ             (getNextTimestamp ι η))
        (where σ             (getLastFront ι η))
        
        ; update read front
        (where σ_delta       ((ι τ)))
        (where σ-tree_new    (updateByFront path σ_delta σ-tree))
        (where auxξ_upd_read (updateState (Read σ-tree) (Read σ-tree_new) auxξ))
        
        ; update acq front
        (where auxξ_upd_acq  (updateAcqFront path (frontMerge σ σ_delta) auxξ_upd_read))

        ; create message and update history
        (where σ_ToWrite  (updateFront ι τ (getσ_relFront ι path auxξ)))
        (where η_new      (updateCell ι μ-value_new (acqSuccCASσReadNew ι η σ_ToWrite) η))
        (where auxξ_upd_η (updateState η η_new auxξ_upd_acq))

        ; update operation buffer
        (where σ_write  (getWriteσ path auxξ))
        (where auxξ_new (dupRelWriteRestrictions ι τ σ_write auxξ_upd_η))

        (side-condition
            (term (succCAScondition ι η μ-value_expected rlx FM)))
        (side-condition (term (ι-not-in-α-tree ι path auxξ)))
        (side-condition (not (term (isRestrictedByγ_auxξ ι τ rlx auxξ))))
        (side-condition (not (term (isRestrictedByγ_auxξ ι τ_last acq auxξ))))
        (side-condition (not (term (hasιInObservedWrites path ι auxξ)))))
)))

(define-syntax-rule (define-rlxWriteRules lang)
  (begin
  (union-reduction-relations
   (define-rlxCasRules        lang)
   (define-rlxWriteRulesWOcas lang))))

(define-syntax-rule (define-rlxRules lang)
  (begin

  (union-reduction-relations
   (define-rlxReadRules  lang)
   (define-rlxWriteRules lang))))
