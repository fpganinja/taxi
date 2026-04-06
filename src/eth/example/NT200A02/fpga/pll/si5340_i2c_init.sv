// SPDX-License-Identifier: CERN-OHL-S-2.0
/*

Copyright (c) 2015-2026 FPGA Ninja, LLC

Authors:
- Alex Forencich

*/

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * si5340_i2c_init
 */
module si5340_i2c_init #
(
    parameter logic SIM_SPEEDUP = 1'b0
)
(
    input  wire logic  clk,
    input  wire logic  rst,

    /*
     * I2C master interface
     */
    taxi_axis_if.src   m_axis_cmd,
    taxi_axis_if.src   m_axis_tx,

    /*
     * Status
     */
    output wire logic  busy,

    /*
     * Configuration
     */
    input  wire logic  start
);

/*

Generic module for I2C bus initialization.  Good for use when multiple devices
on an I2C bus must be initialized on system start without intervention of a
general-purpose processor.

Copy this file and change init_data and INIT_DATA_LEN as needed.

This module can be used in two modes: simple device initialization, or multiple
device initialization.  In multiple device mode, the same initialization sequence
can be performed on multiple different device addresses.

To use single device mode, only use the start write to address and write data commands.
The module will generate the I2C commands in sequential order.  Terminate the list
with a 0 entry.

To use the multiple device mode, use the start data and start address block commands
to set up lists of initialization data and device addresses.  The module enters
multiple device mode upon seeing a start data block command.  The module stores the
offset of the start of the data block and then skips ahead until it reaches a start
address block command.  The module will store the offset to the address block and
read the first address in the block.  Then it will jump back to the data block
and execute it, substituting the stored address for each current address write
command.  Upon reaching the start address block command, the module will read out the
next address and start again at the top of the data block.  If the module encounters
a start data block command while looking for an address, then it will store a new data
offset and then look for a start address block command.  Terminate the list with a 0
entry.  Normal address commands will operate normally inside a data block.

Commands:

00 0000000 : stop
00 0000001 : exit multiple device mode
00 0000011 : start write to current address
00 0001000 : start address block
00 0001001 : start data block
00 001dddd : delay 2**(16+d) cycles
00 1000001 : send I2C stop
01 aaaaaaa : start write to address
1 dddddddd : write 8-bit data

Examples

write 0x11223344 to register 0x0004 on device at 0x50

01 1010000  start write to 0x50
1 00000000  write address 0x0004
1 00000100
1 00010001  write data 0x11223344
1 00100010
1 00110011
1 01000100
0 00000000  stop

write 0x11223344 to register 0x0004 on devices at 0x50, 0x51, 0x52, and 0x53

00 0001001  start data block
00 0000011  start write to current address
1 00000000  write address 0x0004
1 00000100
1 00010001  write data 0x11223344
1 00100010
1 00110011
1 01000100
00 0001000  start address block
01 1010000  address 0x50
01 1010001  address 0x51
01 1010010  address 0x52
01 1010011  address 0x53
00 0000001  exit multi-dev mode
00 0000000  stop

*/

// check configuration
if (m_axis_cmd.DATA_W < 12)
    $fatal(0, "Command interface width must be at least 12 bits (instance %m)");

if (m_axis_tx.DATA_W != 8)
    $fatal(0, "Data interface width must be 8 bits (instance %m)");

function [8:0] cmd_start(input [6:0] addr);
    cmd_start = {2'b01, addr};
endfunction

function [8:0] cmd_wr(input [7:0] data);
    cmd_wr = {1'b1, data};
endfunction

function [8:0] cmd_stop();
    cmd_stop = {2'b00, 7'b1000001};
endfunction

function [8:0] cmd_delay(input [3:0] d);
    cmd_delay = {2'b00, 3'b001, d};
endfunction

function [8:0] cmd_halt();
    cmd_halt = 9'd0;
endfunction

function [8:0] blk_start_data();
    blk_start_data = {2'b00, 7'b0001001};
endfunction

function [8:0] blk_start_addr();
    blk_start_addr = {2'b00, 7'b0001000};
endfunction

function [8:0] cmd_start_cur();
    cmd_start_cur = {2'b00, 7'b0000011};
endfunction

function [8:0] cmd_exit();
    cmd_exit = {2'b00, 7'b0000001};
endfunction

// init_data ROM
localparam INIT_DATA_LEN = 461;

reg [8:0] init_data [INIT_DATA_LEN-1:0];

initial begin
    // Initial delay
    init_data[0] = cmd_delay(6); // delay 30 ms
    // Si534x/7x/8x/9x Registers Script
    // 
    // Part: Si5340
    // Project File: X:\Projects\taxi-corundum\src\eth\example\NT200A02\fpga\pll\Si5340-RevD-NT200-Project.slabtimeproj
    // Design ID: NT200
    // Includes Pre/Post Download Control Register Writes: Yes
    // Die Revision: B1
    // Creator: ClockBuilder Pro v4.1 [2021-09-22]
    // Created On: 2026-04-04 21:47:23 GMT-07:00
    // 
    // Start configuration preamble
    init_data[1] = cmd_start(7'h74);
    init_data[2] = cmd_wr(8'h01);
    init_data[3] = cmd_wr(8'h0b); // set page 0x0b
    init_data[4] = cmd_start(7'h74);
    init_data[5] = cmd_wr(8'h24);
    init_data[6] = cmd_wr(8'hc0); // write 0xc0 to 0x0b24
    init_data[7] = cmd_wr(8'h00); // write 0x00 to 0x0b25
    // Rev D stuck divider fix
    init_data[8] = cmd_start(7'h74);
    init_data[9] = cmd_wr(8'h01);
    init_data[10] = cmd_wr(8'h05); // set page 0x05
    init_data[11] = cmd_start(7'h74);
    init_data[12] = cmd_wr(8'h02);
    init_data[13] = cmd_wr(8'h01); // write 0x01 to 0x0502
    init_data[14] = cmd_start(7'h74);
    init_data[15] = cmd_wr(8'h05);
    init_data[16] = cmd_wr(8'h03); // write 0x03 to 0x0505
    init_data[17] = cmd_start(7'h74);
    init_data[18] = cmd_wr(8'h01);
    init_data[19] = cmd_wr(8'h09); // set page 0x09
    init_data[20] = cmd_start(7'h74);
    init_data[21] = cmd_wr(8'h57);
    init_data[22] = cmd_wr(8'h17); // write 0x17 to 0x0957
    init_data[23] = cmd_start(7'h74);
    init_data[24] = cmd_wr(8'h01);
    init_data[25] = cmd_wr(8'h0b); // set page 0x0b
    init_data[26] = cmd_start(7'h74);
    init_data[27] = cmd_wr(8'h4e);
    init_data[28] = cmd_wr(8'h1a); // write 0x1a to 0x0b4e
    // End configuration preamble
    // 
    // Delay 300 msec
    init_data[29] = cmd_delay(10); // delay 300 ms
    // Delay is worst case time for device to complete any calibration
    // that is running due to device state change previous to this script
    // being processed.
    // 
    // Start configuration registers
    init_data[30] = cmd_start(7'h74);
    init_data[31] = cmd_wr(8'h01);
    init_data[32] = cmd_wr(8'h00); // set page 0x00
    init_data[33] = cmd_start(7'h74);
    init_data[34] = cmd_wr(8'h06);
    init_data[35] = cmd_wr(8'h00); // write 0x00 to 0x0006
    init_data[36] = cmd_wr(8'h00); // write 0x00 to 0x0007
    init_data[37] = cmd_wr(8'h00); // write 0x00 to 0x0008
    init_data[38] = cmd_start(7'h74);
    init_data[39] = cmd_wr(8'h0b);
    init_data[40] = cmd_wr(8'h74); // write 0x74 to 0x000b
    init_data[41] = cmd_start(7'h74);
    init_data[42] = cmd_wr(8'h17);
    init_data[43] = cmd_wr(8'hd0); // write 0xd0 to 0x0017
    init_data[44] = cmd_wr(8'hff); // write 0xff to 0x0018
    init_data[45] = cmd_start(7'h74);
    init_data[46] = cmd_wr(8'h21);
    init_data[47] = cmd_wr(8'h0f); // write 0x0f to 0x0021
    init_data[48] = cmd_wr(8'h00); // write 0x00 to 0x0022
    init_data[49] = cmd_start(7'h74);
    init_data[50] = cmd_wr(8'h2b);
    init_data[51] = cmd_wr(8'h02); // write 0x02 to 0x002b
    init_data[52] = cmd_wr(8'h20); // write 0x20 to 0x002c
    init_data[53] = cmd_wr(8'h00); // write 0x00 to 0x002d
    init_data[54] = cmd_wr(8'h00); // write 0x00 to 0x002e
    init_data[55] = cmd_wr(8'h00); // write 0x00 to 0x002f
    init_data[56] = cmd_wr(8'h00); // write 0x00 to 0x0030
    init_data[57] = cmd_wr(8'h00); // write 0x00 to 0x0031
    init_data[58] = cmd_wr(8'h00); // write 0x00 to 0x0032
    init_data[59] = cmd_wr(8'h00); // write 0x00 to 0x0033
    init_data[60] = cmd_wr(8'h00); // write 0x00 to 0x0034
    init_data[61] = cmd_wr(8'h00); // write 0x00 to 0x0035
    init_data[62] = cmd_wr(8'h00); // write 0x00 to 0x0036
    init_data[63] = cmd_wr(8'h00); // write 0x00 to 0x0037
    init_data[64] = cmd_wr(8'h00); // write 0x00 to 0x0038
    init_data[65] = cmd_wr(8'h00); // write 0x00 to 0x0039
    init_data[66] = cmd_wr(8'h00); // write 0x00 to 0x003a
    init_data[67] = cmd_wr(8'h00); // write 0x00 to 0x003b
    init_data[68] = cmd_wr(8'h00); // write 0x00 to 0x003c
    init_data[69] = cmd_wr(8'h00); // write 0x00 to 0x003d
    init_data[70] = cmd_start(7'h74);
    init_data[71] = cmd_wr(8'h41);
    init_data[72] = cmd_wr(8'h00); // write 0x00 to 0x0041
    init_data[73] = cmd_wr(8'h00); // write 0x00 to 0x0042
    init_data[74] = cmd_wr(8'h00); // write 0x00 to 0x0043
    init_data[75] = cmd_wr(8'h00); // write 0x00 to 0x0044
    init_data[76] = cmd_start(7'h74);
    init_data[77] = cmd_wr(8'h9e);
    init_data[78] = cmd_wr(8'h00); // write 0x00 to 0x009e
    init_data[79] = cmd_start(7'h74);
    init_data[80] = cmd_wr(8'h01);
    init_data[81] = cmd_wr(8'h01); // set page 0x01
    init_data[82] = cmd_start(7'h74);
    init_data[83] = cmd_wr(8'h02);
    init_data[84] = cmd_wr(8'h01); // write 0x01 to 0x0102
    init_data[85] = cmd_start(7'h74);
    init_data[86] = cmd_wr(8'h12);
    init_data[87] = cmd_wr(8'h06); // write 0x06 to 0x0112
    init_data[88] = cmd_wr(8'h09); // write 0x09 to 0x0113
    init_data[89] = cmd_wr(8'h3b); // write 0x3b to 0x0114
    init_data[90] = cmd_wr(8'h28); // write 0x28 to 0x0115
    init_data[91] = cmd_start(7'h74);
    init_data[92] = cmd_wr(8'h17);
    init_data[93] = cmd_wr(8'h06); // write 0x06 to 0x0117
    init_data[94] = cmd_wr(8'h09); // write 0x09 to 0x0118
    init_data[95] = cmd_wr(8'h3b); // write 0x3b to 0x0119
    init_data[96] = cmd_wr(8'h29); // write 0x29 to 0x011a
    init_data[97] = cmd_start(7'h74);
    init_data[98] = cmd_wr(8'h26);
    init_data[99] = cmd_wr(8'h06); // write 0x06 to 0x0126
    init_data[100] = cmd_wr(8'h09); // write 0x09 to 0x0127
    init_data[101] = cmd_wr(8'h3b); // write 0x3b to 0x0128
    init_data[102] = cmd_wr(8'h29); // write 0x29 to 0x0129
    init_data[103] = cmd_start(7'h74);
    init_data[104] = cmd_wr(8'h2b);
    init_data[105] = cmd_wr(8'h06); // write 0x06 to 0x012b
    init_data[106] = cmd_wr(8'h09); // write 0x09 to 0x012c
    init_data[107] = cmd_wr(8'h3b); // write 0x3b to 0x012d
    init_data[108] = cmd_wr(8'h29); // write 0x29 to 0x012e
    init_data[109] = cmd_start(7'h74);
    init_data[110] = cmd_wr(8'h3f);
    init_data[111] = cmd_wr(8'h00); // write 0x00 to 0x013f
    init_data[112] = cmd_wr(8'h00); // write 0x00 to 0x0140
    init_data[113] = cmd_wr(8'h40); // write 0x40 to 0x0141
    init_data[114] = cmd_start(7'h74);
    init_data[115] = cmd_wr(8'h01);
    init_data[116] = cmd_wr(8'h02); // set page 0x02
    init_data[117] = cmd_start(7'h74);
    init_data[118] = cmd_wr(8'h06);
    init_data[119] = cmd_wr(8'h00); // write 0x00 to 0x0206
    init_data[120] = cmd_start(7'h74);
    init_data[121] = cmd_wr(8'h08);
    init_data[122] = cmd_wr(8'h00); // write 0x00 to 0x0208
    init_data[123] = cmd_wr(8'h00); // write 0x00 to 0x0209
    init_data[124] = cmd_wr(8'h00); // write 0x00 to 0x020a
    init_data[125] = cmd_wr(8'h00); // write 0x00 to 0x020b
    init_data[126] = cmd_wr(8'h00); // write 0x00 to 0x020c
    init_data[127] = cmd_wr(8'h00); // write 0x00 to 0x020d
    init_data[128] = cmd_wr(8'h00); // write 0x00 to 0x020e
    init_data[129] = cmd_wr(8'h00); // write 0x00 to 0x020f
    init_data[130] = cmd_wr(8'h00); // write 0x00 to 0x0210
    init_data[131] = cmd_wr(8'h00); // write 0x00 to 0x0211
    init_data[132] = cmd_wr(8'h00); // write 0x00 to 0x0212
    init_data[133] = cmd_wr(8'h00); // write 0x00 to 0x0213
    init_data[134] = cmd_wr(8'h00); // write 0x00 to 0x0214
    init_data[135] = cmd_wr(8'h00); // write 0x00 to 0x0215
    init_data[136] = cmd_wr(8'h00); // write 0x00 to 0x0216
    init_data[137] = cmd_wr(8'h00); // write 0x00 to 0x0217
    init_data[138] = cmd_wr(8'h00); // write 0x00 to 0x0218
    init_data[139] = cmd_wr(8'h00); // write 0x00 to 0x0219
    init_data[140] = cmd_wr(8'h00); // write 0x00 to 0x021a
    init_data[141] = cmd_wr(8'h00); // write 0x00 to 0x021b
    init_data[142] = cmd_wr(8'h00); // write 0x00 to 0x021c
    init_data[143] = cmd_wr(8'h00); // write 0x00 to 0x021d
    init_data[144] = cmd_wr(8'h00); // write 0x00 to 0x021e
    init_data[145] = cmd_wr(8'h00); // write 0x00 to 0x021f
    init_data[146] = cmd_wr(8'h00); // write 0x00 to 0x0220
    init_data[147] = cmd_wr(8'h00); // write 0x00 to 0x0221
    init_data[148] = cmd_wr(8'h00); // write 0x00 to 0x0222
    init_data[149] = cmd_wr(8'h00); // write 0x00 to 0x0223
    init_data[150] = cmd_wr(8'h00); // write 0x00 to 0x0224
    init_data[151] = cmd_wr(8'h00); // write 0x00 to 0x0225
    init_data[152] = cmd_wr(8'h00); // write 0x00 to 0x0226
    init_data[153] = cmd_wr(8'h00); // write 0x00 to 0x0227
    init_data[154] = cmd_wr(8'h00); // write 0x00 to 0x0228
    init_data[155] = cmd_wr(8'h00); // write 0x00 to 0x0229
    init_data[156] = cmd_wr(8'h00); // write 0x00 to 0x022a
    init_data[157] = cmd_wr(8'h00); // write 0x00 to 0x022b
    init_data[158] = cmd_wr(8'h00); // write 0x00 to 0x022c
    init_data[159] = cmd_wr(8'h00); // write 0x00 to 0x022d
    init_data[160] = cmd_wr(8'h00); // write 0x00 to 0x022e
    init_data[161] = cmd_wr(8'h00); // write 0x00 to 0x022f
    init_data[162] = cmd_start(7'h74);
    init_data[163] = cmd_wr(8'h35);
    init_data[164] = cmd_wr(8'ha0); // write 0xa0 to 0x0235
    init_data[165] = cmd_wr(8'h2a); // write 0x2a to 0x0236
    init_data[166] = cmd_wr(8'hcd); // write 0xcd to 0x0237
    init_data[167] = cmd_wr(8'hd8); // write 0xd8 to 0x0238
    init_data[168] = cmd_wr(8'had); // write 0xad to 0x0239
    init_data[169] = cmd_wr(8'h00); // write 0x00 to 0x023a
    init_data[170] = cmd_wr(8'h00); // write 0x00 to 0x023b
    init_data[171] = cmd_wr(8'h80); // write 0x80 to 0x023c
    init_data[172] = cmd_wr(8'h96); // write 0x96 to 0x023d
    init_data[173] = cmd_wr(8'h98); // write 0x98 to 0x023e
    init_data[174] = cmd_start(7'h74);
    init_data[175] = cmd_wr(8'h50);
    init_data[176] = cmd_wr(8'h00); // write 0x00 to 0x0250
    init_data[177] = cmd_wr(8'h00); // write 0x00 to 0x0251
    init_data[178] = cmd_wr(8'h00); // write 0x00 to 0x0252
    init_data[179] = cmd_wr(8'h00); // write 0x00 to 0x0253
    init_data[180] = cmd_wr(8'h00); // write 0x00 to 0x0254
    init_data[181] = cmd_wr(8'h00); // write 0x00 to 0x0255
    init_data[182] = cmd_start(7'h74);
    init_data[183] = cmd_wr(8'h5c);
    init_data[184] = cmd_wr(8'h00); // write 0x00 to 0x025c
    init_data[185] = cmd_wr(8'h00); // write 0x00 to 0x025d
    init_data[186] = cmd_wr(8'h00); // write 0x00 to 0x025e
    init_data[187] = cmd_wr(8'h00); // write 0x00 to 0x025f
    init_data[188] = cmd_wr(8'h00); // write 0x00 to 0x0260
    init_data[189] = cmd_wr(8'h00); // write 0x00 to 0x0261
    init_data[190] = cmd_start(7'h74);
    init_data[191] = cmd_wr(8'h6b);
    init_data[192] = cmd_wr(8'h4e); // write 0x4e to 0x026b
    init_data[193] = cmd_wr(8'h54); // write 0x54 to 0x026c
    init_data[194] = cmd_wr(8'h32); // write 0x32 to 0x026d
    init_data[195] = cmd_wr(8'h30); // write 0x30 to 0x026e
    init_data[196] = cmd_wr(8'h30); // write 0x30 to 0x026f
    init_data[197] = cmd_wr(8'h00); // write 0x00 to 0x0270
    init_data[198] = cmd_wr(8'h00); // write 0x00 to 0x0271
    init_data[199] = cmd_wr(8'h00); // write 0x00 to 0x0272
    init_data[200] = cmd_start(7'h74);
    init_data[201] = cmd_wr(8'h01);
    init_data[202] = cmd_wr(8'h03); // set page 0x03
    init_data[203] = cmd_start(7'h74);
    init_data[204] = cmd_wr(8'h02);
    init_data[205] = cmd_wr(8'h00); // write 0x00 to 0x0302
    init_data[206] = cmd_wr(8'h00); // write 0x00 to 0x0303
    init_data[207] = cmd_wr(8'h00); // write 0x00 to 0x0304
    init_data[208] = cmd_wr(8'h00); // write 0x00 to 0x0305
    init_data[209] = cmd_wr(8'h0f); // write 0x0f to 0x0306
    init_data[210] = cmd_wr(8'h00); // write 0x00 to 0x0307
    init_data[211] = cmd_wr(8'h00); // write 0x00 to 0x0308
    init_data[212] = cmd_wr(8'h00); // write 0x00 to 0x0309
    init_data[213] = cmd_wr(8'h00); // write 0x00 to 0x030a
    init_data[214] = cmd_wr(8'h80); // write 0x80 to 0x030b
    init_data[215] = cmd_wr(8'h00); // write 0x00 to 0x030c
    init_data[216] = cmd_wr(8'haa); // write 0xaa to 0x030d
    init_data[217] = cmd_wr(8'hd2); // write 0xd2 to 0x030e
    init_data[218] = cmd_wr(8'h8c); // write 0x8c to 0x030f
    init_data[219] = cmd_wr(8'hdd); // write 0xdd to 0x0310
    init_data[220] = cmd_wr(8'h0a); // write 0x0a to 0x0311
    init_data[221] = cmd_wr(8'h00); // write 0x00 to 0x0312
    init_data[222] = cmd_wr(8'hfc); // write 0xfc to 0x0313
    init_data[223] = cmd_wr(8'h8d); // write 0x8d to 0x0314
    init_data[224] = cmd_wr(8'h0e); // write 0x0e to 0x0315
    init_data[225] = cmd_wr(8'h80); // write 0x80 to 0x0316
    init_data[226] = cmd_wr(8'h00); // write 0x00 to 0x0317
    init_data[227] = cmd_wr(8'h00); // write 0x00 to 0x0318
    init_data[228] = cmd_wr(8'h00); // write 0x00 to 0x0319
    init_data[229] = cmd_wr(8'h00); // write 0x00 to 0x031a
    init_data[230] = cmd_wr(8'h00); // write 0x00 to 0x031b
    init_data[231] = cmd_wr(8'h00); // write 0x00 to 0x031c
    init_data[232] = cmd_wr(8'h00); // write 0x00 to 0x031d
    init_data[233] = cmd_wr(8'h00); // write 0x00 to 0x031e
    init_data[234] = cmd_wr(8'h00); // write 0x00 to 0x031f
    init_data[235] = cmd_wr(8'h00); // write 0x00 to 0x0320
    init_data[236] = cmd_wr(8'h00); // write 0x00 to 0x0321
    init_data[237] = cmd_wr(8'h00); // write 0x00 to 0x0322
    init_data[238] = cmd_wr(8'h00); // write 0x00 to 0x0323
    init_data[239] = cmd_wr(8'h00); // write 0x00 to 0x0324
    init_data[240] = cmd_wr(8'h00); // write 0x00 to 0x0325
    init_data[241] = cmd_wr(8'h00); // write 0x00 to 0x0326
    init_data[242] = cmd_wr(8'h00); // write 0x00 to 0x0327
    init_data[243] = cmd_wr(8'h00); // write 0x00 to 0x0328
    init_data[244] = cmd_wr(8'h00); // write 0x00 to 0x0329
    init_data[245] = cmd_wr(8'h00); // write 0x00 to 0x032a
    init_data[246] = cmd_wr(8'h00); // write 0x00 to 0x032b
    init_data[247] = cmd_wr(8'h00); // write 0x00 to 0x032c
    init_data[248] = cmd_wr(8'h00); // write 0x00 to 0x032d
    init_data[249] = cmd_start(7'h74);
    init_data[250] = cmd_wr(8'h38);
    init_data[251] = cmd_wr(8'h00); // write 0x00 to 0x0338
    init_data[252] = cmd_wr(8'h1f); // write 0x1f to 0x0339
    init_data[253] = cmd_start(7'h74);
    init_data[254] = cmd_wr(8'h3b);
    init_data[255] = cmd_wr(8'h00); // write 0x00 to 0x033b
    init_data[256] = cmd_wr(8'h00); // write 0x00 to 0x033c
    init_data[257] = cmd_wr(8'h00); // write 0x00 to 0x033d
    init_data[258] = cmd_wr(8'h00); // write 0x00 to 0x033e
    init_data[259] = cmd_wr(8'h00); // write 0x00 to 0x033f
    init_data[260] = cmd_wr(8'h00); // write 0x00 to 0x0340
    init_data[261] = cmd_wr(8'h00); // write 0x00 to 0x0341
    init_data[262] = cmd_wr(8'h00); // write 0x00 to 0x0342
    init_data[263] = cmd_wr(8'h00); // write 0x00 to 0x0343
    init_data[264] = cmd_wr(8'h00); // write 0x00 to 0x0344
    init_data[265] = cmd_wr(8'h00); // write 0x00 to 0x0345
    init_data[266] = cmd_wr(8'h00); // write 0x00 to 0x0346
    init_data[267] = cmd_wr(8'h00); // write 0x00 to 0x0347
    init_data[268] = cmd_wr(8'h00); // write 0x00 to 0x0348
    init_data[269] = cmd_wr(8'h00); // write 0x00 to 0x0349
    init_data[270] = cmd_wr(8'h00); // write 0x00 to 0x034a
    init_data[271] = cmd_wr(8'h00); // write 0x00 to 0x034b
    init_data[272] = cmd_wr(8'h00); // write 0x00 to 0x034c
    init_data[273] = cmd_wr(8'h00); // write 0x00 to 0x034d
    init_data[274] = cmd_wr(8'h00); // write 0x00 to 0x034e
    init_data[275] = cmd_wr(8'h00); // write 0x00 to 0x034f
    init_data[276] = cmd_wr(8'h00); // write 0x00 to 0x0350
    init_data[277] = cmd_wr(8'h00); // write 0x00 to 0x0351
    init_data[278] = cmd_wr(8'h00); // write 0x00 to 0x0352
    init_data[279] = cmd_start(7'h74);
    init_data[280] = cmd_wr(8'h59);
    init_data[281] = cmd_wr(8'h00); // write 0x00 to 0x0359
    init_data[282] = cmd_wr(8'h00); // write 0x00 to 0x035a
    init_data[283] = cmd_wr(8'h00); // write 0x00 to 0x035b
    init_data[284] = cmd_wr(8'h00); // write 0x00 to 0x035c
    init_data[285] = cmd_wr(8'h00); // write 0x00 to 0x035d
    init_data[286] = cmd_wr(8'h00); // write 0x00 to 0x035e
    init_data[287] = cmd_wr(8'h00); // write 0x00 to 0x035f
    init_data[288] = cmd_wr(8'h00); // write 0x00 to 0x0360
    init_data[289] = cmd_start(7'h74);
    init_data[290] = cmd_wr(8'h01);
    init_data[291] = cmd_wr(8'h08); // set page 0x08
    init_data[292] = cmd_start(7'h74);
    init_data[293] = cmd_wr(8'h02);
    init_data[294] = cmd_wr(8'h00); // write 0x00 to 0x0802
    init_data[295] = cmd_wr(8'h00); // write 0x00 to 0x0803
    init_data[296] = cmd_wr(8'h00); // write 0x00 to 0x0804
    init_data[297] = cmd_wr(8'h00); // write 0x00 to 0x0805
    init_data[298] = cmd_wr(8'h00); // write 0x00 to 0x0806
    init_data[299] = cmd_wr(8'h00); // write 0x00 to 0x0807
    init_data[300] = cmd_wr(8'h00); // write 0x00 to 0x0808
    init_data[301] = cmd_wr(8'h00); // write 0x00 to 0x0809
    init_data[302] = cmd_wr(8'h00); // write 0x00 to 0x080a
    init_data[303] = cmd_wr(8'h00); // write 0x00 to 0x080b
    init_data[304] = cmd_wr(8'h00); // write 0x00 to 0x080c
    init_data[305] = cmd_wr(8'h00); // write 0x00 to 0x080d
    init_data[306] = cmd_wr(8'h00); // write 0x00 to 0x080e
    init_data[307] = cmd_wr(8'h00); // write 0x00 to 0x080f
    init_data[308] = cmd_wr(8'h00); // write 0x00 to 0x0810
    init_data[309] = cmd_wr(8'h00); // write 0x00 to 0x0811
    init_data[310] = cmd_wr(8'h00); // write 0x00 to 0x0812
    init_data[311] = cmd_wr(8'h00); // write 0x00 to 0x0813
    init_data[312] = cmd_wr(8'h00); // write 0x00 to 0x0814
    init_data[313] = cmd_wr(8'h00); // write 0x00 to 0x0815
    init_data[314] = cmd_wr(8'h00); // write 0x00 to 0x0816
    init_data[315] = cmd_wr(8'h00); // write 0x00 to 0x0817
    init_data[316] = cmd_wr(8'h00); // write 0x00 to 0x0818
    init_data[317] = cmd_wr(8'h00); // write 0x00 to 0x0819
    init_data[318] = cmd_wr(8'h00); // write 0x00 to 0x081a
    init_data[319] = cmd_wr(8'h00); // write 0x00 to 0x081b
    init_data[320] = cmd_wr(8'h00); // write 0x00 to 0x081c
    init_data[321] = cmd_wr(8'h00); // write 0x00 to 0x081d
    init_data[322] = cmd_wr(8'h00); // write 0x00 to 0x081e
    init_data[323] = cmd_wr(8'h00); // write 0x00 to 0x081f
    init_data[324] = cmd_wr(8'h00); // write 0x00 to 0x0820
    init_data[325] = cmd_wr(8'h00); // write 0x00 to 0x0821
    init_data[326] = cmd_wr(8'h00); // write 0x00 to 0x0822
    init_data[327] = cmd_wr(8'h00); // write 0x00 to 0x0823
    init_data[328] = cmd_wr(8'h00); // write 0x00 to 0x0824
    init_data[329] = cmd_wr(8'h00); // write 0x00 to 0x0825
    init_data[330] = cmd_wr(8'h00); // write 0x00 to 0x0826
    init_data[331] = cmd_wr(8'h00); // write 0x00 to 0x0827
    init_data[332] = cmd_wr(8'h00); // write 0x00 to 0x0828
    init_data[333] = cmd_wr(8'h00); // write 0x00 to 0x0829
    init_data[334] = cmd_wr(8'h00); // write 0x00 to 0x082a
    init_data[335] = cmd_wr(8'h00); // write 0x00 to 0x082b
    init_data[336] = cmd_wr(8'h00); // write 0x00 to 0x082c
    init_data[337] = cmd_wr(8'h00); // write 0x00 to 0x082d
    init_data[338] = cmd_wr(8'h00); // write 0x00 to 0x082e
    init_data[339] = cmd_wr(8'h00); // write 0x00 to 0x082f
    init_data[340] = cmd_wr(8'h00); // write 0x00 to 0x0830
    init_data[341] = cmd_wr(8'h00); // write 0x00 to 0x0831
    init_data[342] = cmd_wr(8'h00); // write 0x00 to 0x0832
    init_data[343] = cmd_wr(8'h00); // write 0x00 to 0x0833
    init_data[344] = cmd_wr(8'h00); // write 0x00 to 0x0834
    init_data[345] = cmd_wr(8'h00); // write 0x00 to 0x0835
    init_data[346] = cmd_wr(8'h00); // write 0x00 to 0x0836
    init_data[347] = cmd_wr(8'h00); // write 0x00 to 0x0837
    init_data[348] = cmd_wr(8'h00); // write 0x00 to 0x0838
    init_data[349] = cmd_wr(8'h00); // write 0x00 to 0x0839
    init_data[350] = cmd_wr(8'h00); // write 0x00 to 0x083a
    init_data[351] = cmd_wr(8'h00); // write 0x00 to 0x083b
    init_data[352] = cmd_wr(8'h00); // write 0x00 to 0x083c
    init_data[353] = cmd_wr(8'h00); // write 0x00 to 0x083d
    init_data[354] = cmd_wr(8'h00); // write 0x00 to 0x083e
    init_data[355] = cmd_wr(8'h00); // write 0x00 to 0x083f
    init_data[356] = cmd_wr(8'h00); // write 0x00 to 0x0840
    init_data[357] = cmd_wr(8'h00); // write 0x00 to 0x0841
    init_data[358] = cmd_wr(8'h00); // write 0x00 to 0x0842
    init_data[359] = cmd_wr(8'h00); // write 0x00 to 0x0843
    init_data[360] = cmd_wr(8'h00); // write 0x00 to 0x0844
    init_data[361] = cmd_wr(8'h00); // write 0x00 to 0x0845
    init_data[362] = cmd_wr(8'h00); // write 0x00 to 0x0846
    init_data[363] = cmd_wr(8'h00); // write 0x00 to 0x0847
    init_data[364] = cmd_wr(8'h00); // write 0x00 to 0x0848
    init_data[365] = cmd_wr(8'h00); // write 0x00 to 0x0849
    init_data[366] = cmd_wr(8'h00); // write 0x00 to 0x084a
    init_data[367] = cmd_wr(8'h00); // write 0x00 to 0x084b
    init_data[368] = cmd_wr(8'h00); // write 0x00 to 0x084c
    init_data[369] = cmd_wr(8'h00); // write 0x00 to 0x084d
    init_data[370] = cmd_wr(8'h00); // write 0x00 to 0x084e
    init_data[371] = cmd_wr(8'h00); // write 0x00 to 0x084f
    init_data[372] = cmd_wr(8'h00); // write 0x00 to 0x0850
    init_data[373] = cmd_wr(8'h00); // write 0x00 to 0x0851
    init_data[374] = cmd_wr(8'h00); // write 0x00 to 0x0852
    init_data[375] = cmd_wr(8'h00); // write 0x00 to 0x0853
    init_data[376] = cmd_wr(8'h00); // write 0x00 to 0x0854
    init_data[377] = cmd_wr(8'h00); // write 0x00 to 0x0855
    init_data[378] = cmd_wr(8'h00); // write 0x00 to 0x0856
    init_data[379] = cmd_wr(8'h00); // write 0x00 to 0x0857
    init_data[380] = cmd_wr(8'h00); // write 0x00 to 0x0858
    init_data[381] = cmd_wr(8'h00); // write 0x00 to 0x0859
    init_data[382] = cmd_wr(8'h00); // write 0x00 to 0x085a
    init_data[383] = cmd_wr(8'h00); // write 0x00 to 0x085b
    init_data[384] = cmd_wr(8'h00); // write 0x00 to 0x085c
    init_data[385] = cmd_wr(8'h00); // write 0x00 to 0x085d
    init_data[386] = cmd_wr(8'h00); // write 0x00 to 0x085e
    init_data[387] = cmd_wr(8'h00); // write 0x00 to 0x085f
    init_data[388] = cmd_wr(8'h00); // write 0x00 to 0x0860
    init_data[389] = cmd_wr(8'h00); // write 0x00 to 0x0861
    init_data[390] = cmd_start(7'h74);
    init_data[391] = cmd_wr(8'h01);
    init_data[392] = cmd_wr(8'h09); // set page 0x09
    init_data[393] = cmd_start(7'h74);
    init_data[394] = cmd_wr(8'h0e);
    init_data[395] = cmd_wr(8'h02); // write 0x02 to 0x090e
    init_data[396] = cmd_start(7'h74);
    init_data[397] = cmd_wr(8'h1c);
    init_data[398] = cmd_wr(8'h04); // write 0x04 to 0x091c
    init_data[399] = cmd_start(7'h74);
    init_data[400] = cmd_wr(8'h43);
    init_data[401] = cmd_wr(8'h00); // write 0x00 to 0x0943
    init_data[402] = cmd_start(7'h74);
    init_data[403] = cmd_wr(8'h49);
    init_data[404] = cmd_wr(8'h00); // write 0x00 to 0x0949
    init_data[405] = cmd_wr(8'h00); // write 0x00 to 0x094a
    init_data[406] = cmd_start(7'h74);
    init_data[407] = cmd_wr(8'h4e);
    init_data[408] = cmd_wr(8'h49); // write 0x49 to 0x094e
    init_data[409] = cmd_wr(8'h02); // write 0x02 to 0x094f
    init_data[410] = cmd_start(7'h74);
    init_data[411] = cmd_wr(8'h5e);
    init_data[412] = cmd_wr(8'h00); // write 0x00 to 0x095e
    init_data[413] = cmd_start(7'h74);
    init_data[414] = cmd_wr(8'h01);
    init_data[415] = cmd_wr(8'h0a); // set page 0x0a
    init_data[416] = cmd_start(7'h74);
    init_data[417] = cmd_wr(8'h02);
    init_data[418] = cmd_wr(8'h00); // write 0x00 to 0x0a02
    init_data[419] = cmd_wr(8'h03); // write 0x03 to 0x0a03
    init_data[420] = cmd_wr(8'h01); // write 0x01 to 0x0a04
    init_data[421] = cmd_wr(8'h03); // write 0x03 to 0x0a05
    init_data[422] = cmd_start(7'h74);
    init_data[423] = cmd_wr(8'h14);
    init_data[424] = cmd_wr(8'h00); // write 0x00 to 0x0a14
    init_data[425] = cmd_start(7'h74);
    init_data[426] = cmd_wr(8'h1a);
    init_data[427] = cmd_wr(8'h00); // write 0x00 to 0x0a1a
    init_data[428] = cmd_start(7'h74);
    init_data[429] = cmd_wr(8'h20);
    init_data[430] = cmd_wr(8'h00); // write 0x00 to 0x0a20
    init_data[431] = cmd_start(7'h74);
    init_data[432] = cmd_wr(8'h26);
    init_data[433] = cmd_wr(8'h00); // write 0x00 to 0x0a26
    init_data[434] = cmd_start(7'h74);
    init_data[435] = cmd_wr(8'h01);
    init_data[436] = cmd_wr(8'h0b); // set page 0x0b
    init_data[437] = cmd_start(7'h74);
    init_data[438] = cmd_wr(8'h44);
    init_data[439] = cmd_wr(8'h0f); // write 0x0f to 0x0b44
    init_data[440] = cmd_start(7'h74);
    init_data[441] = cmd_wr(8'h4a);
    init_data[442] = cmd_wr(8'h0c); // write 0x0c to 0x0b4a
    init_data[443] = cmd_start(7'h74);
    init_data[444] = cmd_wr(8'h57);
    init_data[445] = cmd_wr(8'h0e); // write 0x0e to 0x0b57
    init_data[446] = cmd_wr(8'h01); // write 0x01 to 0x0b58
    // End configuration registers
    // 
    // Start configuration postamble
    init_data[447] = cmd_start(7'h74);
    init_data[448] = cmd_wr(8'h01);
    init_data[449] = cmd_wr(8'h00); // set page 0x00
    init_data[450] = cmd_start(7'h74);
    init_data[451] = cmd_wr(8'h1c);
    init_data[452] = cmd_wr(8'h01); // write 0x01 to 0x001c
    init_data[453] = cmd_start(7'h74);
    init_data[454] = cmd_wr(8'h01);
    init_data[455] = cmd_wr(8'h0b); // set page 0x0b
    init_data[456] = cmd_start(7'h74);
    init_data[457] = cmd_wr(8'h24);
    init_data[458] = cmd_wr(8'hc3); // write 0xc3 to 0x0b24
    init_data[459] = cmd_wr(8'h02); // write 0x02 to 0x0b25
    // End configuration postamble
    init_data[460] = cmd_halt(); // end
end

typedef enum logic [2:0] {
    STATE_IDLE,
    STATE_RUN,
    STATE_TABLE_1,
    STATE_TABLE_2,
    STATE_TABLE_3
} state_t;

state_t state_reg = STATE_IDLE, state_next;

localparam AW = $clog2(INIT_DATA_LEN);

logic [8:0] init_data_reg = '0;

logic [AW-1:0] address_reg = '0, address_next;
logic [AW-1:0] address_ptr_reg = '0, address_ptr_next;
logic [AW-1:0] data_ptr_reg = '0, data_ptr_next;

logic [6:0] cur_address_reg = '0, cur_address_next;

logic [31:0] delay_counter_reg = '0, delay_counter_next;

logic [6:0] m_axis_cmd_address_reg = '0, m_axis_cmd_address_next;
logic m_axis_cmd_start_reg = 1'b0, m_axis_cmd_start_next;
logic m_axis_cmd_write_reg = 1'b0, m_axis_cmd_write_next;
logic m_axis_cmd_stop_reg = 1'b0, m_axis_cmd_stop_next;
logic m_axis_cmd_valid_reg = 1'b0, m_axis_cmd_valid_next;

logic [7:0] m_axis_tx_tdata_reg = '0, m_axis_tx_tdata_next;
logic m_axis_tx_tvalid_reg = 1'b0, m_axis_tx_tvalid_next;

logic start_flag_reg = 1'b0, start_flag_next;

logic busy_reg = 1'b0;

assign m_axis_cmd.tdata[6:0] = m_axis_cmd_address_reg;
assign m_axis_cmd.tdata[7]   = m_axis_cmd_start_reg;
assign m_axis_cmd.tdata[8]   = 1'b0; // read
assign m_axis_cmd.tdata[9]   = m_axis_cmd_write_reg;
assign m_axis_cmd.tdata[10]  = 1'b0; // write multi
assign m_axis_cmd.tdata[11]  = m_axis_cmd_stop_reg;
assign m_axis_cmd.tvalid = m_axis_cmd_valid_reg;
assign m_axis_cmd.tlast = 1'b1;
assign m_axis_cmd.tid = '0;
assign m_axis_cmd.tdest = '0;
assign m_axis_cmd.tuser = '0;

assign m_axis_tx.tdata = m_axis_tx_tdata_reg;
assign m_axis_tx.tvalid = m_axis_tx_tvalid_reg;
assign m_axis_tx.tlast = 1'b1;
assign m_axis_tx.tid = '0;
assign m_axis_tx.tdest = '0;
assign m_axis_tx.tuser = '0;

assign busy = busy_reg;

always_comb begin
    state_next = STATE_IDLE;

    address_next = address_reg;
    address_ptr_next = address_ptr_reg;
    data_ptr_next = data_ptr_reg;

    cur_address_next = cur_address_reg;

    delay_counter_next = delay_counter_reg;

    m_axis_cmd_address_next = m_axis_cmd_address_reg;
    m_axis_cmd_start_next = m_axis_cmd_start_reg && !(m_axis_cmd.tvalid && m_axis_cmd.tready);
    m_axis_cmd_write_next = m_axis_cmd_write_reg && !(m_axis_cmd.tvalid && m_axis_cmd.tready);
    m_axis_cmd_stop_next = m_axis_cmd_stop_reg && !(m_axis_cmd.tvalid && m_axis_cmd.tready);
    m_axis_cmd_valid_next = m_axis_cmd_valid_reg && !m_axis_cmd.tready;

    m_axis_tx_tdata_next = m_axis_tx_tdata_reg;
    m_axis_tx_tvalid_next = m_axis_tx_tvalid_reg && !m_axis_tx.tready;

    start_flag_next = start_flag_reg;

    if (m_axis_cmd.tvalid || m_axis_tx.tvalid) begin
        // wait for output registers to clear
        state_next = state_reg;
    end else if (delay_counter_reg != 0) begin
        // delay
        delay_counter_next = delay_counter_reg - 1;
        state_next = state_reg;
    end else begin
        case (state_reg)
            STATE_IDLE: begin
                // wait for start signal
                if (!start_flag_reg && start) begin
                    address_next = '0;
                    start_flag_next = 1'b1;
                    state_next = STATE_RUN;
                end else begin
                    state_next = STATE_IDLE;
                end
            end
            STATE_RUN: begin
                // process commands
                if (init_data_reg[8] == 1'b1) begin
                    // write data
                    m_axis_cmd_write_next = 1'b1;
                    m_axis_cmd_stop_next = 1'b0;
                    m_axis_cmd_valid_next = 1'b1;

                    m_axis_tx_tdata_next = init_data_reg[7:0];
                    m_axis_tx_tvalid_next = 1'b1;

                    address_next = address_reg + 1;

                    state_next = STATE_RUN;
                end else if (init_data_reg[8:7] == 2'b01) begin
                    // write address
                    m_axis_cmd_address_next = init_data_reg[6:0];
                    m_axis_cmd_start_next = 1'b1;

                    address_next = address_reg + 1;

                    state_next = STATE_RUN;
                end else if (init_data_reg[8:4] == 5'b00001) begin
                    // delay
                    if (SIM_SPEEDUP) begin
                        delay_counter_next = 32'd1 << (init_data_reg[3:0]);
                    end else begin
                        delay_counter_next = 32'd1 << (init_data_reg[3:0]+16);
                    end

                    address_next = address_reg + 1;

                    state_next = STATE_RUN;
                end else if (init_data_reg == 9'b001000001) begin
                    // send stop
                    m_axis_cmd_write_next = 1'b0;
                    m_axis_cmd_start_next = 1'b0;
                    m_axis_cmd_stop_next = 1'b1;
                    m_axis_cmd_valid_next = 1'b1;

                    address_next = address_reg + 1;

                    state_next = STATE_RUN;
                end else if (init_data_reg == 9'b000001001) begin
                    // data table start
                    data_ptr_next = address_reg + 1;
                    address_next = address_reg + 1;
                    state_next = STATE_TABLE_1;
                end else if (init_data_reg == 9'd0) begin
                    // stop
                    m_axis_cmd_start_next = 1'b0;
                    m_axis_cmd_write_next = 1'b0;
                    m_axis_cmd_stop_next = 1'b1;
                    m_axis_cmd_valid_next = 1'b1;

                    state_next = STATE_IDLE;
                end else begin
                    // invalid command, skip
                    address_next = address_reg + 1;
                    state_next = STATE_RUN;
                end
            end
            STATE_TABLE_1: begin
                // find address table start
                if (init_data_reg == 9'b000001000) begin
                    // address table start
                    address_ptr_next = address_reg + 1;
                    address_next = address_reg + 1;
                    state_next = STATE_TABLE_2;
                end else if (init_data_reg == 9'b000001001) begin
                    // data table start
                    data_ptr_next = address_reg + 1;
                    address_next = address_reg + 1;
                    state_next = STATE_TABLE_1;
                end else if (init_data_reg == 1) begin
                    // exit mode
                    address_next = address_reg + 1;
                    state_next = STATE_RUN;
                end else if (init_data_reg == 9'd0) begin
                    // stop
                    m_axis_cmd_start_next = 1'b0;
                    m_axis_cmd_write_next = 1'b0;
                    m_axis_cmd_stop_next = 1'b1;
                    m_axis_cmd_valid_next = 1'b1;

                    state_next = STATE_IDLE;
                end else begin
                    // invalid command, skip
                    address_next = address_reg + 1;
                    state_next = STATE_TABLE_1;
                end
            end
            STATE_TABLE_2: begin
                // find next address
                if (init_data_reg[8:7] == 2'b01) begin
                    // write address command
                    // store address and move to data table
                    cur_address_next = init_data_reg[6:0];
                    address_ptr_next = address_reg + 1;
                    address_next = data_ptr_reg;
                    state_next = STATE_TABLE_3;
                end else if (init_data_reg == 9'b000001001) begin
                    // data table start
                    data_ptr_next = address_reg + 1;
                    address_next = address_reg + 1;
                    state_next = STATE_TABLE_1;
                end else if (init_data_reg == 9'd1) begin
                    // exit mode
                    address_next = address_reg + 1;
                    state_next = STATE_RUN;
                end else if (init_data_reg == 9'd0) begin
                    // stop
                    m_axis_cmd_start_next = 1'b0;
                    m_axis_cmd_write_next = 1'b0;
                    m_axis_cmd_stop_next = 1'b1;
                    m_axis_cmd_valid_next = 1'b1;

                    state_next = STATE_IDLE;
                end else begin
                    // invalid command, skip
                    address_next = address_reg + 1;
                    state_next = STATE_TABLE_2;
                end
            end
            STATE_TABLE_3: begin
                // process data table with selected address
                if (init_data_reg[8] == 1'b1) begin
                    // write data
                    m_axis_cmd_write_next = 1'b1;
                    m_axis_cmd_stop_next = 1'b0;
                    m_axis_cmd_valid_next = 1'b1;

                    m_axis_tx_tdata_next = init_data_reg[7:0];
                    m_axis_tx_tvalid_next = 1'b1;

                    address_next = address_reg + 1;

                    state_next = STATE_TABLE_3;
                end else if (init_data_reg[8:7] == 2'b01) begin
                    // write address
                    m_axis_cmd_address_next = init_data_reg[6:0];
                    m_axis_cmd_start_next = 1'b1;

                    address_next = address_reg + 1;

                    state_next = STATE_TABLE_3;
                end else if (init_data_reg == 9'b000000011) begin
                    // write current address
                    m_axis_cmd_address_next = cur_address_reg;
                    m_axis_cmd_start_next = 1'b1;

                    address_next = address_reg + 1;

                    state_next = STATE_TABLE_3;
                end else if (init_data_reg[8:4] == 5'b00001) begin
                    // delay
                    if (SIM_SPEEDUP) begin
                        delay_counter_next = 32'd1 << (init_data_reg[3:0]);
                    end else begin
                        delay_counter_next = 32'd1 << (init_data_reg[3:0]+16);
                    end

                    address_next = address_reg + 1;

                    state_next = STATE_TABLE_3;
                end else if (init_data_reg == 9'b001000001) begin
                    // send stop
                    m_axis_cmd_write_next = 1'b0;
                    m_axis_cmd_start_next = 1'b0;
                    m_axis_cmd_stop_next = 1'b1;
                    m_axis_cmd_valid_next = 1'b1;

                    address_next = address_reg + 1;

                    state_next = STATE_TABLE_3;
                end else if (init_data_reg == 9'b000001001) begin
                    // data table start
                    data_ptr_next = address_reg + 1;
                    address_next = address_reg + 1;
                    state_next = STATE_TABLE_1;
                end else if (init_data_reg == 9'b000001000) begin
                    // address table start
                    address_next = address_ptr_reg;
                    state_next = STATE_TABLE_2;
                end else if (init_data_reg == 9'd1) begin
                    // exit mode
                    address_next = address_reg + 1;
                    state_next = STATE_RUN;
                end else if (init_data_reg == 9'd0) begin
                    // stop
                    m_axis_cmd_start_next = 1'b0;
                    m_axis_cmd_write_next = 1'b0;
                    m_axis_cmd_stop_next = 1'b1;
                    m_axis_cmd_valid_next = 1'b1;

                    state_next = STATE_IDLE;
                end else begin
                    // invalid command, skip
                    address_next = address_reg + 1;
                    state_next = STATE_TABLE_3;
                end
            end
            default: begin
                // invalid state
                state_next = STATE_IDLE;
            end
        endcase
    end
end

always_ff @(posedge clk) begin
    state_reg <= state_next;

    // read init_data ROM
    init_data_reg <= init_data[address_next];

    address_reg <= address_next;
    address_ptr_reg <= address_ptr_next;
    data_ptr_reg <= data_ptr_next;

    cur_address_reg <= cur_address_next;

    delay_counter_reg <= delay_counter_next;

    m_axis_cmd_address_reg <= m_axis_cmd_address_next;
    m_axis_cmd_start_reg <= m_axis_cmd_start_next;
    m_axis_cmd_write_reg <= m_axis_cmd_write_next;
    m_axis_cmd_stop_reg <= m_axis_cmd_stop_next;
    m_axis_cmd_valid_reg <= m_axis_cmd_valid_next;

    m_axis_tx_tdata_reg <= m_axis_tx_tdata_next;
    m_axis_tx_tvalid_reg <= m_axis_tx_tvalid_next;

    start_flag_reg <= start && start_flag_next;

    busy_reg <= (state_reg != STATE_IDLE);

    if (rst) begin
        state_reg <= STATE_IDLE;

        init_data_reg <= '0;

        address_reg <= '0;
        address_ptr_reg <= '0;
        data_ptr_reg <= '0;

        cur_address_reg <= '0;

        delay_counter_reg <= '0;

        m_axis_cmd_valid_reg <= 1'b0;

        m_axis_tx_tvalid_reg <= 1'b0;

        start_flag_reg <= 1'b0;

        busy_reg <= 1'b0;
    end
end

endmodule

`resetall