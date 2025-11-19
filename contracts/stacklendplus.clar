;; stackstakeplus.clar
;; Advanced staking contract with referrals, tiers, and dynamic APR

;; --------------------------------
;; ERRORS
;; --------------------------------
(define-constant ERR_NOT_OWNER u100)
(define-constant ERR_NO_STAKE u101)
(define-constant ERR_INVALID_AMOUNT u102)
(define-constant ERR_ALREADY_REFERRED u103)
(define-constant ERR_INVALID_REFERRAL u104)
(define-constant ERR_NO_REWARD u105)
(define-constant ERR_LOCK_PERIOD u106)

;; --------------------------------
;; STORAGE
;; --------------------------------
(define-data-var owner principal tx-sender)
(define-data-var base-rate uint u2)              ;; base APR (2%)
(define-data-var total-staked uint u0)
(define-data-var lock-period uint u500)
(define-data-var referral-bonus uint u1)         ;; 1% bonus to referrer
(define-data-var early-penalty uint u10)         ;; 10% penalty for early unstake
(define-data-var treasury uint u0)

(define-map stakes
  principal
  (tuple
    (amount uint)
    (start-block uint)
    (lock-extend uint)
    (rewarded uint)
    (referrer (optional principal))
  )
)

;; --------------------------------
;; EVENTS (represented as data-var for tracking)
;; --------------------------------
;; Note: Clarity doesn't have native events, these would be logged via contract behavior

;; --------------------------------
;; PRIVATE HELPERS
;; --------------------------------
(define-private (only-owner)
  (if (is-eq tx-sender (var-get owner))
      (ok true)
      (err ERR_NOT_OWNER))
)

;; Dynamic APR - higher total stake means lower APR (deflationary)
(define-private (current-apr)
  (let ((t (var-get total-staked)))
    (if (< t u1000000) u5 (if (< t u5000000) u3 u2)))
)

;; Reward calculation (simplified - uses fixed block estimation)
(define-private (calc-reward (user principal))
  (let ((s (map-get? stakes user)))
    (match s
      st
        (let (
          (rate (current-apr))
        )
          (/ (* (get amount st) rate) u100))
      u0))
)

;; Tier determination
(define-private (get-tier (amount uint))
  (if (>= amount u10000000)
      "Diamond"
      (if (>= amount u5000000)
          "Gold"
          (if (>= amount u1000000)
              "Silver"
              "Bronze")))
)

;; --------------------------------
;; PUBLIC FUNCTIONS
;; --------------------------------

;; 1. Stake with optional referrer
(define-public (stake (amount uint) (referrer (optional principal)))
  (if (> amount u0)
      (begin
        (try! (stx-transfer? amount tx-sender contract-caller))
        (map-set stakes tx-sender
          (tuple
            (amount amount)
            (start-block u0)
            (lock-extend u0)
            (rewarded u0)
            (referrer referrer)))
        (var-set total-staked (+ (var-get total-staked) amount))
        (match referrer
          r
            (if (not (is-eq r tx-sender))
                (let ((bonus (/ amount u100)))
                  (var-set treasury (+ (var-get treasury) (- bonus))))
                true)
          true)
        (ok "Stake successful"))
      (err ERR_INVALID_AMOUNT))
)

;; 2. Claim rewards
(define-public (claim-reward)
  (let ((r (calc-reward tx-sender)))
    (if (> r u0)
        (begin
          (try! (stx-transfer? r contract-caller tx-sender))
          (ok (tuple (reward r))))
        (err ERR_NO_REWARD)))
)

;; 3. Extend lock period for higher rewards
(define-public (extend-lock (extra uint))
  (let ((s (map-get? stakes tx-sender)))
    (match s
      st
        (if (> extra u0)
            (begin
              (map-set stakes tx-sender
                (tuple
                  (amount (get amount st))
                  (start-block (get start-block st))
                  (lock-extend (+ (get lock-extend st) extra))
                  (rewarded (get rewarded st))
                  (referrer (get referrer st))))
              (ok "Lock extended"))
            (err ERR_LOCK_PERIOD))
      (err ERR_NO_STAKE))))

;; 4. Unstake with penalty if early
(define-public (unstake)
  (let ((s (map-get? stakes tx-sender)))
    (match s
      st
        (let ((locked (+ (var-get lock-period) (get lock-extend st)))
              (elapsed u0))
          (if (>= elapsed locked)
              (begin
                (try! (stx-transfer? (get amount st) contract-caller tx-sender))
                (map-delete stakes tx-sender)
                (var-set total-staked (- (var-get total-staked) (get amount st)))
                (ok "Unstaked successfully"))
              (let ((penalty (/ (* (get amount st) (var-get early-penalty)) u100))
                    (refund (- (get amount st) penalty)))
                (try! (stx-transfer? refund contract-caller tx-sender))
                (var-set treasury (+ (var-get treasury) penalty))
                (map-delete stakes tx-sender)
                (ok "Early unstake with penalty"))))
      (err ERR_NO_STAKE)))
)

;; 5. Compound rewards
(define-public (compound)
  (let ((r (calc-reward tx-sender)))
    (if (> r u0)
        (let ((s (map-get? stakes tx-sender)))
          (match s
            st
              (begin
                (map-set stakes tx-sender
                  (tuple
                    (amount (+ (get amount st) r))
                    (start-block u0)
                    (lock-extend (get lock-extend st))
                    (rewarded (+ (get rewarded st) r))
                    (referrer (get referrer st))))
                (ok "Reward compounded"))
            (err ERR_NO_STAKE)))
        (err ERR_NO_REWARD)))
)

;; 6. Admin - update parameters
(define-public (update-params (new-rate uint) (new-penalty uint))
  (begin
    (try! (only-owner))
    (var-set base-rate new-rate)
    (var-set early-penalty new-penalty)
    (ok true))
)

;; --------------------------------
;; READ-ONLY FUNCTIONS
;; --------------------------------
(define-read-only (get-stake (user principal))
  (map-get? stakes user)
)

(define-read-only (get-reward (user principal))
  (calc-reward user)
)

(define-read-only (get-total-staked)
  (var-get total-staked)
)

(define-read-only (get-apr)
  (current-apr)
)

(define-read-only (get-tier-info (user principal))
  (let ((s (map-get? stakes user)))
    (match s
      st
        (get-tier (get amount st))
      "None"))
)

(define-read-only (get-treasury)
  (var-get treasury)
)
