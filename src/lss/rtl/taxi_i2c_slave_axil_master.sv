// SPDX-License-Identifier: CERN-OHL-S-2.0
/*

Copyright (c) 2019-2025 FPGA Ninja, LLC

Authors:
- Alex Forencich

*/

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * I2C slave AXI lite master wrapper
 */
module taxi_i2c_slave_axil_master #
(
    parameter FILTER_LEN = 4
)
(
    input  wire logic        clk,
    input  wire logic        rst,

    /*
     * I2C interface
     */
    input  wire logic        i2c_scl_i,
    output wire logic        i2c_scl_o,
    input  wire logic        i2c_sda_i,
    output wire logic        i2c_sda_o,

    /*
     * AXI4-Lite master interface
     */
    taxi_axil_if.wr_mst      m_axil_wr,
    taxi_axil_if.rd_mst      m_axil_rd,

    /*
     * Status
     */
    output wire logic        busy,
    output wire logic [6:0]  bus_address,
    output wire logic        bus_addressed,
    output wire logic        bus_active,

    /*
     * Configuration
     */
    input  wire logic        enable,
    input  wire logic [6:0]  device_address
);
/*

I2C

Read
    __    ___ ___ ___ ___ ___ ___ ___ ___     ___ ___ ___ ___ ___ ___ ___ ___     ___ ___ ___ ___ ___ ___ ___ ___ ___    __
sda   \__/_6_X_5_X_4_X_3_X_2_X_1_X_0_/ R \_A_/_7_X_6_X_5_X_4_X_3_X_2_X_1_X_0_\_A_/_7_X_6_X_5_X_4_X_3_X_2_X_1_X_0_/ N \__/
    ____   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   ____
scl  ST \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ SP

Write
    __    ___ ___ ___ ___ ___ ___ ___         ___ ___ ___ ___ ___ ___ ___ ___     ___ ___ ___ ___ ___ ___ ___ ___        __
sda   \__/_6_X_5_X_4_X_3_X_2_X_1_X_0_\_W___A_/_7_X_6_X_5_X_4_X_3_X_2_X_1_X_0_\_A_/_7_X_6_X_5_X_4_X_3_X_2_X_1_X_0_\_A____/
    ____   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   _   ____
scl  ST \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ SP

Operation:

This module enables I2C control over an AXI lite bus, useful for enabling a
design to operate as a peripheral to an external microcontroller or similar.
The AXI lite interface are fully parametrizable, with the restriction that the
bus must be divided into 2**m words of 8*2**n bits.

Writing via I2C first accesses an internal address register, followed by the
actual AXI lite bus.  The first k bytes go to the address register, where

    k = ceil(log2(ADDR_W+log2(DATA_W/SELECT_W))/8)

.  The address pointer will automatically increment with reads and writes.
For buses with word size > 8 bits, the address register is in bytes and
unaligned writes will be padded with zeros.  Writes to the same bus address in
the same I2C transaction are coalesced and written either once a complete
word is ready or when the I2C transaction terminates with a stop or repeated
start.

Reading via the I2C interface immediately starts reading from the AXI lite
interface starting from the current value of the internal address register.
Like writes, reads are also coalesced when possible.  One AXI lite read is
performed on the first I2C read.  Once that has been completely transferred
out, another read will be performed on the start of the next I2C read
operation.

Read
_   _ _ _ _ _ _ _ _   _ _ _ _ _ _ _ _         _ _ _ _ _ _ _ _   _   _ _ _ _ _ _ _     _ _ _ _ _ _ _ _         _ _ _ _ _ _ _ _ _   _
 |_|_|_|_|_|_|_|_| |_|_|_|_|_|_|_|_|_|_ ... _|_|_|_|_|_|_|_|_|_| |_|_|_|_|_|_|_|_|___|_|_|_|_|_|_|_|_|_ ... _|_|_|_|_|_|_|_|_| |_|

ST  Device Addr   W A   Address MSB   A         Address LSB   A  RS Device Addr   R A   Data byte 0   A         Data byte N   N  SP

Write
_   _ _ _ _ _ _ _ _   _ _ _ _ _ _ _ _         _ _ _ _ _ _ _ _   _ _ _ _ _ _ _ _         _ _ _ _ _ _ _ _     _
 |_|_|_|_|_|_|_|_| |_|_|_|_|_|_|_|_|_|_ ... _|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_|_ ... _|_|_|_|_|_|_|_|_|___|

ST  Device Addr   W A   Address MSB   A         Address LSB   A   Data byte 0   A         Data byte N   A  SP

Status:

busy
    module is communicating over the bus

bus_control
    module has control of bus in active state

bus_active
    bus is active, not necessarily controlled by this module

Parameters:

device_address
    address of slave device

Example of interfacing with tristate pins:

assign scl_i = scl_pin;
assign scl_pin = scl_o ? 1'bz : 1'b0;
assign sda_i = sda_pin;
assign sda_pin = sda_o ? 1'bz : 1'b0;

Example of two interconnected internal I2C devices:

assign scl_1_i = scl_1_o & scl_2_o;
assign scl_2_i = scl_1_o & scl_2_o;
assign sda_1_i = sda_1_o & sda_2_o;
assign sda_2_i = sda_1_o & sda_2_o;

Example of two I2C devices sharing the same pins:

assign scl_1_i = scl_pin;
assign scl_2_i = scl_pin;
assign scl_pin = (scl_1_o & scl_2_o) ? 1'bz : 1'b0;
assign sda_1_i = sda_pin;
assign sda_2_i = sda_pin;
assign sda_pin = (sda_1_o & sda_2_o) ? 1'bz : 1'b0;

Notes:

scl_o should not be connected directly to scl_i, only via AND logic or a tristate
I/O pin.  This would prevent devices from stretching the clock period.

*/

// TODO REMOVE THIS
/* verilator lint_off WIDTHTRUNC */

localparam DATA_W = m_axil_wr.DATA_W;
localparam ADDR_W = m_axil_wr.ADDR_W;
localparam STRB_W = m_axil_wr.STRB_W;

// for interfaces that are more than one word wide, disable address lines
localparam VALID_ADDR_W = ADDR_W - $clog2(STRB_W);
// width of data port in words
localparam BYTE_LANES = STRB_W;
// size of words
localparam BYTE_SIZE = DATA_W/BYTE_LANES;

localparam WORD_PART_ADDR_W = $clog2(BYTE_SIZE/8);

localparam ADDR_W_ADJ = ADDR_W+WORD_PART_ADDR_W;

localparam ADDR_WORD_W = (ADDR_W_ADJ+7)/8;

// check configuration
if (BYTE_LANES * BYTE_SIZE != DATA_W)
    $fatal(0, "Error: AXI data width not evenly divisible (instance %m)");

if (2**$clog2(BYTE_LANES) != BYTE_LANES)
    $fatal(0, "Error: AXI word width must be even power of two (instance %m)");

if (8*2**$clog2(BYTE_SIZE/8) != BYTE_SIZE)
    $fatal(0, "Error: AXI word size must be a power of two multiple of 8 bits (instance %m)");

localparam [2:0]
    STATE_IDLE = 3'd0,
    STATE_ADDRESS = 3'd1,
    STATE_READ_1 = 3'd2,
    STATE_READ_2 = 3'd3,
    STATE_WRITE_1 = 3'd4,
    STATE_WRITE_2 = 3'd5;

logic [2:0] state_reg = STATE_IDLE, state_next;

logic [7:0] count_reg = '0, count_next;
logic last_cycle_reg = 1'b0;

logic [ADDR_W_ADJ-1:0] addr_reg = '0, addr_next;
logic [DATA_W-1:0] data_reg = '0, data_next;

logic m_axil_awvalid_reg = 1'b0, m_axil_awvalid_next;
logic [STRB_W-1:0] m_axil_wstrb_reg = '0, m_axil_wstrb_next;
logic m_axil_wvalid_reg = 1'b0, m_axil_wvalid_next;
logic m_axil_bready_reg = 1'b0, m_axil_bready_next;
logic m_axil_arvalid_reg = 1'b0, m_axil_arvalid_next;
logic m_axil_rready_reg = 1'b0, m_axil_rready_next;

logic busy_reg = 1'b0;

taxi_axis_if #(.DATA_W(8)) axis_tx();
taxi_axis_if #(.DATA_W(8)) axis_rx();

logic [7:0] axis_tx_reg = '0, axis_tx_next;
logic axis_tx_valid_reg = 1'b0, axis_tx_valid_next;
assign axis_tx.tdata = axis_tx_reg;
assign axis_tx.tvalid = axis_tx_valid_reg;
assign axis_tx.tlast = 1'b1;
assign axis_tx.tid = '0;
assign axis_tx.tdest = '0;
assign axis_tx.tuser = '0;

logic axis_rx_ready_reg = 1'b0, axis_rx_ready_next;
assign axis_rx.tready = axis_rx_ready_reg;

assign m_axil_wr.awaddr = addr_reg;
assign m_axil_wr.awprot = 3'b010;
assign m_axil_wr.awuser = '0;
assign m_axil_wr.awvalid = m_axil_awvalid_reg;
assign m_axil_wr.wdata = data_reg;
assign m_axil_wr.wstrb = m_axil_wstrb_reg;
assign m_axil_wr.wuser = '0;
assign m_axil_wr.wvalid = m_axil_wvalid_reg;
assign m_axil_wr.bready = m_axil_bready_reg;

assign m_axil_rd.araddr = addr_reg;
assign m_axil_rd.arprot = 3'b010;
assign m_axil_rd.aruser = '0;
assign m_axil_rd.arvalid = m_axil_arvalid_reg;
assign m_axil_rd.rready = m_axil_rready_reg;

assign busy = busy_reg;

always_comb begin
    state_next = STATE_IDLE;

    count_next = count_reg;

    axis_tx_next = axis_tx_reg;
    axis_tx_valid_next = axis_tx_valid_reg && !axis_tx.tready;

    axis_rx_ready_next = 1'b0;

    addr_next = addr_reg;
    data_next = data_reg;

    m_axil_awvalid_next = m_axil_awvalid_reg && !m_axil_wr.awready;
    m_axil_wstrb_next = m_axil_wstrb_reg;
    m_axil_wvalid_next = m_axil_wvalid_reg && !m_axil_wr.wready;
    m_axil_bready_next = 1'b0;
    m_axil_arvalid_next = m_axil_arvalid_reg && !m_axil_rd.arready;
    m_axil_rready_next = 1'b0;

    case (state_reg)
        STATE_IDLE: begin
            // idle, wait for I2C interface

            if (axis_rx.tvalid) begin
                // store address and write
                count_next = 8'(ADDR_WORD_W-1);
                state_next = STATE_ADDRESS;
            end else if (axis_tx.tready && !axis_tx_valid_reg) begin
                // read
                m_axil_arvalid_next = 1'b1;
                m_axil_rready_next = 1'b1;
                state_next = STATE_READ_1;
            end
        end
        STATE_ADDRESS: begin
            // store address
            axis_rx_ready_next = 1'b1;

            if (axis_rx_ready_reg && axis_rx.tvalid) begin
                // store pointers
                addr_next[8*count_reg +: 8] = axis_rx.tdata;
                count_next = count_reg - 1;
                if (count_reg == 0) begin
                    // end of header
                    // set initial word offset
                    if (ADDR_W == VALID_ADDR_W && WORD_PART_ADDR_W == 0) begin
                        count_next = '0;
                    end else begin
                        count_next = 8'(addr_next[ADDR_W_ADJ-VALID_ADDR_W-1:0]);
                    end
                    m_axil_wstrb_next = 'd0;
                    data_next = 'd0;
                    if (axis_rx.tlast) begin
                        // end of transaction
                        state_next = STATE_IDLE;
                    end else begin
                        // start writing
                        state_next = STATE_WRITE_1;
                    end
                end else begin
                    if (axis_rx.tlast) begin
                        // end of transaction
                        state_next = STATE_IDLE;
                    end else begin
                        state_next = STATE_ADDRESS;
                    end
                end
            end else begin
                state_next = STATE_ADDRESS;
            end
        end
        STATE_READ_1: begin
            // wait for data
            m_axil_rready_next = 1'b1;

            if (m_axil_rd.rready && m_axil_rd.rvalid) begin
                // read cycle complete, store result
                m_axil_rready_next = 1'b0;
                data_next = m_axil_rd.rdata;
                addr_next = addr_reg + (1 << (ADDR_W-VALID_ADDR_W+WORD_PART_ADDR_W));
                state_next = STATE_READ_2;
            end else begin
                state_next = STATE_READ_1;
            end
        end
        STATE_READ_2: begin
            // send data
            if (axis_rx.tvalid || !bus_addressed) begin
                // no longer addressed or now addressed for write, return to idle
                state_next = STATE_IDLE;
            end else if (axis_tx.tready && !axis_tx_valid_reg) begin
                // transfer word and update pointers
                axis_tx_next = data_reg[8*count_reg +: 8];
                axis_tx_valid_next = 1'b1;
                count_next = count_reg + 1;
                if (count_reg == 8'((STRB_W*BYTE_SIZE/8)-1)) begin
                    // end of stored data word; return to idle
                    count_next = 0;
                    state_next = STATE_IDLE;
                end else begin
                    state_next = STATE_READ_2;
                end
            end else begin
                state_next = STATE_READ_2;
            end
        end
        STATE_WRITE_1: begin
            // write data
            axis_rx_ready_next = 1'b1;

            if (axis_rx_ready_reg && axis_rx.tvalid) begin
                // store word
                data_next[8*count_reg +: 8] = axis_rx.tdata;
                count_next = count_reg + 1;
                m_axil_wstrb_next[count_reg >> ((BYTE_SIZE/8)-1)] = 1'b1;
                if (count_reg == 8'((STRB_W*BYTE_SIZE/8)-1) || axis_rx.tlast) begin
                    // have full word or at end of block, start write operation
                    count_next = 0;
                    m_axil_awvalid_next = 1'b1;
                    m_axil_wvalid_next = 1'b1;
                    m_axil_bready_next = 1'b1;
                    state_next = STATE_WRITE_2;
                end else begin
                    state_next = STATE_WRITE_1;
                end
            end else begin
                state_next = STATE_WRITE_1;
            end
        end
        STATE_WRITE_2: begin
            // wait for write completion
            m_axil_bready_next = 1'b1;

            if (m_axil_wr.bready && m_axil_wr.bvalid) begin
                // end of write operation
                data_next = 'd0;
                addr_next = addr_reg + (1 << (ADDR_W-VALID_ADDR_W+WORD_PART_ADDR_W));
                m_axil_bready_next = 1'b0;
                m_axil_wstrb_next = 'd0;
                if (last_cycle_reg) begin
                    // end of transaction
                    state_next = STATE_IDLE;
                end else begin
                    state_next = STATE_WRITE_1;
                end
            end else begin
                state_next = STATE_WRITE_2;
            end
        end
        default: begin
            // invalid state - return to idle
            state_next = STATE_IDLE;
        end
    endcase
end

always_ff @(posedge clk) begin
    state_reg <= state_next;

    count_reg <= count_next;

    if (axis_rx_ready_reg & axis_rx.tvalid) begin
        last_cycle_reg <= axis_rx.tlast;
    end

    addr_reg <= addr_next;
    data_reg <= data_next;

    m_axil_awvalid_reg <= m_axil_awvalid_next;
    m_axil_wstrb_reg <= m_axil_wstrb_next;
    m_axil_wvalid_reg <= m_axil_wvalid_next;
    m_axil_bready_reg <= m_axil_bready_next;
    m_axil_arvalid_reg <= m_axil_arvalid_next;
    m_axil_rready_reg <= m_axil_rready_next;

    busy_reg <= state_next != STATE_IDLE;

    axis_tx_reg <= axis_tx_next;
    axis_tx_valid_reg <= axis_tx_valid_next;

    axis_rx_ready_reg <= axis_rx_ready_next;

    if (rst) begin
        state_reg <= STATE_IDLE;
        axis_tx_valid_reg <= 1'b0;
        axis_rx_ready_reg <= 1'b0;
        m_axil_awvalid_reg <= 1'b0;
        m_axil_wvalid_reg <= 1'b0;
        m_axil_bready_reg <= 1'b0;
        m_axil_arvalid_reg <= 1'b0;
        m_axil_rready_reg <= 1'b0;
        busy_reg <= 1'b0;
    end
end

taxi_i2c_slave #(
    .FILTER_LEN(FILTER_LEN)
)
i2c_slave_inst (
    .clk(clk),
    .rst(rst),

    // Host interface
    .release_bus(1'b0),
    .s_axis_tx(axis_tx),
    .m_axis_rx(axis_rx),

    // I2C Interface
    .scl_i(i2c_scl_i),
    .scl_o(i2c_scl_o),
    .sda_i(i2c_sda_i),
    .sda_o(i2c_sda_o),

    // Status
    .busy(),
    .bus_address(bus_address),
    .bus_addressed(bus_addressed),
    .bus_active(bus_active),

    // Configuration
    .enable(enable),
    .device_address(device_address),
    .device_address_mask(7'h7f)
);

endmodule

`resetall
