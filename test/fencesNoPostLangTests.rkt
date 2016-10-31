#lang racket
(require redex/reduction-semantics)
(require "../core/syntax.rkt")
(require "../core/coreLang.rkt")
(require "../core/coreUtils.rkt")
(require "../rules/postRules.rkt")
(require "../rules/rlxRules.rkt")
(require "../rules/relAcqRules.rkt")
(require "../rules/naRules.rkt")
(require "../rules/scRules.rkt")
(require "../core/langs.rkt")
(require "../test/testTerms.rkt")
(require "../core/pp.rkt")

(define-term defaultState (() (Read ()) (AcqFront ()) (RelFront ()) (NA ()) (Write ()) (SC ())))
(define coreStep
  (extend-reduction-relation
   (define-coreStep defaultState)
   etaPsi2SCLang #:domain ξ))
(define coreTest (define-coreTest coreStep defaultState))

(define rlxRules    (define-rlxRules    etaPsi2SCLang))
(define relAcqRules (define-relAcqRules etaPsi2SCLang))
(define naRules     (define-naRules     etaPsi2SCLang defaultState))
(define scRules     (define-scRules     etaPsi2SCLang))

(define step (union-reduction-relations
              coreStep rlxRules relAcqRules naRules scRules))

(test-->> step testSB+rel+acq+fences+sc
         '(0 1)
         '(1 0)
         '(1 1))

(test-->> step testSB+rlx+fences+sc
         '(0 1)
         '(1 0)
         '(1 1))

(test-->> step testMP+cas+relAcq+fences+acq
         1) 

(test-->> step testMP+cas+sc+fences+sc
         1) 

(test-->> step testSB+cas+rel+acq+fences+sc
         '(0 1)
         '(1 0)
         '(1 1))

(test-->> step testMP+cas+rlx+fences+acq+rel
         1)

