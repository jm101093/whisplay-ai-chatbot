import RPi.GPIO as GPIO
import time

# Define RGB LED GPIO pins (physical numbering)
RED_PIN = 22
GREEN_PIN = 18
BLUE_PIN = 16

# Set GPIO mode
GPIO.setmode(GPIO.BOARD)
GPIO.setup(RED_PIN, GPIO.OUT)
GPIO.setup(GREEN_PIN, GPIO.OUT)
GPIO.setup(BLUE_PIN, GPIO.OUT)

# Set PWM, frequency is 1kHz
freq = 100
red_pwm = GPIO.PWM(RED_PIN, freq)
green_pwm = GPIO.PWM(GREEN_PIN, freq)
blue_pwm = GPIO.PWM(BLUE_PIN, freq)

# Start PWM, duty cycle is 0 (LED off)
red_pwm.start(0)
green_pwm.start(0)
blue_pwm.start(0)

def set_color(r, g, b):
    """
    Set RGB color, r, g, b value range 0-255
    Since it's common anode LED, duty cycle needs to be converted
    """
    red_pwm.ChangeDutyCycle(100 - (r / 255 * 100))
    green_pwm.ChangeDutyCycle(100 - (g / 255 * 100))
    blue_pwm.ChangeDutyCycle(100 - (b / 255 * 100))

try:
    while True:
        set_color(255, 0, 0)  # Red
        time.sleep(1)
        set_color(0, 255, 0)  # Green
        time.sleep(1)
        set_color(0, 0, 255)  # Blue
        time.sleep(1)
        set_color(255, 255, 0)  # Yellow
        time.sleep(1)
        set_color(0, 255, 255)  # Cyan
        time.sleep(1)
        set_color(255, 0, 255)  # Magenta
        time.sleep(1)
        set_color(255, 255, 255)  # White
        time.sleep(1)
        set_color(0, 0, 0)  # Off
        time.sleep(1)
except KeyboardInterrupt:
    pass

# Clean up GPIO
red_pwm.stop()
green_pwm.stop()
blue_pwm.stop()
GPIO.cleanup()
