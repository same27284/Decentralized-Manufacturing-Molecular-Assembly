;; Facility Verification Contract
;; Validates and manages molecular manufacturing sites

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_FACILITY_NOT_FOUND (err u101))
(define-constant ERR_FACILITY_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_STATUS (err u103))

;; Facility status types
(define-constant STATUS_PENDING u0)
(define-constant STATUS_VERIFIED u1)
(define-constant STATUS_SUSPENDED u2)
(define-constant STATUS_REVOKED u3)

;; Data structures
(define-map facilities
  { facility-id: uint }
  {
    owner: principal,
    location: (string-ascii 100),
    capacity: uint,
    status: uint,
    verification-date: uint,
    certifications: (list 10 (string-ascii 50))
  }
)

(define-map facility-metrics
  { facility-id: uint }
  {
    uptime-percentage: uint,
    quality-score: uint,
    production-volume: uint,
    last-inspection: uint
  }
)

(define-data-var next-facility-id uint u1)

;; Register a new facility
(define-public (register-facility (location (string-ascii 100)) (capacity uint) (certifications (list 10 (string-ascii 50))))
  (let ((facility-id (var-get next-facility-id)))
    (asserts! (is-none (map-get? facilities { facility-id: facility-id })) ERR_FACILITY_ALREADY_EXISTS)
    (map-set facilities
      { facility-id: facility-id }
      {
        owner: tx-sender,
        location: location,
        capacity: capacity,
        status: STATUS_PENDING,
        verification-date: block-height,
        certifications: certifications
      }
    )
    (map-set facility-metrics
      { facility-id: facility-id }
      {
        uptime-percentage: u100,
        quality-score: u100,
        production-volume: u0,
        last-inspection: block-height
      }
    )
    (var-set next-facility-id (+ facility-id u1))
    (ok facility-id)
  )
)

;; Verify a facility (admin only)
(define-public (verify-facility (facility-id uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (match (map-get? facilities { facility-id: facility-id })
      facility-data
      (begin
        (map-set facilities
          { facility-id: facility-id }
          (merge facility-data { status: STATUS_VERIFIED, verification-date: block-height })
        )
        (ok true)
      )
      ERR_FACILITY_NOT_FOUND
    )
  )
)

;; Update facility status
(define-public (update-facility-status (facility-id uint) (new-status uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (<= new-status STATUS_REVOKED) ERR_INVALID_STATUS)
    (match (map-get? facilities { facility-id: facility-id })
      facility-data
      (begin
        (map-set facilities
          { facility-id: facility-id }
          (merge facility-data { status: new-status })
        )
        (ok true)
      )
      ERR_FACILITY_NOT_FOUND
    )
  )
)

;; Update facility metrics
(define-public (update-metrics (facility-id uint) (uptime uint) (quality uint) (volume uint))
  (begin
    (match (map-get? facilities { facility-id: facility-id })
      facility-data
      (begin
        (asserts! (is-eq tx-sender (get owner facility-data)) ERR_UNAUTHORIZED)
        (map-set facility-metrics
          { facility-id: facility-id }
          {
            uptime-percentage: uptime,
            quality-score: quality,
            production-volume: volume,
            last-inspection: block-height
          }
        )
        (ok true)
      )
      ERR_FACILITY_NOT_FOUND
    )
  )
)

;; Read-only functions
(define-read-only (get-facility (facility-id uint))
  (map-get? facilities { facility-id: facility-id })
)

(define-read-only (get-facility-metrics (facility-id uint))
  (map-get? facility-metrics { facility-id: facility-id })
)

(define-read-only (is-facility-verified (facility-id uint))
  (match (map-get? facilities { facility-id: facility-id })
    facility-data (is-eq (get status facility-data) STATUS_VERIFIED)
    false
  )
)
