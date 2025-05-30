;; ChainPath Marketplace Verification System

;; Main item registry with embedded counters
(define-map items
  { id: uint }
  {
    title: (string-utf8 128),
    details: (string-utf8 1024),
    creator: principal,
    lot: (string-ascii 64),
    created: uint,
    status: (string-ascii 32),  ;; "produced", "shipping", "delivered", "sold", "recalled"
    category: (string-ascii 64),
    location: (string-utf8 128),
    keeper: principal,
    destination: (optional (string-utf8 128)),
    arrival: (optional uint),
    metadata: (optional (string-utf8 256)),
    checkpoint-count: uint,
    transfer-count: uint
  }
)

;; Combined tracking events (checkpoints + transfers)
(define-map events
  { item-id: uint, event-id: uint }
  {
    location: (string-utf8 128),
    block: uint,
    actor: principal,
    event-type: (string-ascii 32),  ;; "checkpoint", "transfer-start", "transfer-complete"
    from-keeper: (optional principal),
    to-keeper: (optional principal),
    temp: (optional int),
    humidity: (optional uint),
    notes: (optional (string-utf8 512)),
    hash: (buff 32),
    status: (string-ascii 32)  ;; "active", "pending", "completed", "rejected"
  }
)

;; Simplified authorization
(define-map inspectors
  { org: principal, inspector: principal }
  { name: (string-utf8 128), role: (string-ascii 64), active: bool }
)

;; Certifications
(define-map certs
  { item-id: uint, standard: (string-ascii 64) }
  {
    authority: principal,
    issued: uint,
    expires: uint,
    hash: (buff 32),
    url: (optional (string-utf8 256)),
    valid: bool
  }
)

(define-data-var next-id uint u0)

;; Constants for validation
(define-constant ERR-INVALID-INPUT u100)
(define-constant ERR-ITEM-NOT-FOUND u101)
(define-constant ERR-NOT-AUTHORIZED u102)
(define-constant ERR-ITEM-RECALLED u103)
(define-constant ERR-EVENT-NOT-FOUND u104)
(define-constant ERR-NOT-RECIPIENT u105)
(define-constant ERR-NOT-PENDING u106)
(define-constant ERR-INVALID-EXPIRY u107)
(define-constant ERR-NOT-AUTHORITY u108)
(define-constant ERR-ONLY-CREATOR u109)

;; Input validation functions
(define-private (validate-string-utf8-128 (input (string-utf8 128)))
  (and (> (len input) u0) (<= (len input) u128))
)

(define-private (validate-string-utf8-1024 (input (string-utf8 1024)))
  (and (> (len input) u0) (<= (len input) u1024))
)

(define-private (validate-string-ascii-64 (input (string-ascii 64)))
  (and (> (len input) u0) (<= (len input) u64))
)

(define-private (validate-string-ascii-32 (input (string-ascii 32)))
  (and (> (len input) u0) (<= (len input) u32))
)

(define-private (validate-optional-string-utf8-256 (input (optional (string-utf8 256))))
  (match input
    some-val (and (> (len some-val) u0) (<= (len some-val) u256))
    true)
)

(define-private (validate-optional-string-utf8-512 (input (optional (string-utf8 512))))
  (match input
    some-val (and (> (len some-val) u0) (<= (len some-val) u512))
    true)
)

(define-private (validate-item-id (item-id uint))
  (< item-id (var-get next-id))
)

(define-private (validate-temperature (temp (optional int)))
  (match temp
    some-temp (and (>= some-temp -100) (<= some-temp 100))
    true)
)

(define-private (validate-humidity (humidity (optional uint)))
  (match humidity
    some-hum (<= some-hum u100)
    true)
)

(define-private (validate-event-type (event-type (string-ascii 32)))
  (or (is-eq event-type "checkpoint")
      (is-eq event-type "transfer-start")
      (is-eq event-type "transfer-complete"))
)

(define-private (validate-status (status (string-ascii 32)))
  (or (is-eq status "produced")
      (is-eq status "shipping")
      (is-eq status "delivered")
      (is-eq status "sold")
      (is-eq status "recalled"))
)

(define-private (validate-event-id (item-id uint) (event-id uint))
  (let ((item (map-get? items { id: item-id })))
    (match item
      some-item (or (< event-id (get checkpoint-count some-item))
                    (< event-id (get transfer-count some-item)))
      false))
)

(define-private (validate-principal (principal-input principal))
  (not (is-eq principal-input 'SP000000000000000000002Q6VF78))
)

(define-private (validate-optional-url (url (optional (string-utf8 256))))
  (match url
    some-url (and (> (len some-url) u0) (<= (len some-url) u256))
    true)
)

;; Utility for hashing - now validates input
(define-private (hash-string (input (string-utf8 512)))
  (begin
    (asserts! (and (> (len input) u0) (<= (len input) u512)) 0x00)
    0x737570706c79747261636b20
  )
)

;; Check authorization
(define-private (authorized? (item-keeper principal) (actor principal))
  (or (is-eq actor item-keeper)
      (default-to false (get active (map-get? inspectors { org: item-keeper, inspector: actor }))))
)

;; Register new item with validation
(define-public (register-item
                (title (string-utf8 128))
                (details (string-utf8 1024))
                (lot (string-ascii 64))
                (category (string-ascii 64))
                (location (string-utf8 128))
                (metadata (optional (string-utf8 256))))
  (let ((id (var-get next-id))
        (validated-title (begin (asserts! (validate-string-utf8-128 title) (err ERR-INVALID-INPUT)) title))
        (validated-details (begin (asserts! (validate-string-utf8-1024 details) (err ERR-INVALID-INPUT)) details))
        (validated-lot (begin (asserts! (validate-string-ascii-64 lot) (err ERR-INVALID-INPUT)) lot))
        (validated-category (begin (asserts! (validate-string-ascii-64 category) (err ERR-INVALID-INPUT)) category))
        (validated-location (begin (asserts! (validate-string-utf8-128 location) (err ERR-INVALID-INPUT)) location))
        (validated-metadata (begin (asserts! (validate-optional-string-utf8-256 metadata) (err ERR-INVALID-INPUT)) metadata)))
    
    ;; Create item with validated inputs
    (map-set items { id: id }
      {
        title: validated-title, details: validated-details, creator: tx-sender, lot: validated-lot,
        created: stacks-block-height, status: "produced", category: validated-category,
        location: validated-location, keeper: tx-sender, destination: none,
        arrival: none, metadata: validated-metadata, checkpoint-count: u1, transfer-count: u0
      })
    
    ;; Initial checkpoint with validated data
    (map-set events { item-id: id, event-id: u0 }
      {
        location: validated-location, block: stacks-block-height, actor: tx-sender,
        event-type: "checkpoint", from-keeper: none, to-keeper: none,
        temp: none, humidity: none, notes: (some u"Item produced"),
        hash: (sha256 (hash-string validated-title)), status: "completed"
      })
    
    (var-set next-id (+ id u1))
    (ok id)
  )
)

;; Add checkpoint or initiate transfer with validation
(define-public (add-event
                (item-id uint)
                (location (string-utf8 128))
                (event-type (string-ascii 32))
                (to-keeper (optional principal))
                (temp (optional int))
                (humidity (optional uint))
                (notes (optional (string-utf8 512))))
  (let
    ((validated-item-id (begin (asserts! (validate-item-id item-id) (err ERR-INVALID-INPUT)) item-id))
     (validated-location (begin (asserts! (validate-string-utf8-128 location) (err ERR-INVALID-INPUT)) location))
     (validated-event-type (begin (asserts! (validate-event-type event-type) (err ERR-INVALID-INPUT)) event-type))
     (validated-temp (begin (asserts! (validate-temperature temp) (err ERR-INVALID-INPUT)) temp))
     (validated-humidity (begin (asserts! (validate-humidity humidity) (err ERR-INVALID-INPUT)) humidity))
     (validated-notes (begin (asserts! (validate-optional-string-utf8-512 notes) (err ERR-INVALID-INPUT)) notes))
     (item (unwrap! (map-get? items { id: validated-item-id }) (err ERR-ITEM-NOT-FOUND)))
     (event-id (if (is-eq validated-event-type "checkpoint") 
                   (get checkpoint-count item)
                   (get transfer-count item))))
    
    (asserts! (authorized? (get keeper item) tx-sender) (err ERR-NOT-AUTHORIZED))
    (asserts! (not (is-eq (get status item) "recalled")) (err ERR-ITEM-RECALLED))
    
    ;; Create event with validated data
    (map-set events { item-id: validated-item-id, event-id: event-id }
      {
        location: validated-location, block: stacks-block-height, actor: tx-sender,
        event-type: validated-event-type, from-keeper: (some (get keeper item)),
        to-keeper: to-keeper, temp: validated-temp, humidity: validated-humidity, notes: validated-notes,
        hash: (sha256 (hash-string validated-location)),
        status: (if (is-some to-keeper) "pending" "completed")
      })
    
    ;; Update item counters and status
    (map-set items { id: validated-item-id }
      (merge item {
        checkpoint-count: (if (is-eq validated-event-type "checkpoint") (+ (get checkpoint-count item) u1) (get checkpoint-count item)),
        transfer-count: (if (is-eq validated-event-type "transfer-start") (+ (get transfer-count item) u1) (get transfer-count item)),
        status: (if (is-eq validated-event-type "checkpoint") "shipping" (get status item))
      }))
    
    (ok event-id)
  )
)

;; Accept transfer with validation
(define-public (accept-transfer (item-id uint) (event-id uint))
  (let
    ((validated-item-id (begin (asserts! (validate-item-id item-id) (err ERR-INVALID-INPUT)) item-id))
     (validated-event-id (begin (asserts! (validate-event-id item-id event-id) (err ERR-INVALID-INPUT)) event-id))
     (item (unwrap! (map-get? items { id: validated-item-id }) (err ERR-ITEM-NOT-FOUND)))
     (event (unwrap! (map-get? events { item-id: validated-item-id, event-id: validated-event-id }) (err ERR-EVENT-NOT-FOUND))))
    
    (asserts! (is-eq (some tx-sender) (get to-keeper event)) (err ERR-NOT-RECIPIENT))
    (asserts! (is-eq (get status event) "pending") (err ERR-NOT-PENDING))
    
    ;; Update event
    (map-set events { item-id: validated-item-id, event-id: validated-event-id }
      (merge event { status: "completed" }))
    
    ;; Update item keeper
    (map-set items { id: validated-item-id }
      (merge item { keeper: tx-sender, status: "delivered" }))
    
    (ok true)
  )
)

;; Reject transfer with validation
(define-public (reject-transfer (item-id uint) (event-id uint))
  (let
    ((validated-item-id (begin (asserts! (validate-item-id item-id) (err ERR-INVALID-INPUT)) item-id))
     (validated-event-id (begin (asserts! (validate-event-id item-id event-id) (err ERR-INVALID-INPUT)) event-id))
     (event (unwrap! (map-get? events { item-id: validated-item-id, event-id: validated-event-id }) (err ERR-EVENT-NOT-FOUND))))
    
    (asserts! (is-eq (some tx-sender) (get to-keeper event)) (err ERR-NOT-RECIPIENT))
    (asserts! (is-eq (get status event) "pending") (err ERR-NOT-PENDING))
    
    (map-set events { item-id: validated-item-id, event-id: validated-event-id }
      (merge event { status: "rejected" }))
    
    (ok true)
  )
)

;; Authorize inspector with validation
(define-public (authorize-inspector (inspector principal) (name (string-utf8 128)) (role (string-ascii 64)))
  (let ((validated-inspector (begin (asserts! (validate-principal inspector) (err ERR-INVALID-INPUT)) inspector))
        (validated-name (begin (asserts! (validate-string-utf8-128 name) (err ERR-INVALID-INPUT)) name))
        (validated-role (begin (asserts! (validate-string-ascii-64 role) (err ERR-INVALID-INPUT)) role)))
    (map-set inspectors { org: tx-sender, inspector: validated-inspector }
      { name: validated-name, role: validated-role, active: true })
    (ok true)
  )
)

;; Revoke inspector with validation
(define-public (revoke-inspector (inspector principal))
  (let ((validated-inspector (begin (asserts! (validate-principal inspector) (err ERR-INVALID-INPUT)) inspector))
        (record (unwrap! (map-get? inspectors { org: tx-sender, inspector: validated-inspector }) (err ERR-EVENT-NOT-FOUND))))
    (map-set inspectors { org: tx-sender, inspector: validated-inspector }
      (merge record { active: false }))
    (ok true)
  )
)

;; Add certification with validation
(define-public (add-cert
                (item-id uint)
                (standard (string-ascii 64))
                (expires uint)
                (hash (buff 32))
                (url (optional (string-utf8 256))))
  (let ((validated-item-id (begin (asserts! (validate-item-id item-id) (err ERR-INVALID-INPUT)) item-id))
        (validated-standard (begin (asserts! (validate-string-ascii-64 standard) (err ERR-INVALID-INPUT)) standard))
        (validated-hash (begin (asserts! (is-eq (len hash) u32) (err ERR-INVALID-INPUT)) hash))
        (validated-url (begin (asserts! (validate-optional-url url) (err ERR-INVALID-INPUT)) url))
        (item (unwrap! (map-get? items { id: validated-item-id }) (err ERR-ITEM-NOT-FOUND))))
    
    (asserts! (authorized? (get creator item) tx-sender) (err ERR-NOT-AUTHORIZED))
    (asserts! (> expires stacks-block-height) (err ERR-INVALID-EXPIRY))
    
    (map-set certs { item-id: validated-item-id, standard: validated-standard }
      {
        authority: tx-sender, issued: stacks-block-height, expires: expires,
        hash: validated-hash, url: validated-url, valid: true
      })
    
    (ok true)
  )
)

;; Revoke certification with validation
(define-public (revoke-cert (item-id uint) (standard (string-ascii 64)))
  (let ((validated-item-id (begin (asserts! (validate-item-id item-id) (err ERR-INVALID-INPUT)) item-id))
        (validated-standard (begin (asserts! (validate-string-ascii-64 standard) (err ERR-INVALID-INPUT)) standard))
        (cert (unwrap! (map-get? certs { item-id: validated-item-id, standard: validated-standard }) (err ERR-EVENT-NOT-FOUND))))
    
    (asserts! (is-eq tx-sender (get authority cert)) (err ERR-NOT-AUTHORITY))
    
    (map-set certs { item-id: validated-item-id, standard: validated-standard }
      (merge cert { valid: false }))
    
    (ok true)
  )
)

;; Recall item with validation
(define-public (recall-item (item-id uint) (reason (string-utf8 512)))
  (let ((validated-item-id (begin (asserts! (validate-item-id item-id) (err ERR-INVALID-INPUT)) item-id))
        (validated-reason (begin (asserts! (and (> (len reason) u0) (<= (len reason) u512)) (err ERR-INVALID-INPUT)) reason))
        (item (unwrap! (map-get? items { id: validated-item-id }) (err ERR-ITEM-NOT-FOUND))))
    
    (asserts! (is-eq tx-sender (get creator item)) (err ERR-ONLY-CREATOR))
    
    ;; Update item status
    (map-set items { id: validated-item-id }
      (merge item { status: "recalled" }))
    
    ;; Add recall event
    (try! (add-event validated-item-id u"recall-notice" "checkpoint" none none none (some validated-reason)))
    
    (ok true)
  )
)

;; Set delivery info with validation
(define-public (set-delivery (item-id uint) (destination (string-utf8 128)) (arrival uint))
  (let ((validated-item-id (begin (asserts! (validate-item-id item-id) (err ERR-INVALID-INPUT)) item-id))
        (validated-destination (begin (asserts! (validate-string-utf8-128 destination) (err ERR-INVALID-INPUT)) destination))
        (item (unwrap! (map-get? items { id: validated-item-id }) (err ERR-ITEM-NOT-FOUND))))
    
    (asserts! (authorized? (get keeper item) tx-sender) (err ERR-NOT-AUTHORIZED))
    (asserts! (> arrival stacks-block-height) (err ERR-INVALID-INPUT))
    
    (map-set items { id: validated-item-id }
      (merge item { destination: (some validated-destination), arrival: (some arrival) }))
    
    (ok true)
  )
)

;; Read-only functions with validation
(define-read-only (get-item (item-id uint))
  (begin
    (asserts! (validate-item-id item-id) (err ERR-INVALID-INPUT))
    (ok (unwrap! (map-get? items { id: item-id }) (err ERR-ITEM-NOT-FOUND)))
  )
)

(define-read-only (get-event (item-id uint) (event-id uint))
  (begin
    (asserts! (validate-item-id item-id) (err ERR-INVALID-INPUT))
    (ok (unwrap! (map-get? events { item-id: item-id, event-id: event-id }) (err ERR-EVENT-NOT-FOUND)))
  )
)

(define-read-only (get-cert (item-id uint) (standard (string-ascii 64)))
  (let ((validated-item-id (begin (asserts! (validate-item-id item-id) (err ERR-INVALID-INPUT)) item-id))
        (validated-standard (begin (asserts! (validate-string-ascii-64 standard) (err ERR-INVALID-INPUT)) standard)))
    (ok (unwrap! (map-get? certs { item-id: validated-item-id, standard: validated-standard }) (err ERR-EVENT-NOT-FOUND)))
  )
)

(define-read-only (is-cert-valid (item-id uint) (standard (string-ascii 64)))
  (let ((validated-item-id (begin (asserts! (validate-item-id item-id) false) item-id))
        (validated-standard (begin (asserts! (validate-string-ascii-64 standard) false) standard)))
    (match (map-get? certs { item-id: validated-item-id, standard: validated-standard })
      cert (and (get valid cert) (> (get expires cert) stacks-block-height))
      false)
  )
)

(define-read-only (verify-item (item-id uint))
  (let ((validated-item-id (begin (asserts! (validate-item-id item-id) (err ERR-INVALID-INPUT)) item-id)))
    (match (map-get? items { id: validated-item-id })
      item (ok { authentic: true, creator: (get creator item), lot: (get lot item), status: (get status item) })
      (err ERR-ITEM-NOT-FOUND))
  )
)