module usb_descriptors (
    input  logic [15:0] requested_length,
    output logic [7:0]  data_out,
    input  logic [15:0] byte_index,
    input  logic [7:0]  descriptor_type,
    input  logic [7:0]  descriptor_index,
    output logic        valid
);

    // -------------------------------------------------------------------------
    // Descriptor Data
    // -------------------------------------------------------------------------

    // Device Descriptor
    localparam DEVICE_DESC_LEN = 18;
    logic [7:0] device_desc [0:DEVICE_DESC_LEN-1];
    
    initial begin
        device_desc[0]  = 8'h12; // bLength
        device_desc[1]  = 8'h01; // bDescriptorType (Device)
        device_desc[2]  = 8'h10; // bcdUSB (1.10) - Low byte
        device_desc[3]  = 8'h01; // bcdUSB (1.10) - High byte
        device_desc[4]  = 8'h00; // bDeviceClass
        device_desc[5]  = 8'h00; // bDeviceSubClass
        device_desc[6]  = 8'h00; // bDeviceProtocol
        device_desc[7]  = 8'h08; // bMaxPacketSize0 (8 bytes)
        device_desc[8]  = 8'hC0; // idVendor (0x16C0) - Low
        device_desc[9]  = 8'h16; // idVendor (0x16C0) - High
        device_desc[10] = 8'hDC; // idProduct (0x05DC) - Low
        device_desc[11] = 8'h05; // idProduct (0x05DC) - High
        device_desc[12] = 8'h00; // bcdDevice (1.00) - Low
        device_desc[13] = 8'h01; // bcdDevice (1.00) - High
        device_desc[14] = 8'h01; // iManufacturer
        device_desc[15] = 8'h02; // iProduct
        device_desc[16] = 8'h00; // iSerialNumber
        device_desc[17] = 8'h01; // bNumConfigurations
    end

    // Configuration Descriptor (Config + Interface + HID + Endpoint)
    localparam CONFIG_DESC_LEN = 9 + 9 + 9 + 7;
    logic [7:0] config_desc [0:CONFIG_DESC_LEN-1];

    initial begin
        // Configuration Descriptor
        config_desc[0] = 9;     // bLength
        config_desc[1] = 2;     // bDescriptorType (Configuration)
        config_desc[2] = CONFIG_DESC_LEN; // wTotalLength Low
        config_desc[3] = 0;     // wTotalLength High
        config_desc[4] = 1;     // bNumInterfaces
        config_desc[5] = 1;     // bConfigurationValue
        config_desc[6] = 0;     // iConfiguration
        config_desc[7] = 8'h80; // bmAttributes (Bus Powered)
        config_desc[8] = 50;    // bMaxPower (100mA)

        // Interface Descriptor
        config_desc[9]  = 9;    // bLength
        config_desc[10] = 4;    // bDescriptorType (Interface)
        config_desc[11] = 0;    // bInterfaceNumber
        config_desc[12] = 0;    // bAlternateSetting
        config_desc[13] = 1;    // bNumEndpoints
        config_desc[14] = 3;    // bInterfaceClass (HID)
        config_desc[15] = 1;    // bInterfaceSubClass (Boot Interface)
        config_desc[16] = 2;    // bInterfaceProtocol (Mouse)
        config_desc[17] = 0;    // iInterface

        // HID Descriptor
        config_desc[18] = 9;    // bLength
        config_desc[19] = 8'h21;// bDescriptorType (HID)
        config_desc[20] = 8'h10;// bcdHID (1.10) Low
        config_desc[21] = 8'h01;// bcdHID (1.10) High
        config_desc[22] = 0;    // bCountryCode
        config_desc[23] = 1;    // bNumDescriptors
        config_desc[24] = 8'h22;// bDescriptorType (Report)
        config_desc[25] = 50;   // wDescriptorLength Low (Report Desc Len)
        config_desc[26] = 0;    // wDescriptorLength High

        // Endpoint Descriptor
        config_desc[27] = 7;    // bLength
        config_desc[28] = 5;    // bDescriptorType (Endpoint)
        config_desc[29] = 8'h81;// bEndpointAddress (IN, EP1)
        config_desc[30] = 8'h03;// bmAttributes (Interrupt)
        config_desc[31] = 4;    // wMaxPacketSize Low (4 bytes)
        config_desc[32] = 0;    // wMaxPacketSize High
        config_desc[33] = 10;   // bInterval (10ms)
    end

    // HID Report Descriptor (Standard Mouse)
    localparam REPORT_DESC_LEN = 50;
    logic [7:0] report_desc [0:REPORT_DESC_LEN-1];

    initial begin
        report_desc[0]  = 8'h05; report_desc[1]  = 8'h01; // Usage Page (Generic Desktop)
        report_desc[2]  = 8'h09; report_desc[3]  = 8'h02; // Usage (Mouse)
        report_desc[4]  = 8'hA1; report_desc[5]  = 8'h01; // Collection (Application)
        report_desc[6]  = 8'h09; report_desc[7]  = 8'h01; //   Usage (Pointer)
        report_desc[8]  = 8'hA1; report_desc[9]  = 8'h00; //   Collection (Physical)
        report_desc[10] = 8'h05; report_desc[11] = 8'h09; //     Usage Page (Button)
        report_desc[12] = 8'h19; report_desc[13] = 8'h01; //     Usage Minimum (1)
        report_desc[14] = 8'h29; report_desc[15] = 8'h03; //     Usage Maximum (3)
        report_desc[16] = 8'h15; report_desc[17] = 8'h00; //     Logical Minimum (0)
        report_desc[18] = 8'h25; report_desc[19] = 8'h01; //     Logical Maximum (1)
        report_desc[20] = 8'h95; report_desc[21] = 8'h03; //     Report Count (3)
        report_desc[22] = 8'h75; report_desc[23] = 8'h01; //     Report Size (1)
        report_desc[24] = 8'h81; report_desc[25] = 8'h02; //     Input (Data,Var,Abs)
        report_desc[26] = 8'h95; report_desc[27] = 8'h01; //     Report Count (1)
        report_desc[28] = 8'h75; report_desc[29] = 8'h05; //     Report Size (5)
        report_desc[30] = 8'h81; report_desc[31] = 8'h03; //     Input (Cnst,Var,Abs)
        report_desc[32] = 8'h05; report_desc[33] = 8'h01; //     Usage Page (Generic Desktop)
        report_desc[34] = 8'h09; report_desc[35] = 8'h30; //     Usage (X)
        report_desc[36] = 8'h09; report_desc[37] = 8'h31; //     Usage (Y)
        report_desc[38] = 8'h09; report_desc[39] = 8'h38; //     Usage (Wheel)
        report_desc[40] = 8'h15; report_desc[41] = 8'h81; //     Logical Minimum (-127)
        report_desc[42] = 8'h25; report_desc[43] = 8'h7F; //     Logical Maximum (127)
        report_desc[44] = 8'h75; report_desc[45] = 8'h08; //     Report Size (8)
        report_desc[46] = 8'h95; report_desc[47] = 8'h03; //     Report Count (3)
        report_desc[48] = 8'h81; report_desc[49] = 8'h06; //     Input (Data,Var,Rel)
        // End Collection x2 is implicit or we can add it, but standard usually ends here or with C0
        // Wait, I missed the End Collections. 
        // Let's re-check the byte count.
        // The guide says ~250 lines, so it might be more verbose.
        // Standard mouse descriptor usually ends with 0xC0, 0xC0.
        // Let's add them and adjust length.
    end
    // Actually, let's fix the Report Descriptor to be correct.
    // 50 bytes was the estimate in my head but let's count.
    // 05 01, 09 02, A1 01, 09 01, A1 00 (10)
    // 05 09, 19 01, 29 03, 15 00, 25 01 (10)
    // 95 03, 75 01, 81 02 (6)
    // 95 01, 75 05, 81 03 (6)
    // 05 01, 09 30, 09 31, 09 38 (8)
    // 15 81, 25 7F, 75 08, 95 03, 81 06 (10)
    // C0, C0 (2)
    // Total: 10+10+6+6+8+10+2 = 52 bytes.
    
    localparam REPORT_DESC_LEN_REAL = 52;
    logic [7:0] report_desc_real [0:REPORT_DESC_LEN_REAL-1];
    
    initial begin
        report_desc_real[0]  = 8'h05; report_desc_real[1]  = 8'h01;
        report_desc_real[2]  = 8'h09; report_desc_real[3]  = 8'h02;
        report_desc_real[4]  = 8'hA1; report_desc_real[5]  = 8'h01;
        report_desc_real[6]  = 8'h09; report_desc_real[7]  = 8'h01;
        report_desc_real[8]  = 8'hA1; report_desc_real[9]  = 8'h00;
        report_desc_real[10] = 8'h05; report_desc_real[11] = 8'h09;
        report_desc_real[12] = 8'h19; report_desc_real[13] = 8'h01;
        report_desc_real[14] = 8'h29; report_desc_real[15] = 8'h03;
        report_desc_real[16] = 8'h15; report_desc_real[17] = 8'h00;
        report_desc_real[18] = 8'h25; report_desc_real[19] = 8'h01;
        report_desc_real[20] = 8'h95; report_desc_real[21] = 8'h03;
        report_desc_real[22] = 8'h75; report_desc_real[23] = 8'h01;
        report_desc_real[24] = 8'h81; report_desc_real[25] = 8'h02;
        report_desc_real[26] = 8'h95; report_desc_real[27] = 8'h01;
        report_desc_real[28] = 8'h75; report_desc_real[29] = 8'h05;
        report_desc_real[30] = 8'h81; report_desc_real[31] = 8'h03;
        report_desc_real[32] = 8'h05; report_desc_real[33] = 8'h01;
        report_desc_real[34] = 8'h09; report_desc_real[35] = 8'h30;
        report_desc_real[36] = 8'h09; report_desc_real[37] = 8'h31;
        report_desc_real[38] = 8'h09; report_desc_real[39] = 8'h38;
        report_desc_real[40] = 8'h15; report_desc_real[41] = 8'h81;
        report_desc_real[42] = 8'h25; report_desc_real[43] = 8'h7F;
        report_desc_real[44] = 8'h75; report_desc_real[45] = 8'h08;
        report_desc_real[46] = 8'h95; report_desc_real[47] = 8'h03;
        report_desc_real[48] = 8'h81; report_desc_real[49] = 8'h06;
        report_desc_real[50] = 8'hC0; report_desc_real[51] = 8'hC0;
    end

    // String Descriptors
    // String 0: LangID (0x0409 English US)
    localparam STR0_LEN = 4;
    logic [7:0] str0_desc [0:STR0_LEN-1] = '{4, 3, 9, 4};

    // String 1: Manufacturer "TangNano"
    localparam STR1_LEN = 18;
    logic [7:0] str1_desc [0:STR1_LEN-1] = '{
        18, 3, 
        "T", 0, "a", 0, "n", 0, "g", 0, "N", 0, "a", 0, "n", 0, "o", 0
    };

    // String 2: Product "FPGA Mouse"
    localparam STR2_LEN = 22;
    logic [7:0] str2_desc [0:STR2_LEN-1] = '{
        22, 3,
        "F", 0, "P", 0, "G", 0, "A", 0, " ", 0, "M", 0, "o", 0, "u", 0, "s", 0, "e", 0
    };

    // -------------------------------------------------------------------------
    // Read Logic
    // -------------------------------------------------------------------------

    always_comb begin
        valid = 1'b0;
        data_out = 8'h00;

        case (descriptor_type)
            8'h01: begin // Device
                if (byte_index < DEVICE_DESC_LEN && byte_index < requested_length) begin
                    data_out = device_desc[byte_index];
                    valid = 1'b1;
                end
            end
            
            8'h02: begin // Configuration
                if (byte_index < CONFIG_DESC_LEN && byte_index < requested_length) begin
                    data_out = config_desc[byte_index];
                    valid = 1'b1;
                end
            end

            8'h03: begin // String
                case (descriptor_index)
                    0: begin
                        if (byte_index < STR0_LEN && byte_index < requested_length) begin
                            data_out = str0_desc[byte_index];
                            valid = 1'b1;
                        end
                    end
                    1: begin
                        if (byte_index < STR1_LEN && byte_index < requested_length) begin
                            data_out = str1_desc[byte_index];
                            valid = 1'b1;
                        end
                    end
                    2: begin
                        if (byte_index < STR2_LEN && byte_index < requested_length) begin
                            data_out = str2_desc[byte_index];
                            valid = 1'b1;
                        end
                    end
                endcase
            end

            8'h22: begin // HID Report
                if (byte_index < REPORT_DESC_LEN_REAL && byte_index < requested_length) begin
                    data_out = report_desc_real[byte_index];
                    valid = 1'b1;
                end
            end
        endcase
    end

endmodule
