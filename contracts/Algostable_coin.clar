;; AlgoStable Coin - Algorithmic Stablecoin Protocol
;; Maintains USD peg through dynamic supply adjustments and incentive mechanisms

;; Define the stablecoin token
(define-fungible-token algostable-coin)

;; Constants
(define-constant contract-owner tx-sender)
(define-constant target-price u100000000) ;; $1.00 in 8 decimal places
(define-constant price-threshold u5000000) ;; 5% threshold (0.05 * 100000000)
(define-constant rebase-percentage u10) ;; 10% supply adjustment
(define-constant err-owner-only (err u100))
(define-constant err-insufficient-balance (err u101))
(define-constant err-invalid-amount (err u102))
(define-constant err-price-stable (err u103))

;; State variables
(define-data-var total-supply uint u1000000000000) ;; Initial supply: 10,000 tokens
(define-data-var current-price uint target-price) ;; Current price in USD (8 decimals)
(define-data-var last-rebase-block uint u0)
(define-data-var rebase-cooldown uint u144) ;; ~24 hours in blocks

;; Token metadata
(define-data-var token-name (string-ascii 32) "AlgoStable Coin")
(define-data-var token-symbol (string-ascii 10) "ALGO")

;; Price oracle data
(define-map price-feeds principal uint)
(define-data-var authorized-oracles (list 10 principal) (list))

;; Function 1: Rebase Supply - Core algorithmic mechanism
;; Adjusts token supply based on price deviation from $1 peg
(define-public (rebase-supply (new-price uint))
  (let (
    (current-supply (var-get total-supply))
    (price-deviation (if (> new-price target-price)
                        (- new-price target-price)
                        (- target-price new-price)))
    (blocks-since-rebase (- stacks-block-height (var-get last-rebase-block)))
  )
    ;; Only owner or authorized oracle can trigger rebase
    (asserts! (or (is-eq tx-sender contract-owner) 
                  (is-some (index-of (var-get authorized-oracles) tx-sender))) 
              err-owner-only)
    
    ;; Check cooldown period
    (asserts! (>= blocks-since-rebase (var-get rebase-cooldown)) 
              (err u104))
    
    ;; Only rebase if price deviation exceeds threshold
    (asserts! (> price-deviation price-threshold) err-price-stable)
    
    ;; Update current price
    (var-set current-price new-price)
    
    ;; Calculate supply adjustment
    (let (
      (adjustment-amount (/ (* current-supply rebase-percentage) u100))
    )
      (if (> new-price target-price)
        ;; Price above peg - increase supply (mint tokens)
        (begin
          (try! (ft-mint? algostable-coin adjustment-amount contract-owner))
          (var-set total-supply (+ current-supply adjustment-amount))
          (var-set last-rebase-block stacks-block-height)
          (print {action: "expand", amount: adjustment-amount, new-supply: (+ current-supply adjustment-amount), price: new-price})
          (ok {action: "expand", adjustment: adjustment-amount}))
        ;; Price below peg - decrease supply (burn tokens)
        (begin
          (asserts! (>= (ft-get-balance algostable-coin contract-owner) adjustment-amount) 
                    err-insufficient-balance)
          (try! (ft-burn? algostable-coin adjustment-amount contract-owner))
          (var-set total-supply (- current-supply adjustment-amount))
          (var-set last-rebase-block stacks-block-height)
          (print {action: "contract", amount: adjustment-amount, new-supply: (- current-supply adjustment-amount), price: new-price})
          (ok {action: "contract", adjustment: adjustment-amount}))))))

;; Function 2: Claim Rebase Rewards - Incentive mechanism
;; Distributes rewards to users who help maintain the peg
(define-public (claim-rebase-rewards (user principal))
  (let (
    (user-balance (ft-get-balance algostable-coin user))
    (reward-rate u2) ;; 2% of user balance as reward
    (min-balance-required u100000000) ;; Minimum 1 token balance required
  )
    ;; Check if user has minimum balance
    (asserts! (>= user-balance min-balance-required) 
              (err u105))
    
    ;; Calculate reward based on user's token balance
    (let (
      (reward-amount (/ (* user-balance reward-rate) u100))
    )
      ;; Only distribute rewards if there was a recent rebase
      (asserts! (< (- stacks-block-height (var-get last-rebase-block)) u144) 
                (err u106))
      
      ;; Mint reward tokens to user
      (try! (ft-mint? algostable-coin reward-amount user))
      (var-set total-supply (+ (var-get total-supply) reward-amount))
      
      (print {event: "reward-claimed", user: user, amount: reward-amount})
      (ok {user: user, reward: reward-amount}))))

;; Read-only functions for contract state
(define-read-only (get-current-price)
  (ok (var-get current-price)))

(define-read-only (get-total-supply)
  (ok (var-get total-supply)))

(define-read-only (get-target-price)
  (ok target-price))

(define-read-only (get-balance (account principal))
  (ok (ft-get-balance algostable-coin account)))

(define-read-only (get-last-rebase-block)
  (ok (var-get last-rebase-block)))

(define-read-only (get-token-info)
  (ok {
    name: (var-get token-name),
    symbol: (var-get token-symbol),
    supply: (var-get total-supply),
    price: (var-get current-price),
    target: target-price
  }))

;; Initialize contract with initial token distribution
(define-public (initialize)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (try! (ft-mint? algostable-coin (var-get total-supply) contract-owner))
    (ok true)))