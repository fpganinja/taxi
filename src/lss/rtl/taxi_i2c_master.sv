// SPDX-License-Identifier: CERN-OHL-S-2.0
/*

Copyright (c) 2015-2025 FPGA Ninja, LLC

Authors:
- Alex Forencich

*/

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * I2C master
 */
module taxi_i2c_master (
    input  wire logic         clk,
    input  wire logic         rst,

    /*
     * Host interface
     */
    taxi_axis_if.snk          s_axis_cmd,
    taxi_axis_if.snk          s_axis_tx,
    taxi_axis_if.src          m_axis_rx,

    /*
     * I2C interface
     */
    input  wire logic         scl_i,
    output wire logic         scl_o,
    input  wire logic         sda_i,
    output wire logic         sda_o,

    /*
     * Status
     */
    output wire logic         busy,
    output wire logic         bus_control,
    output wire logic         bus_active,
    output wire logic         missed_ack,

    /*
     * Configuration
     */
    input  wire logic [15:0]  prescale,
    input  wire logic         stop_on_idle
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

Command encoding:

    cmd[6:0] address
    cmd[7]   start
    cmd[8]   read
    cmd[9]   write
    cmd[10]  write_multiple
    cmd[11]  stop

Commands:

read
    read data byte
    set start to force generation of a start condition
    start is implied when bus is inactive or active with write or different address
    set stop to issue a stop condition after reading current byte
    if stop is set with read command, then m_axis_rx.tlast will be set

write
    write data byte
    set start to force generation of a start condition
    start is implied when bus is inactive or active with read or different address
    set stop to issue a stop condition after writing current byte

write multiple
    write multiple data bytes (until s_axis_tx.tlast)
    set start to force generation of a start condition
    start is implied when bus is inactive or active with read or different address
    set stop to issue a stop condition after writing block

stop
    issue stop condition if bus is active

Status:

busy
    module is communicating over the bus

bus_control
    module has control of bus in active state

bus_active
    bus is active, not necessarily controlled by this module

missed_ack
    strobed when a slave ack is missed

Parameters:

prescale
    set prescale to 1/4 of the minimum clock period in units
    of input clk cycles (prescale = Fclk / (FI2Cclk * 4))

stop_on_idle
    automatically issue stop when command input is not valid

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

// check configuration
if (s_axis_cmd.DATA_W < 12)
    $fatal(0, "Command interface width must be at least 12 bits (instance %m)");

if (s_axis_tx.DATA_W != 8 || m_axis_rx.DATA_W != 8)
    $fatal(0, "Data interface width must be 8 bits (instance %m)");

typedef enum logic [3:0] {
    STATE_IDLE,
    STATE_ACTIVE_WRITE,
    STATE_ACTIVE_READ,
    STATE_START_WAIT,
    STATE_START,
    STATE_ADDRESS_1,
    STATE_ADDRESS_2,
    STATE_WRITE_1,
    STATE_WRITE_2,
    STATE_WRITE_3,
    STATE_READ,
    STATE_STOP
} state_t;

state_t state_reg = STATE_IDLE, state_next;

typedef enum logic [3:0] {
    PHY_STATE_IDLE,
    PHY_STATE_ACTIVE,
    PHY_STATE_REPEATED_START_1,
    PHY_STATE_REPEATED_START_2,
    PHY_STATE_START_1,
    PHY_STATE_START_2,
    PHY_STATE_WRITE_BIT_1,
    PHY_STATE_WRITE_BIT_2,
    PHY_STATE_WRITE_BIT_3,
    PHY_STATE_READ_BIT_1,
    PHY_STATE_READ_BIT_2,
    PHY_STATE_READ_BIT_3,
    PHY_STATE_STOP_1,
    PHY_STATE_STOP_2,
    PHY_STATE_STOP_3
} phy_state_t;

phy_state_t phy_state_reg = PHY_STATE_IDLE, phy_state_next;

logic phy_start_bit;
logic phy_stop_bit;
logic phy_write_bit;
logic phy_read_bit;
logic phy_release_bus;

logic phy_tx_data;

logic phy_ready_reg = 1'b0, phy_ready_next;
logic phy_rx_data_reg = 1'b0, phy_rx_data_next;

logic [6:0] addr_reg = '0, addr_next;
logic [7:0] data_reg = '0, data_next;
logic last_reg = 1'b0, last_next;

logic mode_read_reg = 1'b0, mode_read_next;
logic mode_write_multiple_reg = 1'b0, mode_write_multiple_next;
logic mode_stop_reg = 1'b0, mode_stop_next;

logic [15:0] delay_count_reg = '0, delay_count_next;
logic delay_run_reg = 1'b0, delay_run_next;
logic delay_scl_reg = 1'b0, delay_scl_next;
logic delay_sda_reg = 1'b0, delay_sda_next;

logic [3:0] bit_count_reg = '0, bit_count_next;

logic s_axis_cmd_ready_reg = 1'b0, s_axis_cmd_ready_next;

logic s_axis_tx_tready_reg = 1'b0, s_axis_tx_tready_next;

logic [7:0] m_axis_rx_tdata_reg = '0, m_axis_rx_tdata_next;
logic m_axis_rx_tvalid_reg = 1'b0, m_axis_rx_tvalid_next;
logic m_axis_rx_tlast_reg = 1'b0, m_axis_rx_tlast_next;

logic scl_i_reg = 1'b1;
logic sda_i_reg = 1'b1;

logic scl_o_reg = 1'b1, scl_o_next;
logic sda_o_reg = 1'b1, sda_o_next;

logic last_scl_i_reg = 1'b1;
logic last_sda_i_reg = 1'b1;

logic busy_reg = 1'b0;
logic bus_active_reg = 1'b0;
logic bus_control_reg = 1'b0, bus_control_next;
logic missed_ack_reg = 1'b0, missed_ack_next;

wire [6:0]  s_axis_cmd_address = s_axis_cmd.tdata[6:0];
wire        s_axis_cmd_start = s_axis_cmd.tdata[7];
wire        s_axis_cmd_read = s_axis_cmd.tdata[8];
wire        s_axis_cmd_write = s_axis_cmd.tdata[9];
wire        s_axis_cmd_write_multi = s_axis_cmd.tdata[10];
wire        s_axis_cmd_stop = s_axis_cmd.tdata[11];

assign s_axis_cmd.tready = s_axis_cmd_ready_reg;

assign s_axis_tx.tready = s_axis_tx_tready_reg;

assign m_axis_rx.tdata = m_axis_rx_tdata_reg;
assign m_axis_rx.tkeep = '1;
assign m_axis_rx.tstrb = m_axis_rx.tkeep;
assign m_axis_rx.tvalid = m_axis_rx_tvalid_reg;
assign m_axis_rx.tlast = m_axis_rx_tlast_reg;
assign m_axis_rx.tid = '0;
assign m_axis_rx.tdest = '0;
assign m_axis_rx.tuser = '0;

assign scl_o = scl_o_reg;
assign sda_o = sda_o_reg;

assign busy = busy_reg;
assign bus_active = bus_active_reg;
assign bus_control = bus_control_reg;
assign missed_ack = missed_ack_reg;

wire scl_posedge = scl_i_reg && !last_scl_i_reg;
wire scl_negedge = !scl_i_reg && last_scl_i_reg;
wire sda_posedge = sda_i_reg && !last_sda_i_reg;
wire sda_negedge = !sda_i_reg && last_sda_i_reg;

wire start_bit = sda_negedge && scl_i_reg;
wire stop_bit = sda_posedge && scl_i_reg;

always_comb begin
    state_next = STATE_IDLE;

    phy_start_bit = 1'b0;
    phy_stop_bit = 1'b0;
    phy_write_bit = 1'b0;
    phy_read_bit = 1'b0;
    phy_tx_data = 1'b0;
    phy_release_bus = 1'b0;

    addr_next = addr_reg;
    data_next = data_reg;
    last_next = last_reg;

    mode_read_next = mode_read_reg;
    mode_write_multiple_next = mode_write_multiple_reg;
    mode_stop_next = mode_stop_reg;

    bit_count_next = bit_count_reg;

    s_axis_cmd_ready_next = 1'b0;

    s_axis_tx_tready_next = 1'b0;

    m_axis_rx_tdata_next = m_axis_rx_tdata_reg;
    m_axis_rx_tvalid_next = m_axis_rx_tvalid_reg && !m_axis_rx.tready;
    m_axis_rx_tlast_next = m_axis_rx_tlast_reg;

    missed_ack_next = 1'b0;

    // generate delays
    if (!phy_ready_reg) begin
        // wait for phy operation
        state_next = state_reg;
    end else begin
        // process states
        case (state_reg)
            STATE_IDLE: begin
                // line idle
                s_axis_cmd_ready_next = 1'b1;

                if (s_axis_cmd.tready && s_axis_cmd.tvalid) begin
                    // command valid
                    if (s_axis_cmd_read ^ (s_axis_cmd_write || s_axis_cmd_write_multi)) begin
                        // read or write command
                        addr_next = s_axis_cmd_address;
                        mode_read_next = s_axis_cmd_read;
                        mode_write_multiple_next = s_axis_cmd_write_multi;
                        mode_stop_next = s_axis_cmd_stop;

                        s_axis_cmd_ready_next = 1'b0;

                        // start bit
                        if (bus_active) begin
                            state_next = STATE_START_WAIT;
                        end else begin
                            phy_start_bit = 1'b1;
                            bit_count_next = 4'd8;
                            state_next = STATE_ADDRESS_1;
                        end
                    end else begin
                        // invalid or unspecified - ignore
                        state_next = STATE_IDLE;
                    end
                end else begin
                    state_next = STATE_IDLE;
                end
            end
            STATE_ACTIVE_WRITE: begin
                // line active with current address and read/write mode
                s_axis_cmd_ready_next = 1'b1;

                if (s_axis_cmd.tready && s_axis_cmd.tvalid) begin
                    // command valid
                    s_axis_cmd_ready_next = 1'b0;

                    if (s_axis_cmd_read ^ (s_axis_cmd_write || s_axis_cmd_write_multi)) begin
                        // read or write command
                        addr_next = s_axis_cmd_address;
                        mode_read_next = s_axis_cmd_read;
                        mode_write_multiple_next = s_axis_cmd_write_multi;
                        mode_stop_next = s_axis_cmd_stop;

                        if (s_axis_cmd_start || s_axis_cmd_address != addr_reg || s_axis_cmd_read) begin
                            // address or mode mismatch or forced start - repeated start

                            // repeated start bit
                            phy_start_bit = 1'b1;
                            bit_count_next = 4'd8;
                            state_next = STATE_ADDRESS_1;
                        end else begin
                            // address and mode match

                            // start write
                            s_axis_tx_tready_next = 1'b1;
                            state_next = STATE_WRITE_1;
                        end
                    end else if (s_axis_cmd_stop && !(s_axis_cmd_read || s_axis_cmd_write || s_axis_cmd_write_multi)) begin
                        // stop command
                        phy_stop_bit = 1'b1;
                        state_next = STATE_IDLE;
                    end else begin
                        // invalid or unspecified - ignore
                        state_next = STATE_ACTIVE_WRITE;
                    end
                end else begin
                    if (stop_on_idle && s_axis_cmd.tready && !s_axis_cmd.tvalid) begin
                        // no waiting command and stop_on_idle selected, issue stop condition
                        s_axis_cmd_ready_next = 1'b0;
                        phy_stop_bit = 1'b1;
                        state_next = STATE_IDLE;
                    end else begin
                        state_next = STATE_ACTIVE_WRITE;
                    end
                end
            end
            STATE_ACTIVE_READ: begin
                // line active to current address
                s_axis_cmd_ready_next = !m_axis_rx.tvalid;

                if (s_axis_cmd.tready && s_axis_cmd.tvalid) begin
                    // command valid
                    s_axis_cmd_ready_next = 1'b0;

                    if (s_axis_cmd_read ^ (s_axis_cmd_write || s_axis_cmd_write_multi)) begin
                        // read or write command
                        addr_next = s_axis_cmd_address;
                        mode_read_next = s_axis_cmd_read;
                        mode_write_multiple_next = s_axis_cmd_write_multi;
                        mode_stop_next = s_axis_cmd_stop;

                        if (s_axis_cmd_start || s_axis_cmd_address != addr_reg || s_axis_cmd_write) begin
                            // address or mode mismatch or forced start - repeated start

                            // write nack for previous read
                            phy_write_bit = 1'b1;
                            phy_tx_data = 1'b1;
                            // repeated start bit
                            state_next = STATE_START;
                        end else begin
                            // address and mode match

                            // write ack for previous read
                            phy_write_bit = 1'b1;
                            phy_tx_data = 1'b0;
                            // start next read
                            bit_count_next = 4'd8;
                            data_next = 8'd0;
                            state_next = STATE_READ;
                        end
                    end else if (s_axis_cmd_stop && !(s_axis_cmd_read || s_axis_cmd_write || s_axis_cmd_write_multi)) begin
                        // stop command
                        // write nack for previous read
                        phy_write_bit = 1'b1;
                        phy_tx_data = 1'b1;
                        // send stop bit
                        state_next = STATE_STOP;
                    end else begin
                        // invalid or unspecified - ignore
                        state_next = STATE_ACTIVE_READ;
                    end
                end else begin
                    if (stop_on_idle && s_axis_cmd.tready && !s_axis_cmd.tvalid) begin
                        // no waiting command and stop_on_idle selected, issue stop condition
                        s_axis_cmd_ready_next = 1'b0;
                        // write ack for previous read
                        phy_write_bit = 1'b1;
                        phy_tx_data = 1'b1;
                        // send stop bit
                        state_next = STATE_STOP;
                    end else begin
                        state_next = STATE_ACTIVE_READ;
                    end
                end
            end
            STATE_START_WAIT: begin
                // wait for bus idle

                if (bus_active) begin
                    state_next = STATE_START_WAIT;
                end else begin
                    // bus is idle, take control
                    phy_start_bit = 1'b1;
                    bit_count_next = 4'd8;
                    state_next = STATE_ADDRESS_1;
                end
            end
            STATE_START: begin
                // send start bit

                phy_start_bit = 1'b1;
                bit_count_next = 4'd8;
                state_next = STATE_ADDRESS_1;
            end
            STATE_ADDRESS_1: begin
                // send address
                bit_count_next = bit_count_reg - 1;
                if (bit_count_reg > 1) begin
                    // send address
                    phy_write_bit = 1'b1;
                    phy_tx_data = addr_reg[bit_count_reg-2];
                    state_next = STATE_ADDRESS_1;
                end else if (bit_count_reg != 0) begin
                    // send read/write bit
                    phy_write_bit = 1'b1;
                    phy_tx_data = mode_read_reg;
                    state_next = STATE_ADDRESS_1;
                end else begin
                    // read ack bit
                    phy_read_bit = 1'b1;
                    state_next = STATE_ADDRESS_2;
                end
            end
            STATE_ADDRESS_2: begin
                // read ack bit
                missed_ack_next = phy_rx_data_reg;

                if (mode_read_reg) begin
                    // start read
                    bit_count_next = 4'd8;
                    state_next = STATE_READ;
                end else begin
                    // start write
                    s_axis_tx_tready_next = 1'b1;
                    state_next = STATE_WRITE_1;
                end
            end
            STATE_WRITE_1: begin
                s_axis_tx_tready_next = 1'b1;

                if (s_axis_tx.tready && s_axis_tx.tvalid) begin
                    // got data, start write
                    data_next = s_axis_tx.tdata;
                    last_next = s_axis_tx.tlast;
                    bit_count_next = 4'd8;
                    s_axis_tx_tready_next = 1'b0;
                    state_next = STATE_WRITE_2;
                end else begin
                    // wait for data
                    state_next = STATE_WRITE_1;
                end
            end
            STATE_WRITE_2: begin
                // send data
                bit_count_next = bit_count_reg - 1;
                if (bit_count_reg != 0) begin
                    // write data bit
                    phy_write_bit = 1'b1;
                    phy_tx_data = data_reg[bit_count_reg-1];
                    state_next = STATE_WRITE_2;
                end else begin
                    // read ack bit
                    phy_read_bit = 1'b1;
                    state_next = STATE_WRITE_3;
                end
            end
            STATE_WRITE_3: begin
                // read ack bit
                missed_ack_next = phy_rx_data_reg;

                if (mode_write_multiple_reg && !last_reg) begin
                    // more to write
                    state_next = STATE_WRITE_1;
                end else if (mode_stop_reg) begin
                    // last cycle and stop selected
                    phy_stop_bit = 1'b1;
                    state_next = STATE_IDLE;
                end else begin
                    // otherwise, return to bus active state
                    state_next = STATE_ACTIVE_WRITE;
                end
            end
            STATE_READ: begin
                // read data

                bit_count_next = bit_count_reg - 1;
                data_next = {data_reg[6:0], phy_rx_data_reg};
                if (bit_count_reg != 0) begin
                    // read next bit
                    phy_read_bit = 1'b1;
                    state_next = STATE_READ;
                end else begin
                    // output data word
                    m_axis_rx_tdata_next = data_next;
                    m_axis_rx_tvalid_next = 1'b1;
                    m_axis_rx_tlast_next = 1'b0;
                    if (mode_stop_reg) begin
                        // send nack and stop
                        m_axis_rx_tlast_next = 1'b1;
                        phy_write_bit = 1'b1;
                        phy_tx_data = 1'b1;
                        state_next = STATE_STOP;
                    end else begin
                        // return to bus active state
                        state_next = STATE_ACTIVE_READ;
                    end
                end
            end
            STATE_STOP: begin
                // send stop bit
                phy_stop_bit = 1'b1;
                state_next = STATE_IDLE;
            end
            default: begin
                state_next = STATE_IDLE;
            end
        endcase
    end
end

always_comb begin
    phy_state_next = PHY_STATE_IDLE;

    phy_ready_next = 1'b0;
    phy_rx_data_next = phy_rx_data_reg;

    delay_count_next = delay_count_reg;
    delay_run_next = delay_run_reg;
    delay_scl_next = delay_scl_reg;
    delay_sda_next = delay_sda_reg;

    scl_o_next = scl_o_reg;
    sda_o_next = sda_o_reg;

    bus_control_next = bus_control_reg;

    if (delay_scl_reg) begin
        // wait for SCL to match command
        delay_scl_next = scl_o_reg && !scl_i_reg;
    end else if (delay_sda_reg) begin
        // wait for SDA to match command
        delay_sda_next = sda_o_reg && !sda_i_reg;
    end else if (delay_run_reg) begin
        // time delay
        if (delay_count_reg != 0) begin
            delay_count_next = delay_count_reg - 1;
        end else begin
            delay_run_next = 1'b0;
        end
    end else begin
        delay_count_next = prescale;
    end

    if (phy_release_bus) begin
        // release bus and return to idle state
        sda_o_next = 1'b1;
        scl_o_next = 1'b1;
        delay_scl_next = 1'b0;
        delay_sda_next = 1'b0;
        delay_run_next = '0;
        phy_state_next = PHY_STATE_IDLE;
    end else if (delay_scl_reg) begin
        // wait for SCL to match command
        phy_state_next = phy_state_reg;
    end else if (delay_sda_reg) begin
        // wait for SDA to match command
        phy_state_next = phy_state_reg;
    end else if (delay_run_reg) begin
        // time delay
        phy_state_next = phy_state_reg;
    end else begin
        case (phy_state_reg)
            PHY_STATE_IDLE: begin
                // bus idle - wait for start command
                phy_ready_next = 1'b1;
                sda_o_next = 1'b1;
                scl_o_next = 1'b1;
                if (phy_start_bit && phy_ready_reg) begin
                    phy_ready_next = 1'b0;
                    sda_o_next = 1'b0;
                    delay_run_next = 1'b1;
                    phy_state_next = PHY_STATE_START_1;
                end else begin
                    phy_state_next = PHY_STATE_IDLE;
                end
            end
            PHY_STATE_ACTIVE: begin
                // bus active
                phy_ready_next = 1'b1;
                if (phy_start_bit && phy_ready_reg) begin
                    phy_ready_next = 1'b0;
                    sda_o_next = 1'b1;
                    delay_run_next = 1'b1;
                    phy_state_next = PHY_STATE_REPEATED_START_1;
                end else if (phy_write_bit && phy_ready_reg) begin
                    phy_ready_next = 1'b0;
                    sda_o_next = phy_tx_data;
                    delay_run_next = 1'b1;
                    phy_state_next = PHY_STATE_WRITE_BIT_1;
                end else if (phy_read_bit && phy_ready_reg) begin
                    phy_ready_next = 1'b0;
                    sda_o_next = 1'b1;
                    delay_run_next = 1'b1;
                    phy_state_next = PHY_STATE_READ_BIT_1;
                end else if (phy_stop_bit && phy_ready_reg) begin
                    phy_ready_next = 1'b0;
                    sda_o_next = 1'b0;
                    delay_run_next = 1'b1;
                    phy_state_next = PHY_STATE_STOP_1;
                end else begin
                    phy_state_next = PHY_STATE_ACTIVE;
                end
            end
            PHY_STATE_REPEATED_START_1: begin
                // generate repeated start bit
                //         ______
                // sda XXX/      \_______
                //            _______
                // scl ______/       \___
                //

                scl_o_next = 1'b1;
                delay_scl_next = 1'b1;
                delay_run_next = 1'b1;
                phy_state_next = PHY_STATE_REPEATED_START_2;
            end
            PHY_STATE_REPEATED_START_2: begin
                // generate repeated start bit
                //         ______
                // sda XXX/      \_______
                //            _______
                // scl ______/       \___
                //

                sda_o_next = 1'b0;
                delay_run_next = 1'b1;
                phy_state_next = PHY_STATE_START_1;
            end
            PHY_STATE_START_1: begin
                // generate start bit
                //     ___
                // sda    \_______
                //     _______
                // scl        \___
                //

                scl_o_next = 1'b0;
                delay_run_next = 1'b1;
                phy_state_next = PHY_STATE_START_2;
            end
            PHY_STATE_START_2: begin
                // generate start bit
                //     ___
                // sda    \_______
                //     _______
                // scl        \___
                //

                bus_control_next = 1'b1;
                phy_state_next = PHY_STATE_ACTIVE;
            end
            PHY_STATE_WRITE_BIT_1: begin
                // write bit
                //      ________
                // sda X________X
                //        ____
                // scl __/    \__

                scl_o_next = 1'b1;
                delay_scl_next = 1'b1;
                delay_run_next = 1'b1;
                phy_state_next = PHY_STATE_WRITE_BIT_2;
            end
            PHY_STATE_WRITE_BIT_2: begin
                // write bit
                //      ________
                // sda X________X
                //        ____
                // scl __/    \__

                delay_run_next = 1'b1;
                phy_state_next = PHY_STATE_WRITE_BIT_3;
            end
            PHY_STATE_WRITE_BIT_3: begin
                // write bit
                //      ________
                // sda X________X
                //        ____
                // scl __/    \__

                scl_o_next = 1'b0;
                delay_run_next = 1'b1;
                phy_state_next = PHY_STATE_ACTIVE;
            end
            PHY_STATE_READ_BIT_1: begin
                // read bit
                //      ________
                // sda X________X
                //        ____
                // scl __/    \__

                scl_o_next = 1'b1;
                delay_scl_next = 1'b1;
                delay_run_next = 1'b1;
                phy_state_next = PHY_STATE_READ_BIT_2;
            end
            PHY_STATE_READ_BIT_2: begin
                // read bit
                //      ________
                // sda X________X
                //        ____
                // scl __/    \__

                phy_rx_data_next = sda_i_reg;
                delay_run_next = 1'b1;
                phy_state_next = PHY_STATE_READ_BIT_3;
            end
            PHY_STATE_READ_BIT_3: begin
                // read bit
                //      ________
                // sda X________X
                //        ____
                // scl __/    \__

                scl_o_next = 1'b0;
                delay_run_next = 1'b1;
                phy_state_next = PHY_STATE_ACTIVE;
            end
            PHY_STATE_STOP_1: begin
                // stop bit
                //                 ___
                // sda XXX\_______/
                //             _______
                // scl _______/

                scl_o_next = 1'b1;
                delay_scl_next = 1'b1;
                delay_run_next = 1'b1;
                phy_state_next = PHY_STATE_STOP_2;
            end
            PHY_STATE_STOP_2: begin
                // stop bit
                //                 ___
                // sda XXX\_______/
                //             _______
                // scl _______/

                sda_o_next = 1'b1;
                delay_run_next = 1'b1;
                phy_state_next = PHY_STATE_STOP_3;
            end
            PHY_STATE_STOP_3: begin
                // stop bit
                //                 ___
                // sda XXX\_______/
                //             _______
                // scl _______/

                bus_control_next = 1'b0;
                phy_state_next = PHY_STATE_IDLE;
            end
            default: begin
                phy_state_next = PHY_STATE_IDLE;
            end
        endcase
    end
end

always_ff @(posedge clk) begin
    state_reg <= state_next;
    phy_state_reg <= phy_state_next;

    phy_ready_reg <= phy_ready_next;
    phy_rx_data_reg <= phy_rx_data_next;

    addr_reg <= addr_next;
    data_reg <= data_next;
    last_reg <= last_next;

    mode_read_reg <= mode_read_next;
    mode_write_multiple_reg <= mode_write_multiple_next;
    mode_stop_reg <= mode_stop_next;

    delay_count_reg <= delay_count_next;
    delay_run_reg <= delay_run_next;
    delay_scl_reg <= delay_scl_next;
    delay_sda_reg <= delay_sda_next;

    bit_count_reg <= bit_count_next;

    s_axis_cmd_ready_reg <= s_axis_cmd_ready_next;

    s_axis_tx_tready_reg <= s_axis_tx_tready_next;

    m_axis_rx_tdata_reg <= m_axis_rx_tdata_next;
    m_axis_rx_tlast_reg <= m_axis_rx_tlast_next;
    m_axis_rx_tvalid_reg <= m_axis_rx_tvalid_next;

    scl_i_reg <= scl_i;
    sda_i_reg <= sda_i;

    scl_o_reg <= scl_o_next;
    sda_o_reg <= sda_o_next;

    last_scl_i_reg <= scl_i_reg;
    last_sda_i_reg <= sda_i_reg;

    busy_reg <= !(state_reg == STATE_IDLE || state_reg == STATE_ACTIVE_WRITE || state_reg == STATE_ACTIVE_READ) || !phy_ready_reg;

    if (start_bit) begin
        bus_active_reg <= 1'b1;
    end else if (stop_bit) begin
        bus_active_reg <= 1'b0;
    end else begin
        bus_active_reg <= bus_active_reg;
    end

    bus_control_reg <= bus_control_next;
    missed_ack_reg <= missed_ack_next;

    if (rst) begin
        state_reg <= STATE_IDLE;
        phy_state_reg <= PHY_STATE_IDLE;
        delay_count_reg <= '0;
        delay_run_reg <= 1'b0;
        delay_scl_reg <= 1'b0;
        delay_sda_reg <= 1'b0;
        s_axis_cmd_ready_reg <= 1'b0;
        s_axis_tx_tready_reg <= 1'b0;
        m_axis_rx_tvalid_reg <= 1'b0;
        scl_o_reg <= 1'b1;
        sda_o_reg <= 1'b1;
        busy_reg <= 1'b0;
        bus_active_reg <= 1'b0;
        bus_control_reg <= 1'b0;
        missed_ack_reg <= 1'b0;
    end
end

endmodule

`resetall
