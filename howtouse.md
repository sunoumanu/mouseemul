To use your Tang Nano 20K as a USB mouse, you need to physically connect a USB cable or connector to the specific GPIO pins defined in your project. Since the Tang Nano 20K's built-in USB-C port is typically used for programming and power, you must create a second USB connection for the emulated mouse.

1. Pin Connections
Based on your 
tangnano20k.cst
 file, here are the pins you need to use:

USB Signal	Wire Color (Typical)	Tang Nano 20K Pin	Note
D+	Green	Pin 69	Requires Pull-up (see below)
D-	White	Pin 70	
GND	Black	GND	Connect to any GND pin
VBUS	Red	NC	Do NOT connect if powering board via USB-C
2. Hardware Setup (Crucial Step)
The USB host (your computer) will not detect the device unless one of the data lines is pulled high. For a Full-Speed USB device (which this is), you must add a resistor:

Connect a 1.5kΩ resistor between D+ (Pin 69) and 3.3V.
You can find a 3.3V pin on the Tang Nano headers.
Why? This resistor pulls the D+ line to 3.3V, signaling to your computer that a "Full Speed" USB device has been plugged in. Without it, nothing will happen.

3. How to Connect to Computer
Get a USB Breakout: The easiest way is to use a USB Type-A Male breakout board or cut a spare USB cable.
Wiring:
Connect the Green wire (D+) to Pin 69.
Connect the White wire (D-) to Pin 70.
Connect the Black wire (GND) to a GND pin on the FPGA.
Ignore the Red wire (5V) if you are powering the Tang Nano via its own USB-C port.
Resistor: Install the 1.5kΩ resistor between Pin 69 and a 3.3V pin.
4. How to Use
Once you have programmed the FPGA and made the connections:

Plug the new USB connection into your computer.
Your computer should detect a new "HID-compliant mouse".
Use the configured control pins to operate the mouse (simulated via buttons/wires on these pins):
Enable Movement: Pin 81 (High = Active)
Change Pattern: Pins 79 and 80 (Selects different movement shapes like circle, square, etc.)
If you see "Unknown USB Device" errors, try swapping D+ and D- (sometimes wire colors are non-standard), or ensure your 1.5kΩ resistor is correctly connected to 3.3V (not 5V).