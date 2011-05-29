(define PIN_LED 13)

(pin-mode PIN_LED HIGH)

(define (loop)
  (digital-write PIN_LED HIGH)
  (sleep 1000)
  (digital-write PIN_LED HIGH)
  (loop))

(loop)
