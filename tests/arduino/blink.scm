(define PIN_LED 13)

(pin-mode PIN_LED HIGH)

(define (main)
  (let loop ()
    ;; (display "digital write HIGH")
    (digital-write PIN_LED HIGH)
    (sleep 1000)
    ;; (display "digital write LOW")
    (digital-write PIN_LED LOW)
    (sleep 1000)
    (loop)))

(main)
