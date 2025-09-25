(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-INVALID-INPUT (err u400))
(define-constant ERR-PROBLEM-NOT-FOUND (err u404))
(define-constant ERR-SOLUTION-NOT-FOUND (err u405))
(define-constant ERR-INSUFFICIENT-FUNDS (err u402))
(define-constant ERR-PROBLEM-CLOSED (err u403))
(define-constant ERR-ALREADY-VOTED (err u406))
(define-constant ERR-DEADLINE-PASSED (err u407))
(define-constant ERR-INVALID-STATUS (err u408))
(define-constant ERR-NOT-SOLVER (err u409))
(define-constant ERR-ALREADY-SOLVED (err u410))
(define-constant ERR-INSUFFICIENT-REPUTATION (err u411))

(define-constant CONTRACT-OWNER tx-sender)

(define-constant STATUS-OPEN u1)
(define-constant STATUS-ANALYZING u2)
(define-constant STATUS-SOLVED u3)
(define-constant STATUS-VERIFIED u4)
(define-constant STATUS-CLOSED u5)

(define-constant SOLUTION-PENDING u1)
(define-constant SOLUTION-APPROVED u2)
(define-constant SOLUTION-REJECTED u3)
(define-constant SOLUTION-VERIFIED u4)

(define-constant MIN-REPUTATION u10)
(define-constant VERIFICATION-THRESHOLD u3)
(define-constant COGNITIVE-COMPLEXITY-MAX u10)

(define-data-var problem-nonce uint u0)
(define-data-var solution-nonce uint u0)
(define-data-var platform-fee uint u2)
(define-data-var min-reward uint u50000)

(define-map problems
  { problem-id: uint }
  {
    creator: principal,
    title: (string-ascii 100),
    description: (string-ascii 1000),
    category: (string-ascii 50),
    cognitive-complexity: uint,
    reward-amount: uint,
    deadline: uint,
    created-at: uint,
    status: uint,
    solution-count: uint,
    winning-solution: (optional uint),
    verification-count: uint,
    required-skills: (list 5 (string-ascii 40)),
    thinking-method: (string-ascii 80)
  }
)

(define-map solutions
  { solution-id: uint }
  {
    problem-id: uint,
    solver: principal,
    title: (string-ascii 100),
    approach-description: (string-ascii 1200),
    reasoning-process: (string-ascii 800),
    implementation-steps: (string-ascii 600),
    expected-outcome: (string-ascii 400),
    cognitive-method: (string-ascii 60),
    submitted-at: uint,
    status: uint,
    verification-score: uint,
    peer-ratings: uint,
    effectiveness-rating: uint
  }
)

(define-map solution-verifications
  { solution-id: uint, verifier: principal }
  {
    verified-at: uint,
    accuracy-score: uint,
    logic-score: uint,
    feasibility-score: uint,
    comments: (string-ascii 200),
    overall-rating: uint
  }
)

(define-map peer-votes
  { solution-id: uint, voter: principal }
  {
    vote-weight: uint,
    reasoning-quality: uint,
    innovation-score: uint,
    clarity-score: uint,
    voted-at: uint
  }
)

(define-map cognitive-profiles
  { solver: principal }
  {
    problems-solved: uint,
    solutions-submitted: uint,
    verification-count: uint,
    reputation-score: uint,
    cognitive-skills: (list 8 (string-ascii 40)),
    specialization-areas: (list 6 (string-ascii 50)),
    success-rate: uint,
    total-earned: uint,
    thinking-styles: (list 4 (string-ascii 30))
  }
)

(define-map problem-analytics
  { problem-id: uint }
  {
    cognitive-patterns: (list 10 uint),
    solution-effectiveness: uint,
    solving-time: uint,
    complexity-achieved: uint,
    innovation-level: uint,
    knowledge-areas: (list 8 (string-ascii 40))
  }
)

(define-public (create-problem
  (title (string-ascii 100))
  (description (string-ascii 1000))
  (category (string-ascii 50))
  (cognitive-complexity uint)
  (reward-amount uint)
  (deadline-blocks uint)
  (required-skills (list 5 (string-ascii 40)))
  (thinking-method (string-ascii 80))
)
  (let (
    (problem-id (+ (var-get problem-nonce) u1))
    (creator tx-sender)
    (deadline (+ stacks-block-height deadline-blocks))
  )
    (asserts! (>= reward-amount (var-get min-reward)) ERR-INSUFFICIENT-FUNDS)
    (asserts! (> deadline-blocks u0) ERR-INVALID-INPUT)
    (asserts! (> (len title) u0) ERR-INVALID-INPUT)
    (asserts! (> (len description) u20) ERR-INVALID-INPUT)
    (asserts! (and (<= cognitive-complexity COGNITIVE-COMPLEXITY-MAX) (>= cognitive-complexity u1)) ERR-INVALID-INPUT)

    (try! (stx-transfer? reward-amount creator (as-contract tx-sender)))

    (map-set problems
      {problem-id: problem-id}
      {
        creator: creator,
        title: title,
        description: description,
        category: category,
        cognitive-complexity: cognitive-complexity,
        reward-amount: reward-amount,
        deadline: deadline,
        created-at: stacks-block-height,
        status: STATUS-OPEN,
        solution-count: u0,
        winning-solution: none,
        verification-count: u0,
        required-skills: required-skills,
        thinking-method: thinking-method
      }
    )

    (var-set problem-nonce problem-id)
    (ok problem-id)
  )
)

(define-public (submit-solution
  (problem-id uint)
  (title (string-ascii 100))
  (approach-description (string-ascii 1200))
  (reasoning-process (string-ascii 800))
  (implementation-steps (string-ascii 600))
  (expected-outcome (string-ascii 400))
  (cognitive-method (string-ascii 60))
)
  (let (
    (solution-id (+ (var-get solution-nonce) u1))
    (solver tx-sender)
    (problem (unwrap! (map-get? problems {problem-id: problem-id}) ERR-PROBLEM-NOT-FOUND))
    (solver-profile (default-to
      {problems-solved: u0, solutions-submitted: u0, verification-count: u0, reputation-score: u100, cognitive-skills: (list), specialization-areas: (list), success-rate: u100, total-earned: u0, thinking-styles: (list)}
      (map-get? cognitive-profiles {solver: solver})
    ))
  )
    (asserts! (is-eq (get status problem) STATUS-OPEN) ERR-PROBLEM-CLOSED)
    (asserts! (< stacks-block-height (get deadline problem)) ERR-DEADLINE-PASSED)
    (asserts! (>= (get reputation-score solver-profile) MIN-REPUTATION) ERR-INSUFFICIENT-REPUTATION)
    (asserts! (> (len title) u0) ERR-INVALID-INPUT)
    (asserts! (> (len approach-description) u50) ERR-INVALID-INPUT)
    (asserts! (> (len reasoning-process) u30) ERR-INVALID-INPUT)

    (map-set solutions
      {solution-id: solution-id}
      {
        problem-id: problem-id,
        solver: solver,
        title: title,
        approach-description: approach-description,
        reasoning-process: reasoning-process,
        implementation-steps: implementation-steps,
        expected-outcome: expected-outcome,
        cognitive-method: cognitive-method,
        submitted-at: stacks-block-height,
        status: SOLUTION-PENDING,
        verification-score: u0,
        peer-ratings: u0,
        effectiveness-rating: u0
      }
    )

    (map-set problems
      {problem-id: problem-id}
      (merge problem {solution-count: (+ (get solution-count problem) u1)})
    )

    (map-set cognitive-profiles
      {solver: solver}
      (merge solver-profile {solutions-submitted: (+ (get solutions-submitted solver-profile) u1)})
    )

    (var-set solution-nonce solution-id)
    (ok solution-id)
  )
)

(define-public (verify-solution
  (solution-id uint)
  (accuracy-score uint)
  (logic-score uint)
  (feasibility-score uint)
  (comments (string-ascii 200))
)
  (let (
    (verifier tx-sender)
    (solution (unwrap! (map-get? solutions {solution-id: solution-id}) ERR-SOLUTION-NOT-FOUND))
    (problem (unwrap! (map-get? problems {problem-id: (get problem-id solution)}) ERR-PROBLEM-NOT-FOUND))
    (verifier-profile (default-to
      {problems-solved: u0, solutions-submitted: u0, verification-count: u0, reputation-score: u100, cognitive-skills: (list), specialization-areas: (list), success-rate: u100, total-earned: u0, thinking-styles: (list)}
      (map-get? cognitive-profiles {solver: verifier})
    ))
    (overall-rating (/ (+ accuracy-score logic-score feasibility-score) u3))
  )
    (asserts! (not (is-eq verifier (get solver solution))) ERR-NOT-AUTHORIZED)
    (asserts! (>= (get reputation-score verifier-profile) u20) ERR-INSUFFICIENT-REPUTATION)
    (asserts! (is-none (map-get? solution-verifications {solution-id: solution-id, verifier: verifier})) ERR-ALREADY-VOTED)
    (asserts! (<= accuracy-score u100) ERR-INVALID-INPUT)
    (asserts! (<= logic-score u100) ERR-INVALID-INPUT)
    (asserts! (<= feasibility-score u100) ERR-INVALID-INPUT)

    (map-set solution-verifications
      {solution-id: solution-id, verifier: verifier}
      {
        verified-at: stacks-block-height,
        accuracy-score: accuracy-score,
        logic-score: logic-score,
        feasibility-score: feasibility-score,
        comments: comments,
        overall-rating: overall-rating
      }
    )

    (let (
      (updated-verification-score (+ (get verification-score solution) overall-rating))
      (updated-solution (merge solution {verification-score: updated-verification-score}))
    )
      (map-set solutions {solution-id: solution-id} updated-solution)
    )

    (map-set problems
      {problem-id: (get problem-id solution)}
      (merge problem {verification-count: (+ (get verification-count problem) u1)})
    )

    (map-set cognitive-profiles
      {solver: verifier}
      (merge verifier-profile {
        verification-count: (+ (get verification-count verifier-profile) u1),
        reputation-score: (+ (get reputation-score verifier-profile) u5)
      })
    )

    (ok true)
  )
)

(define-public (peer-rate-solution
  (solution-id uint)
  (vote-weight uint)
  (reasoning-quality uint)
  (innovation-score uint)
  (clarity-score uint)
)
  (let (
    (voter tx-sender)
    (solution (unwrap! (map-get? solutions {solution-id: solution-id}) ERR-SOLUTION-NOT-FOUND))
    (problem (unwrap! (map-get? problems {problem-id: (get problem-id solution)}) ERR-PROBLEM-NOT-FOUND))
  )
    (asserts! (not (is-eq voter (get solver solution))) ERR-NOT-AUTHORIZED)
    (asserts! (is-none (map-get? peer-votes {solution-id: solution-id, voter: voter})) ERR-ALREADY-VOTED)
    (asserts! (and (>= vote-weight u1) (<= vote-weight u5)) ERR-INVALID-INPUT)
    (asserts! (<= reasoning-quality u100) ERR-INVALID-INPUT)
    (asserts! (<= innovation-score u100) ERR-INVALID-INPUT)
    (asserts! (<= clarity-score u100) ERR-INVALID-INPUT)

    (map-set peer-votes
      {solution-id: solution-id, voter: voter}
      {
        vote-weight: vote-weight,
        reasoning-quality: reasoning-quality,
        innovation-score: innovation-score,
        clarity-score: clarity-score,
        voted-at: stacks-block-height
      }
    )

    (let (
      (weighted-rating (* vote-weight (/ (+ reasoning-quality innovation-score clarity-score) u3)))
      (updated-ratings (+ (get peer-ratings solution) weighted-rating))
    )
      (map-set solutions
        {solution-id: solution-id}
        (merge solution {peer-ratings: updated-ratings})
      )
    )

    (ok true)
  )
)

(define-public (select-winning-solution
  (problem-id uint)
  (winning-solution-id uint)
)
  (let (
    (problem (unwrap! (map-get? problems {problem-id: problem-id}) ERR-PROBLEM-NOT-FOUND))
    (solution (unwrap! (map-get? solutions {solution-id: winning-solution-id}) ERR-SOLUTION-NOT-FOUND))
  )
    (asserts! (is-eq tx-sender (get creator problem)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status problem) STATUS-OPEN) ERR-INVALID-STATUS)
    (asserts! (is-eq (get problem-id solution) problem-id) ERR-INVALID-INPUT)
    (asserts! (>= (get verification-count problem) VERIFICATION-THRESHOLD) ERR-INVALID-STATUS)

    (map-set problems
      {problem-id: problem-id}
      (merge problem {
        status: STATUS-SOLVED,
        winning-solution: (some winning-solution-id)
      })
    )

    (map-set solutions
      {solution-id: winning-solution-id}
      (merge solution {status: SOLUTION-APPROVED})
    )

    (try! (distribute-rewards problem-id winning-solution-id))
    (try! (update-analytics problem-id))

    (ok true)
  )
)

(define-public (verify-problem-solved
  (problem-id uint)
  (effectiveness-rating uint)
)
  (let (
    (problem (unwrap! (map-get? problems {problem-id: problem-id}) ERR-PROBLEM-NOT-FOUND))
    (winning-solution-id (unwrap! (get winning-solution problem) ERR-SOLUTION-NOT-FOUND))
    (solution (unwrap! (map-get? solutions {solution-id: winning-solution-id}) ERR-SOLUTION-NOT-FOUND))
  )
    (asserts! (is-eq tx-sender (get creator problem)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status problem) STATUS-SOLVED) ERR-INVALID-STATUS)
    (asserts! (<= effectiveness-rating u100) ERR-INVALID-INPUT)

    (map-set problems
      {problem-id: problem-id}
      (merge problem {status: STATUS-VERIFIED})
    )

    (map-set solutions
      {solution-id: winning-solution-id}
      (merge solution {
        status: SOLUTION-VERIFIED,
        effectiveness-rating: effectiveness-rating
      })
    )

    (let (
      (solver (get solver solution))
      (solver-profile (default-to
        {problems-solved: u0, solutions-submitted: u0, verification-count: u0, reputation-score: u100, cognitive-skills: (list), specialization-areas: (list), success-rate: u100, total-earned: u0, thinking-styles: (list)}
        (map-get? cognitive-profiles {solver: solver})
      ))
      (reputation-bonus (if (>= effectiveness-rating u80) u50 u20))
    )
      (map-set cognitive-profiles
        {solver: solver}
        (merge solver-profile {
          problems-solved: (+ (get problems-solved solver-profile) u1),
          reputation-score: (+ (get reputation-score solver-profile) reputation-bonus),
          success-rate: (/ (* (+ (get problems-solved solver-profile) u1) u100) (get solutions-submitted solver-profile))
        })
      )
    )

    (ok true)
  )
)

(define-public (update-cognitive-skills
  (solver principal)
  (cognitive-skills (list 8 (string-ascii 40)))
  (specialization-areas (list 6 (string-ascii 50)))
  (thinking-styles (list 4 (string-ascii 30)))
)
  (let (
    (profile (default-to
      {problems-solved: u0, solutions-submitted: u0, verification-count: u0, reputation-score: u100, cognitive-skills: (list), specialization-areas: (list), success-rate: u100, total-earned: u0, thinking-styles: (list)}
      (map-get? cognitive-profiles {solver: solver})
    ))
  )
    (asserts! (is-eq tx-sender solver) ERR-NOT-AUTHORIZED)

    (map-set cognitive-profiles
      {solver: solver}
      (merge profile {
        cognitive-skills: cognitive-skills,
        specialization-areas: specialization-areas,
        thinking-styles: thinking-styles
      })
    )

    (ok true)
  )
)

(define-private (distribute-rewards (problem-id uint) (winning-solution-id uint))
  (let (
    (problem (unwrap! (map-get? problems {problem-id: problem-id}) ERR-PROBLEM-NOT-FOUND))
    (solution (unwrap! (map-get? solutions {solution-id: winning-solution-id}) ERR-SOLUTION-NOT-FOUND))
    (total-reward (get reward-amount problem))
    (platform-fee-amount (/ (* total-reward (var-get platform-fee)) u100))
    (winner-amount (- total-reward platform-fee-amount))
    (winner (get solver solution))
  )
    (try! (as-contract (stx-transfer? winner-amount tx-sender winner)))

    (let (
      (profile (default-to
        {problems-solved: u0, solutions-submitted: u0, verification-count: u0, reputation-score: u100, cognitive-skills: (list), specialization-areas: (list), success-rate: u100, total-earned: u0, thinking-styles: (list)}
        (map-get? cognitive-profiles {solver: winner})
      ))
    )
      (map-set cognitive-profiles
        {solver: winner}
        (merge profile {
          total-earned: (+ (get total-earned profile) winner-amount),
          reputation-score: (+ (get reputation-score profile) u30)
        })
      )
    )

    (ok true)
  )
)

(define-private (update-analytics (problem-id uint))
  (let (
    (problem (unwrap! (map-get? problems {problem-id: problem-id}) ERR-PROBLEM-NOT-FOUND))
    (solving-time (- stacks-block-height (get created-at problem)))
  )
    (map-set problem-analytics
      {problem-id: problem-id}
      {
        cognitive-patterns: (list (get cognitive-complexity problem) (get solution-count problem) u85 u90 u75 u88 u92 u80 u87 u95),
        solution-effectiveness: u85,
        solving-time: solving-time,
        complexity-achieved: (get cognitive-complexity problem),
        innovation-level: u75,
        knowledge-areas: (list "problem-solving" "critical-thinking" "logic" "creativity" "analysis" "synthesis" "evaluation" "application")
      }
    )
    (ok true)
  )
)

(define-read-only (get-problem (problem-id uint))
  (map-get? problems {problem-id: problem-id})
)

(define-read-only (get-solution (solution-id uint))
  (map-get? solutions {solution-id: solution-id})
)

(define-read-only (get-cognitive-profile (solver principal))
  (map-get? cognitive-profiles {solver: solver})
)

(define-read-only (get-solution-verification (solution-id uint) (verifier principal))
  (map-get? solution-verifications {solution-id: solution-id, verifier: verifier})
)

(define-read-only (get-peer-vote (solution-id uint) (voter principal))
  (map-get? peer-votes {solution-id: solution-id, voter: voter})
)

(define-read-only (get-problem-analytics (problem-id uint))
  (map-get? problem-analytics {problem-id: problem-id})
)

(define-read-only (get-platform-stats)
  {
    total-problems: (var-get problem-nonce),
    total-solutions: (var-get solution-nonce),
    platform-fee: (var-get platform-fee),
    min-reward: (var-get min-reward),
    min-reputation: MIN-REPUTATION,
    verification-threshold: VERIFICATION-THRESHOLD
  }
)

(define-public (set-platform-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (<= new-fee u10) ERR-INVALID-INPUT)
    (var-set platform-fee new-fee)
    (ok true)
  )
)

(define-public (set-min-reward (new-min uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> new-min u0) ERR-INVALID-INPUT)
    (var-set min-reward new-min)
    (ok true)
  )
)

(begin
  (var-set platform-fee u2)
  (var-set min-reward u50000)
)