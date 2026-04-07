#!/usr/bin/env python
"""
Generates an I2C init module for multiple chips
"""

from jinja2 import Template


def si5340_cmds(regs, dev_addr=0x77):
    cur_page = None
    cur_addr = None

    cmds = []

    print(f"Reading register list file '{regs}'...")

    with open(regs, "r") as f:
        for line in f:
            line = line.strip()
            if not line or line == "Address,Data":
                continue
            if line[0] == '#':
                cmds.append(f"// {line[1:].strip()}")

                if line.startswith("# Delay"):
                    cmds.append("cmd_delay(10); // delay 300 ms")
                    cur_addr = None

                continue

            d = line.split(",")
            addr = int(d[0], 0)
            page = (addr >> 8) & 0xff
            data = int(d[1], 0)

            if page != cur_page:
                cmds.append(f"cmd_start(7'h{dev_addr:02x});")
                cmds.append("cmd_wr(8'h01);")
                cmds.append(f"cmd_wr(8'h{page:02x}); // set page {page:#04x}")
                cur_page = page
                cur_addr = None

            if addr != cur_addr:
                cmds.append(f"cmd_start(7'h{dev_addr:02x});")
                cmds.append(f"cmd_wr(8'h{addr & 0xff:02x});")
                cur_addr = addr

            cmds.append(f"cmd_wr(8'h{data:02x}); // write {data:#04x} to {addr:#06x}")
            cur_addr += 1

    return cmds


def mux_cmds(val, dev_addr):
    cmds = []
    cmds.append(f"cmd_start(7'h{dev_addr:02x});")
    cmds.append(f"cmd_wr(8'h{val:02x});")
    cmds.append("cmd_stop(); // I2C stop")
    return cmds


def main():
    cmds = []

    cmds.append("// Initial delay")
    cmds.append("cmd_delay(6); // delay 30 ms")

    cmds.extend(si5340_cmds("Si5340-RevD-NT200-Registers.txt", 0x74))

    generate(cmds, output="si5340_i2c_init.sv")


def generate(cmds=None, name=None, output=None):
    if cmds is None:
        raise Exception("Command list is required")

    if name is None:
        name = "si5340_i2c_init"

    if output is None:
        output = name + ".sv"

    print(f"Generating Si5340 I2C init module {name}...")

    cmds = cmds.copy()
    cmds.append("cmd_halt(); // end")

    cmd_str = ""
    cmd_count = 0

    for cmd in cmds:
        if cmd.startswith('//'):
            cmd_str += f"    {cmd}\n"
        else:
            cmd_str += f"    init_data[{cmd_count}] = {cmd}\n"
            cmd_count += 1

    t = Template(u"""// SPDX-License-Identifier: CERN-OHL-S-2.0
/*

Copyright (c) 2015-2026 FPGA Ninja, LLC

Authors:
- Alex Forencich

*/

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * {{name}}
 */
module {{name}} #
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
localparam INIT_DATA_LEN = {{cmd_count}};

reg [8:0] init_data [INIT_DATA_LEN-1:0];

initial begin
{{cmd_str-}}
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
""")

    print(f"Writing file '{output}'...")

    with open(output, 'w') as f:
        f.write(t.render(
            cmd_str=cmd_str,
            cmd_count=cmd_count,
            name=name
        ))
        f.flush()

    print("Done")


if __name__ == "__main__":
    main()
