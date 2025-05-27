;; Assembly Protocol Contract
;; Manages molecular-level production protocols

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_PROTOCOL_NOT_FOUND (err u201))
(define-constant ERR_INVALID_PARAMETERS (err u202))
(define-constant ERR_FACILITY_NOT_VERIFIED (err u203))

;; Protocol status
(define-constant PROTOCOL_DRAFT u0)
(define-constant PROTOCOL_ACTIVE u1)
(define-constant PROTOCOL_DEPRECATED u2)

;; Data structures
(define-map assembly-protocols
  { protocol-id: uint }
  {
    name: (string-ascii 100),
    creator: principal,
    molecular-formula: (string-ascii 200),
    assembly-steps: (list 20 (string-ascii 100)),
    temperature-range: { min: uint, max: uint },
    pressure-range: { min: uint, max: uint },
    duration-minutes: uint,
    status: uint,
    created-at: uint
  }
)

(define-map protocol-executions
  { execution-id: uint }
  {
    protocol-id: uint,
    facility-id: uint,
    executor: principal,
    start-time: uint,
    end-time: (optional uint),
    success: (optional bool),
    yield-percentage: (optional uint),
    notes: (optional (string-ascii 500))
  }
)

(define-data-var next-protocol-id uint u1)
(define-data-var next-execution-id uint u1)

;; Create a new assembly protocol
(define-public (create-protocol
  (name (string-ascii 100))
  (molecular-formula (string-ascii 200))
  (assembly-steps (list 20 (string-ascii 100)))
  (temp-min uint) (temp-max uint)
  (pressure-min uint) (pressure-max uint)
  (duration uint))
  (let ((protocol-id (var-get next-protocol-id)))
    (asserts! (> (len assembly-steps) u0) ERR_INVALID_PARAMETERS)
    (asserts! (< temp-min temp-max) ERR_INVALID_PARAMETERS)
    (asserts! (< pressure-min pressure-max) ERR_INVALID_PARAMETERS)
    (map-set assembly-protocols
      { protocol-id: protocol-id }
      {
        name: name,
        creator: tx-sender,
        molecular-formula: molecular-formula,
        assembly-steps: assembly-steps,
        temperature-range: { min: temp-min, max: temp-max },
        pressure-range: { min: pressure-min, max: pressure-max },
        duration-minutes: duration,
        status: PROTOCOL_DRAFT,
        created-at: block-height
      }
    )
    (var-set next-protocol-id (+ protocol-id u1))
    (ok protocol-id)
  )
)

;; Activate a protocol (admin only)
(define-public (activate-protocol (protocol-id uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (match (map-get? assembly-protocols { protocol-id: protocol-id })
      protocol-data
      (begin
        (map-set assembly-protocols
          { protocol-id: protocol-id }
          (merge protocol-data { status: PROTOCOL_ACTIVE })
        )
        (ok true)
      )
      ERR_PROTOCOL_NOT_FOUND
    )
  )
)

;; Start protocol execution
(define-public (start-execution (protocol-id uint) (facility-id uint))
  (let ((execution-id (var-get next-execution-id)))
    (match (map-get? assembly-protocols { protocol-id: protocol-id })
      protocol-data
      (begin
        (asserts! (is-eq (get status protocol-data) PROTOCOL_ACTIVE) ERR_INVALID_PARAMETERS)
        ;; Note: In a real implementation, we'd verify facility status via contract call
        (map-set protocol-executions
          { execution-id: execution-id }
          {
            protocol-id: protocol-id,
            facility-id: facility-id,
            executor: tx-sender,
            start-time: block-height,
            end-time: none,
            success: none,
            yield-percentage: none,
            notes: none
          }
        )
        (var-set next-execution-id (+ execution-id u1))
        (ok execution-id)
      )
      ERR_PROTOCOL_NOT_FOUND
    )
  )
)

;; Complete protocol execution
(define-public (complete-execution
  (execution-id uint)
  (success bool)
  (yield-percentage uint)
  (notes (string-ascii 500)))
  (match (map-get? protocol-executions { execution-id: execution-id })
    execution-data
    (begin
      (asserts! (is-eq tx-sender (get executor execution-data)) ERR_UNAUTHORIZED)
      (asserts! (is-none (get end-time execution-data)) ERR_INVALID_PARAMETERS)
      (map-set protocol-executions
        { execution-id: execution-id }
        (merge execution-data {
          end-time: (some block-height),
          success: (some success),
          yield-percentage: (some yield-percentage),
          notes: (some notes)
        })
      )
      (ok true)
    )
    ERR_PROTOCOL_NOT_FOUND
  )
)

;; Read-only functions
(define-read-only (get-protocol (protocol-id uint))
  (map-get? assembly-protocols { protocol-id: protocol-id })
)

(define-read-only (get-execution (execution-id uint))
  (map-get? protocol-executions { execution-id: execution-id })
)

(define-read-only (get-protocol-count)
  (var-get next-protocol-id)
)
