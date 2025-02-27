#lang at-exp racket
(require redex/reduction-semantics)
(require "../steps/relAcqNaRlxPost.rkt")
(require "testTerms.rkt")
(require "../core/parser.rkt")
#|
               x_rlx := 0; y_rlx := 0;
x_rlx := 1 || x_rlx := 2 || r1 = x_rlx; || repeat y_acq end;
           ||            || r2 = x_rlx; || r4 = x_rlx
           ||            || y_rel := 1  ||
                       r5 = x_rlx 
                   ret [[r1 r2] [r3 r4]] r5
Because of read-read coherence, if r3 == 1 then r4 value has to be not
older than r2.
|#
(define (testLong)
    (test-->> randomStep term_CoRR_spec
              0))

#|
x_{rel,rlx}  = 1 || y_{rel,rlx}  = 1
R1 = y_{acq,rlx} || R2 = x_{acq,rlx}

Can lead to R1 = R2 = 0.
|#
(define (test_SB_00 curTerm)
  (test-->>∃ step curTerm
          '(0 0)))
(test_SB_00 term_WrlxRrlx_WrlxRrlx)
(test_SB_00 term_WrelRacq_WrelRacq)

#|
R1 = x_{rlx, con}     || R2 = y_{rlx, con}
y_{sc, rel, rlx}  = 1 || x_{sc, rel, rlx}  = 1

With postponed reads it should be able to lead to R1 = R2 = 1.
|#
(define (test_LB_11 curTerm)
  (test-->>∃ step curTerm
          '(1 1)))
(test_LB_11 term_RrlxWrlx_RrlxWrlx)
(test_LB_11 term_RrlxWrel_RrlxWrel)
(test_LB_11 term_RrlxWsc_RrlxWsc)

(test_LB_11 term_RconWrlx_RconWrlx)
(test_LB_11 term_RconWrel_RconWrel)
(test_LB_11 term_RconWsc_RconWsc)

;; This test fails. However, the behaviour isn't observable
;; on x86, ARM, Power with existing sound compilation schemes.
(define (failingTest)
  (test_LB_11 term_RacqWrlx_RacqWrlx))

#|
R1 = x_{acq,rlx}  || R2 = y_{acq,rlx} 
y_rel  = 1        || x_rel  = 1

Without rlx/rlx combination it's impossible to get R1 = R2 = 1.
|#
(define (test_LB_n11 curTerm)
  (test-->> step curTerm 
          '(0 0)
          '(1 0)
          '(0 1)))
(test_LB_n11 term_RacqWrel_RrlxWrel)
(test_LB_n11 term_RrlxWrel_RacqWrel)
(test_LB_n11 term_RacqWrel_RacqWrel)

#|
R1  = x_{rlx, con}    || R2 = y_{rlx, con}
R1' = R1 + 1          || R2' = R2 + 1
y_{sc, rel, rlx}  = 1 || x_{sc, rel, rlx}  = 1

With postponed lets and reads it should be able to lead to R1' = R2' = 2.
|#
(define (test_LB_let_22 curTerm)
  (test-->>∃ step curTerm
          '(2 2)))
(test_LB_let_22 term_RrlxWrlx_RrlxWrlx_let)
(test_LB_let_22 term_RrlxWrel_RrlxWrel_let)
(test_LB_let_22 term_RrlxWsc_RrlxWsc_let)

(test_LB_let_22 term_RconWrlx_RconWrlx_let)
(test_LB_let_22 term_RconWrel_RconWrel_let)
(test_LB_let_22 term_RconWsc_RconWsc_let)

#|
     x_rlx = 0; y_rlx = 0
R1  = x_mod0; || R2  = y_mod2;
z1_rlx  = R1; || z2_rlx  = R2;
y_mod1  =  1; || x_mod3  =  1;
  r1 = z1_mod0; r2 = z2_mod0

With postponed writes and reads it should be able to lead to r1 = r2 = 1.
|#

(define (test_LB_use curTerm)
  (test-->>∃ step curTerm
          '(1 1)))

(test_LB_use term_RrlxWrlx_RrlxWrlx_use)
(test_LB_use term_RconWrlx_RconWrlx_use)
(test_LB_use term_RrlxWrel_RrlxWrel_use)

#|
  x_mod0 = 0; y_mod0 = 0
x_mod1 = 1; || y_mod3 = 1; 
y_mod2 = 2; || x_mod4 = 2;  
 r1 = x_mod5; r2 = z2_mod5
      ret (r1 r2)

It should be possible to get r1 = r2 = 1, if there is no thread with
both release accesses. 
|#
(define (test_2+2W curTerm)
  (test-->>∃ step curTerm
          '(1 1)))

(test_2+2W term_2+2W_rlx)
(test_2+2W term_2+2W_rel1_rlx)
(test_2+2W term_2+2W_rel2_rlx)
(test_2+2W term_2+2W_rel3_rlx)
(test_2+2W term_2+2W_rel_acq)

#|
          x_rlx = 0; y_rlx = 0
     y_rlx = 1     || if (x_acq == 2) {
     x_rel = 1     ||    r1 = y_rlx 
x_rlx = 2 || ret 0 || } else {
                   ||    r1 = 1 } 

According to Batty-al:POPL11 it's possible to get r1 = 0, because
there is no release sequence between x_rel = 1 and x_rlx = 2.
|#
(test-->>∃ step term_Wrel_Wrlx_Racq
           0)
 
#|
        c_rlx = 0
        x_rlx = c
a_rlx = 239; || b = x_acq;
x_rel = a    || res = b_rlx
          ret res
|#
(define testTerm11
  @prog{c_rlx := 0;
        x_rlx := c;
        r0 := spw
              {{{ a_rlx := 239;
                  x_rel := a
              ||| r1 := x_acq;
                  r1_rlx }}};
        ret r0_2 })

(test-->> step testTerm11
          0
          239)

#|
   x_rlx = 0; y_rlx = 0;
R1 = x_acq || R2 = y_rlx
y_rlx  = 1 || x_rel  = 1
           || x_rlx  = 2

With postponed reads it shouldn't lead to R1 = {1, 2} \/ R2 = 1.
|#
(test-->> step term_RacqWrlx_RrlxWrelWrlx
          '(0 0)
          '(1 0)
          '(2 0)
          '(0 1))

#|
     data_na  = 0
     dataP_na = 0
     p_rel    = 0
data_na  = 5      || r1 = p_con
dataP_na = &data  ||
p_rel    = &dataP || if (r1 != 0) {
                  ||    r3 = r1_na
                  ||    r2 = r3_na
                  || else
                  ||    r2 = 1

Possible outcomes for r2 are 1 and 5.
|#
(test-->> step term_MP_pointer_consume
          1
          5)

#|
     data_na  = 0
     p_rel    = 0
data_na  = 5     || r1 = p_con
p_rel    = &data || if (r1 != 0) {
                 ||    r2 = r1_na
                 || else
                 ||    r2 = 1

Possible outcomes for r2 are 1 and 5.
|#

#|
WRC_rlx

      x_rlx = 0; y_rlx = 0
x_rlx = 1 || r1 = x_rlx || r2 = y_rlx
          || y_rlx = r1 || r3 = x_rlx

Possible outcome: r2 = 1 /\ r3 = 0.
|#
(test-->> step term_WRC_rlx
          '(0 0)
          '(0 1)
          '(1 1)

          '(1 0))

#|
WRC_rel+acq

      x_rel = 0; y_rel = 0
x_rel = 1 || r1 = x_acq || r2 = y_acq
          || y_rel = r1 || r3 = x_acq

Impossible outcome: r2 = 1 /\ r3 = 0.
|#
(test-->> step term_WRC_rel+acq
          '(0 0)
          '(0 1)
          '(1 1))
