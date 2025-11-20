# USB Mouse HID Emulator - Complete Build Guide

## Prerequisites

### Hardware Required
- ✅ Tang Nano 20K FPGA board
- ✅ USB-C cable (for programming)
- ✅ Second USB cable (for mouse functionality)
- ✅ PC with USB ports

### Software Required
- **Gowin EDA** (Educational or Commercial Edition)
  - Download from: http://www.gowinsemi.com.cn/en/support/download_eda/
  - Version 1.9.8 or newer recommended
  - Includes: Designer, Programmer, and Analyzer
- **USB Drivers** (Windows)
  - Included with Gowin EDA installation

---

## Step 1: Install Gowin EDA

### Windows Installation
1. Download Gowin EDA from the official website
2. Run the installer (requires ~5GB disk space)
3. Install USB drivers when prompted
4. License options:
   - **Free license**: Request educational license online
   - **Trial**: 1-month full feature trial
   - **Purchase**: Commercial license

### Linux Installation
```bash
# Extract the archive
tar -xzf Gowin_EDA_X.X.X_linux.tar.gz

# Run installer
cd Gowin_EDA_X.X.X_linux
sudo ./setup.sh

# Add to PATH
echo 'export GOWIN_HOME=/opt/gowin' >> ~/.bashrc
echo 'export PATH=$PATH:$GOWIN_HOME/IDE/bin' >> ~/.bashrc
source ~/.bashrc
```

### Verify Installation
```bash
# Check version
gw_sh --version

# Test programmer
programmer_cli --help
```

---

## Step 2: Create Project Directory

Create and organize your project files:

```bash
usb_mouse_emulator/
├── rtl/
│   ├── usb_mouse_top.sv          # Top-level module
│   ├── usb_device_core.sv        # USB protocol core
│   ├── usb_packet.sv             # Packet handler
│   ├── usb_descriptors.sv        # Device descriptors
│   ├── hid_report_manager.sv     # HID report formatting
│   ├── pattern_generator.sv      # Movement patterns
│   └── clock_reset.sv            # Clock/reset logic
├── constraints/
│   └── tangnano20k.cst           # Pin assignments
├── tb/
│   ├── usb_mouse_tb.sv           # Testbench
│   └── usb_packet_tb.sv          # Packet testbench
└── doc/
    └── README.md
```

---

## Step 3: Create Project in Gowin IDE

### Launch Gowin IDE
1. Open **GOWIN FPGA Designer**
2. Click **File → New → FPGA Design Project**

### Configure Project Settings

**Project Setup:**
- **Project Name**: `usb_mouse_emulator`
- **Project Path**: Choose your directory
- **Default Encoding**: UTF-8

**Device Selection:**
- **Device**: GW2AR-18
- **Device Version**: C
- **Package**: QFN88
- **Part Number**: `GW2AR-LV18QN88C8/I7`
- **Speed**: C8

Click **OK** to create the project.

---

## Step 4: Add Source Files

### Add RTL Files

1. Right-click project in **Design** tab
2. Select **Add File...**
3. Navigate to `rtl/` directory
4. Add files **in this order** (important for dependencies):
   ```
   1. clock_reset.sv
   2. usb_descriptors.sv
   3. usb_packet.sv
   4. hid_report_manager.sv
   5. pattern_generator.sv
   6. usb_device_core.sv
   7. usb_mouse_top.sv (top-level)
   ```

5. Set file type to **SystemVerilog** if not auto-detected

### Set Top-Level Module

1. Right-click `usb_mouse_top.sv`
2. Select **Set as Top Module**
3. Verify the hierarchy icon appears next to the file

---

## Step 5: Create Constraints File

### Create Physical Constraints

1. Click **Tools → FloorPlanner** (or create manually)
2. Create new file: `constraints/tangnano20k.cst`
3. Add the following constraints:

```tcl
// Clock input (27 MHz oscillator)
IO_LOC "clk" 4;
IO_PORT "clk" PULL_MODE=NONE;

// Reset button
IO_LOC "rst_n" 88;
IO_PORT "rst_n" PULL_MODE=UP;

// USB Interface
IO_LOC "usb_dp" 69;
IO_LOC "usb_dn" 70;
IO_PORT "usb_dp" IO_TYPE=LVCMOS33;
IO_PORT "usb_dn" IO_TYPE=LVCMOS33;

// Pattern Control (Switches)
IO_LOC "pattern_select[0]" 15;  // S1
IO_LOC "pattern_select[1]" 16;  // S2
IO_LOC "pattern_enable" 17;      // S3
IO_PORT "pattern_select[0]" PULL_MODE=UP;
IO_PORT "pattern_select[1]" PULL_MODE=UP;
IO_PORT "pattern_enable" PULL_MODE=UP;

// Status LEDs (Active High)
IO_LOC "led[0]" 10;  // Heartbeat
IO_LOC "led[1]" 11;  // PLL locked
IO_LOC "led[2]" 13;  // USB configured
IO_LOC "led[3]" 14;  // Pattern enabled
IO_LOC "led[4]" 15;  // Report sent
IO_LOC "led[5]" 16;  // USB activity

IO_PORT "led[0]" IO_TYPE=LVCMOS33;
IO_PORT "led[1]" IO_TYPE=LVCMOS33;
IO_PORT "led[2]" IO_TYPE=LVCMOS33;
IO_PORT "led[3]" IO_TYPE=LVCMOS33;
IO_PORT "led[4]" IO_TYPE=LVCMOS33;
IO_PORT "led[5]" IO_TYPE=LVCMOS33;
```

4. In Gowin IDE: **Process → Add Constraint File**
5. Select your `.cst` file

---

## Step 6: Configure Synthesis Options

### Open Synthesis Settings
1. Double-click **Synthesize** in the Process window
2. Or right-click **Synthesize → Edit Options**

### Recommended Settings

**General:**
- **VHDL Version**: Not applicable (using SystemVerilog)
- **Verilog Version**: SystemVerilog-2012
- **Top Module**: usb_mouse_top (should auto-populate)

**Optimization:**
- **Optimization Goal**: Area (for smaller design) or Speed
- **Effort Level**: High
- **FSM Encoding**: Auto

**Advanced:**
- Enable: **Allow Undriven Nets**
- Enable: **Allow Dangling Nets** (for unused outputs)
- Disable: **Insert Buffer for CLKDIV** (if causing issues)

---

## Step 7: Run Synthesis

### Start Synthesis
1. Click **Process → Run Synthesis**
2. Or double-click **Synthesize** in Process window
3. Monitor progress in Console window

### Check for Errors
- **Green checkmark**: Success ✓
- **Red X**: Errors (fix syntax issues)
- **Yellow warning**: Warnings (usually safe to ignore)

### Review Reports
1. Expand **Synthesize** in Process tree
2. Open **RTL Viewer** to see design structure
3. Check **Resource Utilization**:
   - LUTs: Should be < 10,000 (plenty of room)
   - FFs: Should be < 8,000
   - BSRAM: Should be < 2Kb

---

## Step 8: Run Place & Route

### Configure Implementation
1. Right-click **Place & Route → Edit Options**

**Timing Settings:**
- **Effort Level**: High
- **Timing Driven**: Enabled
- **Allow Clock Domain Crossing**: Enabled (we have multiple domains)

**Advanced:**
- **Route Density**: Auto
- **Enable Multi-threading**: Enabled (faster on multi-core CPUs)

### Run Place & Route
1. Click **Process → Run Place & Route**
2. This takes 2-10 minutes depending on your PC
3. Monitor utilization and timing

### Verify Timing
1. Open **Timing Report**
2. Check for timing violations:
   - **Setup time**: Must be positive
   - **Hold time**: Must be positive
3. If violations exist, increase effort level or adjust constraints

---

## Step 9: Generate Bitstream

### Configure Bitstream Options
1. Right-click **Program Device → Edit Options**

**Programming Settings:**
- **Format**: Binary (.fs)
- **File name**: usb_mouse_emulator.fs
- **Security**: None (for testing)
- **Compression**: Enabled (smaller file)

### Generate Bitstream
1. Click **Process → Generate Bitstream**
2. Output file: `impl/pnr/usb_mouse_emulator.fs`
3. Verify file size: ~500KB - 1MB

---

## Step 10: Program the FPGA

### Connect Hardware
1. Connect Tang Nano 20K to PC via **programming USB port**
2. Power on the board
3. Verify connection: LED should light up

### Using Gowin Programmer

**GUI Method:**
1. Open **Gowin Programmer**
2. **Device** should auto-detect: GW2AR-18
3. If not detected:
   - Check USB cable
   - Install drivers (Windows)
   - Try different USB port

**Add Programming File:**
1. Right-click device → **Configure Device**
2. Click **Add** button
3. Select: `impl/pnr/usb_mouse_emulator.fs`
4. **Access Mode**: 
   - **SRAM**: Temporary (lost on power-off) - Good for testing
   - **Flash**: Permanent (survives power-off) - For final version

**Program Device:**
1. Click **Program/Configure** button
2. Wait for "Success" message
3. Takes 10-30 seconds

### Command Line Method (Alternative)
```bash
# Navigate to project directory
cd impl/pnr

# Program to SRAM (testing)
programmer_cli -d GW2AR-18 -c USB --fsFile usb_mouse_emulator.fs

# Program to Flash (permanent)
programmer_cli -d GW2AR-18 -c USB --fsFile usb_mouse_emulator.fs \
  --device-package QFN88 --erase --program
```

---

## Step 11: Initial Testing

### Check Status LEDs

After programming, observe the LEDs:

| LED | Expected | Meaning |
|-----|----------|---------|
| LED[0] | Blinking | Heartbeat - system running |
| LED[1] | ON solid | PLL locked - clocks working |
| LED[2] | OFF | USB not configured yet |
| LED[3] | OFF | Pattern disabled (S3 not pressed) |
| LED[4] | OFF | No reports sent yet |
| LED[5] | OFF | No USB activity |

**If LED[0] not blinking**: Clock or reset issue
**If LED[1] not ON**: PLL not locking - check constraints

---

## Step 12: Connect USB Mouse Function

### Hardware Connection
1. Keep programming cable connected (powers the board)
2. Connect **second USB cable** to the **USB-C connector** on board
3. This is the mouse data connection

### Operating System Detection

**Windows:**
1. "Device setup" notification should appear
2. "USB Input Device" or "HID-compliant mouse" installed
3. **LED[2] should turn ON** (USB enumerated)

**Linux:**
```bash
# Check if device detected
lsusb | grep "16c0:05dc"
# Should show: "Bus XXX Device XXX: ID 16c0:05dc Voti"

# View kernel messages
dmesg | tail -20
# Should show USB mouse connection

# Check input devices
ls /dev/input/by-id/ | grep -i mouse
```

**macOS:**
1. Open **System Information** (About This Mac → System Report)
2. Navigate to **Hardware → USB**
3. Look for device with VID 0x16C0, PID 0x05DC

---

## Step 13: Test Mouse Patterns

### Enable Pattern Generation

1. **Select Pattern** using switches S1 and S2:
   - S1=OFF, S2=OFF: Circle pattern
   - S1=ON, S2=OFF: Square pattern
   - S1=OFF, S2=ON: Figure-8 pattern
   - S1=ON, S2=ON: Random walk

2. **Enable Pattern**: Press switch S3
   - LED[3] should turn ON
   - LED[4] should blink (reports being sent)
   - LED[5] should blink (USB activity)

3. **Observe Mouse Cursor**:
   - Should move in selected pattern
   - Movement should be smooth
   - Pattern repeats continuously

### Test Each Pattern

**Circle Pattern:**
- Smooth circular motion
- Radius: ~200 pixels
- Period: ~10 seconds

**Square Pattern:**
- Rectangular motion with sharp corners
- 90-degree turns
- Side length: ~300 pixels

**Figure-8 Pattern:**
- Infinity symbol (∞) shape
- Smooth crossover in center
- Period: ~15 seconds

**Random Walk:**
- Unpredictable movements
- Changes direction randomly
- Stays within bounds

---

## Step 14: Advanced Verification

### Windows Device Manager
1. Open **Device Manager**
2. Expand **Human Interface Devices**
3. Find your mouse device
4. Right-click → **Properties**
5. **Details** tab → **Hardware IDs**:
   ```
   USB\VID_16C0&PID_05DC&REV_0100
   USB\VID_16C0&PID_05DC
   ```

### Linux USB Monitoring
```bash
# Monitor USB traffic
sudo usbmon -i <bus_number>

# View HID reports (raw data)
sudo cat /dev/hidraw0 | hexdump -C

# Test with evtest
sudo evtest /dev/input/by-id/*FPGA*mouse*
# Move mouse and see events
```

### USB Analyzer (Professional)
If you have a USB analyzer (Total Phase, Saleae):
1. Connect inline between FPGA and PC
2. Capture enumeration sequence
3. Verify descriptor contents
4. Check report timing (should be 100 Hz)

---

## Troubleshooting Guide

### Issue: Device Not Detected

**Symptoms:** 
- LED[2] stays OFF
- No device in device manager
- `lsusb` doesn't show device

**Solutions:**
1. **Check D+ pullup resistor**
   - Must have 1.5kΩ from D+ to 3.3V
   - Tang Nano 20K may need external resistor
   
2. **Verify USB pins**
   - Check constraints file pins match board
   - Use multimeter to verify D+/D- connections
   
3. **Check PLL lock**
   - LED[1] must be ON
   - 48 MHz clock is required for USB

4. **Try different USB port**
   - Some ports have better signal quality
   - Avoid USB hubs initially

### Issue: Mouse Detected But Not Moving

**Symptoms:**
- LED[2] is ON (enumerated)
- Pattern enabled (LED[3] ON)
- Cursor doesn't move

**Solutions:**
1. **Check LED[4]** - Should blink when reports sent
   - If not blinking: Report generation issue
   
2. **Verify pattern_enable** signal
   - Press S3 firmly
   - Check switch connection
   
3. **Test with different pattern**
   - Try all 4 patterns using S1/S2

4. **Check OS mouse settings**
   - Windows: Disable "Enhanced pointer precision"
   - Linux: Check xinput settings
   - May need to adjust mouse sensitivity

### Issue: Erratic Movement

**Symptoms:**
- Cursor jumps randomly
- Pattern not smooth
- USB disconnects/reconnects

**Solutions:**
1. **Check clock stability**
   - Verify 48 MHz PLL is stable
   - Try lower optimization level
   
2. **Signal integrity**
   - Use short, quality USB cable
   - Check for EMI sources nearby
   
3. **Timing violations**
   - Review timing report
   - Increase effort level in P&R

### Issue: Compilation Errors

**Common errors and fixes:**

```
Error: Cannot find module 'rPLL'
Fix: Ensure using GW2AR-18 device, check Gowin version

Error: Syntax error in SystemVerilog
Fix: Verify Verilog version set to SV-2012

Error: Pin XX does not exist
Fix: Verify constraints match Tang Nano 20K pinout

Warning: Timing violation on path...
Fix: Increase clock constraint, or reduce clock frequency
```

---

## Optional Enhancements

### 1. Persist Configuration to Flash

For permanent installation:
```bash
programmer_cli -d GW2AR-18 -c USB \
  --fsFile usb_mouse_emulator.fs \
  --erase --program --verify
```

### 2. Add UART Debug Output

Connect UART (115200 baud) to see debug messages:
- USB state machine status
- Report contents
- Error conditions

### 3. Modify Patterns

Edit `rtl/pattern_generator.sv` to create custom patterns:
```systemverilog
2'd3: begin // Custom spiral pattern
    mouse_x <= (amplitude * cos_value) >> shift_factor;
    mouse_y <= (amplitude * sin_value * time_factor) >> shift_factor;
end
```

### 4. Add Button Inputs

Connect physical buttons to send mouse clicks:
- Modify `hid_report_manager.sv`
- Add button inputs to top-level module
- Update constraints file

---

## Next Steps

✅ **Project built successfully!**

**Learn More:**
- Study USB packet capture to understand protocol
- Experiment with different report rates
- Try implementing USB keyboard
- Add composite device (mouse + keyboard)

**Resources:**
- USB 2.0 Specification: https://www.usb.org/
- HID Usage Tables: https://usb.org/hid
- Tang Nano Wiki: https://wiki.sipeed.com/

---

## Summary Checklist

- [ ] Gowin EDA installed and licensed
- [ ] Project created with correct device
- [ ] All RTL files added to project
- [ ] Constraints file configured
- [ ] Synthesis completed without errors
- [ ] Place & Route finished, timing met
- [ ] Bitstream generated successfully
- [ ] FPGA programmed via USB
- [ ] LED[0] blinking (heartbeat)
- [ ] LED[1] ON (PLL locked)
- [ ] USB cable connected to mouse port
- [ ] Device enumerated (LED[2] ON)
- [ ] Pattern enabled (S3 pressed, LED[3] ON)
- [ ] Mouse cursor moving in pattern
- [ ] All 4 patterns tested and working

**Congratulations! Your USB mouse is now working!** 🎉

