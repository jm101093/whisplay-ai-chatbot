import RPi.GPIO as GPIO
import time

# Define the physical pin number for the switch connection
SWITCH_PIN = 11  # Physical pin 11

# Set GPIO mode to BOARD numbering (using physical pin numbers)
GPIO.setmode(GPIO.BOARD)

# Set GPIO pin to input mode with pull-up resistor enabled
GPIO.setup(SWITCH_PIN, GPIO.IN, pull_up_down=GPIO.PUD_UP)

try:
    print(f"Listening to switch connected to physical pin {SWITCH_PIN} (GPIO {GPIO.gpio_function(SWITCH_PIN)})...")
    while True:
        # Read the switch state
        switch_state = GPIO.input(SWITCH_PIN)

        if switch_state == GPIO.LOW:
            print("Switch pressed")
        else:
            print("Switch released")

        time.sleep(0.2)

except KeyboardInterrupt:
    print("Program stopped")
finally:
    GPIO.cleanup()