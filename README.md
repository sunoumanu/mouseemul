# USB Mouse HID Emulator - Complete File List

## RTL Source Files (SystemVerilog)

### 1. **usb_mouse_top.sv** (Top-Level Module)
- **Purpose**: Top-level integration, connects all modules
- **Key Features**:
  - Instantiates all sub-modules
  - Manages USB bidirectional pins
  - Provides LED status indicators
  - Heartbeat generator
- **Lines**: ~180

### 2. **clock_reset.sv** (Clock & Reset Management)
- **Purpose**: Generate 48 MHz clock from 27 MHz input
- **Key Features**:
  - Gowin rPLL primitive configuration
  - 2-stage reset synchronizer
  - Reset holdoff after PLL lock
- **Lines**: ~110

### 3. **pattern_generator.sv** (Movement Pattern Generator)
- **Purpose**: Generate automatic mouse movement patterns
- **Key Features**:
  - 4 patterns: Circle, Square, Figure-8, Random
  - Configurable report rate (default 100 Hz)
  - Sine/cosine approximation
  - LFSR for random pattern
- **Lines**: ~200

### 4. **hid_report_manager.sv** (HID Report Formatter)
- **Purpose**: Format mouse data into HID reports
- **Key Features**:
  - 4-byte HID report format
  - State machine for report generation
  - Handshake with USB core
- **Lines**: ~80

### 5. **usb_descriptors.sv** (USB/HID Descriptors)
- **Purpose**: Store USB device and HID descriptors
- **Key Features**:
  - Device descriptor (VID: 0x16C0, PID: 0x05DC)
  - Configuration descriptor
  - HID report descriptor (boot protocol mouse)
  - String descriptors (Manufacturer, Product)
- **Lines**: ~250

### 6. **usb_packet.sv** (USB Packet Handler)
- **Purpose**: Low-level USB packet encoding/decoding
- **Key Features**:
  - NRZI encoder/decoder
  - Bit stuffing/unstuffing
  - USB timing (12 Mbps from 48 MHz clock)
  - Packet assembly and CRC
  - Line state detection (J, K, SE0)
- **Lines**: ~320

### 7. **usb_device_core.sv** (USB Protocol Handler)
- **Purpose**: USB device enumeration and protocol
- **Key Features**:
  - USB state machine (Default, Address, Configured)
  - Token packet handling (SETUP, IN, OUT, SOF)
  - Control transfer processing
  - Standard request handling:
    - GET_DESCRIPTOR
    - SET_ADDRESS
    - SET_CONFIGURATION
    - SET_IDLE (HID)
  - Endpoint management (EP0 control, EP1 interrupt)
  - DATA0/DATA1 toggle
- **Lines**: ~400

## Constraints File

### 8. **tangnano20k.cst** (Pin Assignments)
- **Purpose**: Map signals to FPGA pins
- **Assignments**:
  - Clock input: Pin 4
  - Reset: Pin 88
  - USB D+/D-: Pins 69/70
  - Switches: Pins 15-17
  - LEDs: Pins 10, 11, 13-16
- **Lines**: ~50

## Testbench Files

### 9. **usb_mouse_tb.sv** (Simulation Testbench)
- **Purpose**: Verify pattern generator and HID manager
- **Features**:
  - Tests all 4 patterns
  - Monitors HID reports
  - Waveform generation (.vcd)
  - Report formatting validation
- **Lines**: ~200

## File Organization

```
usb_mouse_emulator/
├── rtl/
│   ├── usb_mouse_top.sv          ← Start here
│   ├── clock_reset.sv
│   ├── pattern_generator.sv
│   ├── hid_report_manager.sv
│   ├── usb_descriptors.sv
│   ├── usb_packet.sv
│   └── usb_device_core.sv
├── constraints/
│   └── tangnano20k.cst
├── tb/
│   └── usb_mouse_tb.sv
└── doc/
    └── README.md
```

## Module Hierarchy

```
usb_mouse_top
├── clock_reset
│   └── rPLL (Gowin primitive)
├── pattern_generator
├── hid_report_manager
├── usb_device_core
│   ├── usb_packet
│   └── usb_descriptors
```

## Resource Estimates

| Resource | Estimated Usage | Available (GW2AR-18) | Utilization |
|----------|-----------------|----------------------|-------------|
| LUTs     | ~2000           | 20,736               | ~10%        |
| FFs      | ~1500           | 15,552               | ~10%        |
| BSRAM    | ~2 Kb           | 828 Kb               | <1%         |
| PLLs     | 1               | 2                    | 50%         |

## Build Order

**Add files to Gowin IDE in this order:**

1. ✅ `clock_reset.sv` - No dependencies
2. ✅ `usb_descriptors.sv` - No dependencies
3. ✅ `usb_packet.sv` - No dependencies
4. ✅ `hid_report_manager.sv` - No dependencies
5. ✅ `pattern_generator.sv` - No dependencies
6. ✅ `usb_device_core.sv` - Uses usb_packet, usb_descriptors
7. ✅ `usb_mouse_top.sv` - Uses all modules (SET AS TOP)
8. ✅ `tangnano20k.cst` - Constraints

## Simulation Instructions

```bash
# Using Icarus Verilog
iverilog -g2012 -s usb_mouse_tb \
  rtl/pattern_generator.sv \
  rtl/hid_report_manager.sv \
  tb/usb_mouse_tb.sv \
  -o usb_mouse_tb.vvp

# Run simulation
vvp usb_mouse_tb.vvp

# View waveforms
gtkwave usb_mouse_tb.vcd
```

## Key Parameters (Customizable)

### In `pattern_generator.sv`:
```systemverilog
parameter CLOCK_FREQ = 48_000_000  // Must match PLL output
parameter REPORT_RATE = 100        // Reports per second (1-1000)
```

### In `clock_reset.sv`:
```systemverilog
.FCLKIN("27")      // Input clock: 27 MHz
.IDIV_SEL(8)       // Divider: 27/9 = 3 MHz
.FBDIV_SEL(15)     // Multiplier: 3*16 = 48 MHz
.ODIV_SEL(8)       // Output divider: 48/1 = 48 MHz
```

## USB Device Information

- **Vendor ID**: 0x16C0 (Voti - Free for prototyping)
- **Product ID**: 0x05DC
- **Device Class**: HID (0x03)
- **Subclass**: Boot Interface (0x01)
- **Protocol**: Mouse (0x02)
- **Max Power**: 100 mA
- **USB Version**: 1.1 Full-Speed (12 Mbps)

## HID Report Format

| Byte | Bits  | Description          | Range        |
|------|-------|----------------------|--------------|
| 0    | [0]   | Left Button          | 0 or 1       |
| 0    | [1]   | Right Button         | 0 or 1       |
| 0    | [2]   | Middle Button        | 0 or 1       |
| 0    | [7:3] | Reserved             | 0            |
| 1    | [7:0] | X Movement           | -127 to +127 |
| 2    | [7:0] | Y Movement           | -127 to +127 |
| 3    | [7:0] | Wheel Movement       | -127 to +127 |

## Typical Issues & Solutions

### Issue: PLL not locking
- **Check**: Input clock is 27 MHz
- **Fix**: Verify pin 4 constraint and clock source

### Issue: USB not enumerating
- **Check**: LED[1] (PLL locked), LED[0] (heartbeat)
- **Fix**: Verify USB D+/D- pins, check 1.5kΩ pullup on D+

### Issue: Pattern not moving
- **Check**: LED[2] (USB configured), LED[3] (pattern enabled)
- **Fix**: Press S3 switch, verify USB enumeration first

### Issue: Compilation errors
- **Check**: Gowin EDA version (>= 1.9.8)
- **Fix**: Ensure SystemVerilog-2012 language mode enabled

## Next Steps After Build

1. ✅ Verify LEDs (heartbeat, PLL lock)
2. ✅ Connect USB cable for mouse function
3. ✅ Check device enumeration (LED[2] on)
4. ✅ Enable pattern (press S3, LED[3] on)
5. ✅ Test all 4 patterns (S1/S2 switches)
6. ✅ Monitor with Device Manager (Windows) or lsusb (Linux)

## Total Project Statistics

- **Total RTL Lines**: ~1,740
- **Total Files**: 9
- **Build Time**: 5-10 minutes (synthesis + P&R)
- **Programming Time**: 30 seconds
- **Total Development Effort**: ~40 hours (reference)
