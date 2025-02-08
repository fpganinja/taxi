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
 * AXI4-Stream 10GBASE-R frame receiver (10GBASE-R in, AXI out)
 */
module taxi_axis_baser_rx_64 #
(
    parameter DATA_W = 64,
    parameter HDR_W = 2,
    parameter logic PTP_TS_EN = 1'b0,
    parameter logic PTP_TS_FMT_TOD = 1'b1,
    parameter PTP_TS_W = PTP_TS_FMT_TOD ? 96 : 64
)
(
    input  wire logic                 clk,
    input  wire logic                 rst,

    /*
     * 10GBASE-R encoded input
     */
    input  wire logic [DATA_W-1:0]    encoded_rx_data,
    input  wire logic [HDR_W-1:0]     encoded_rx_hdr,

    /*
     * Receive interface (AXI stream)
     */
    taxi_axis_if.src                  m_axis_rx,

    /*
     * PTP
     */
    input  wire logic [PTP_TS_W-1:0]  ptp_ts,

    /*
     * Configuration
     */
    input  wire logic                 cfg_rx_enable,

    /*
     * Status
     */
    output wire logic [1:0]           start_packet,
    output wire logic                 error_bad_frame,
    output wire logic                 error_bad_fcs,
    output wire logic                 rx_bad_block,
    output wire logic                 rx_sequence_error
);

localparam KEEP_W = DATA_W/8;
localparam USER_W = (PTP_TS_EN ? PTP_TS_W : 0) + 1;

// check configuration
if (DATA_W != 64)
    $fatal(0, "Error: Interface width must be 64 (instance %m)");

if (KEEP_W*8 != DATA_W)
    $fatal(0, "Error: Interface requires byte (8-bit) granularity (instance %m)");

if (HDR_W != 2)
    $fatal(0, "Error: HDR_W must be 2 (instance %m)");

if (m_axis_rx.DATA_W != DATA_W)
    $fatal(0, "Error: Interface DATA_W parameter mismatch (instance %m)");

if (m_axis_rx.USER_W != USER_W)
    $fatal(0, "Error: Interface USER_W parameter mismatch (instance %m)");

localparam [7:0]
    ETH_PRE = 8'h55,
    ETH_SFD = 8'hD5;

localparam [7:0]
    XGMII_IDLE = 8'h07,
    XGMII_START = 8'hfb,
    XGMII_TERM = 8'hfd,
    XGMII_ERROR = 8'hfe;

localparam [6:0]
    CTRL_IDLE  = 7'h00,
    CTRL_LPI   = 7'h06,
    CTRL_ERROR = 7'h1e,
    CTRL_RES_0 = 7'h2d,
    CTRL_RES_1 = 7'h33,
    CTRL_RES_2 = 7'h4b,
    CTRL_RES_3 = 7'h55,
    CTRL_RES_4 = 7'h66,
    CTRL_RES_5 = 7'h78;

localparam [3:0]
    O_SEQ_OS = 4'h0,
    O_SIG_OS = 4'hf;

localparam [1:0]
    SYNC_DATA = 2'b10,
    SYNC_CTRL = 2'b01;

localparam [7:0]
    BLOCK_TYPE_CTRL     = 8'h1e, // C7 C6 C5 C4 C3 C2 C1 C0 BT
    BLOCK_TYPE_OS_4     = 8'h2d, // D7 D6 D5 O4 C3 C2 C1 C0 BT
    BLOCK_TYPE_START_4  = 8'h33, // D7 D6 D5    C3 C2 C1 C0 BT
    BLOCK_TYPE_OS_START = 8'h66, // D7 D6 D5    O0 D3 D2 D1 BT
    BLOCK_TYPE_OS_04    = 8'h55, // D7 D6 D5 O4 O0 D3 D2 D1 BT
    BLOCK_TYPE_START_0  = 8'h78, // D7 D6 D5 D4 D3 D2 D1    BT
    BLOCK_TYPE_OS_0     = 8'h4b, // C7 C6 C5 C4 O0 D3 D2 D1 BT
    BLOCK_TYPE_TERM_0   = 8'h87, // C7 C6 C5 C4 C3 C2 C1    BT
    BLOCK_TYPE_TERM_1   = 8'h99, // C7 C6 C5 C4 C3 C2    D0 BT
    BLOCK_TYPE_TERM_2   = 8'haa, // C7 C6 C5 C4 C3    D1 D0 BT
    BLOCK_TYPE_TERM_3   = 8'hb4, // C7 C6 C5 C4    D2 D1 D0 BT
    BLOCK_TYPE_TERM_4   = 8'hcc, // C7 C6 C5    D3 D2 D1 D0 BT
    BLOCK_TYPE_TERM_5   = 8'hd2, // C7 C6    D4 D3 D2 D1 D0 BT
    BLOCK_TYPE_TERM_6   = 8'he1, // C7    D5 D4 D3 D2 D1 D0 BT
    BLOCK_TYPE_TERM_7   = 8'hff; //    D6 D5 D4 D3 D2 D1 D0 BT

localparam [3:0]
    INPUT_TYPE_IDLE = 4'd0,
    INPUT_TYPE_ERROR = 4'd1,
    INPUT_TYPE_START_0 = 4'd2,
    INPUT_TYPE_START_4 = 4'd3,
    INPUT_TYPE_DATA = 4'd4,
    INPUT_TYPE_TERM_0 = 4'd8,
    INPUT_TYPE_TERM_1 = 4'd9,
    INPUT_TYPE_TERM_2 = 4'd10,
    INPUT_TYPE_TERM_3 = 4'd11,
    INPUT_TYPE_TERM_4 = 4'd12,
    INPUT_TYPE_TERM_5 = 4'd13,
    INPUT_TYPE_TERM_6 = 4'd14,
    INPUT_TYPE_TERM_7 = 4'd15;

localparam [1:0]
    STATE_IDLE = 2'd0,
    STATE_PAYLOAD = 2'd1,
    STATE_LAST = 2'd2;

logic [1:0] state_reg = STATE_IDLE, state_next;

// datapath control signals
logic reset_crc;

logic lanes_swapped = 1'b0;
logic [31:0] swap_data = 32'd0;

logic delay_type_valid = 1'b0;
logic [3:0] delay_type = INPUT_TYPE_IDLE;

logic [DATA_W-1:0] input_data_d0 = '0;
logic [DATA_W-1:0] input_data_d1 = '0;

logic [3:0] input_type_d0 = INPUT_TYPE_IDLE;
logic [3:0] input_type_d1 = INPUT_TYPE_IDLE;

logic [DATA_W-1:0] m_axis_rx_tdata_reg = '0, m_axis_rx_tdata_next;
logic [KEEP_W-1:0] m_axis_rx_tkeep_reg = '0, m_axis_rx_tkeep_next;
logic m_axis_rx_tvalid_reg = 1'b0, m_axis_rx_tvalid_next;
logic m_axis_rx_tlast_reg = 1'b0, m_axis_rx_tlast_next;
logic m_axis_rx_tuser_reg = 1'b0, m_axis_rx_tuser_next;

logic [1:0] start_packet_reg = 2'b00;
logic error_bad_frame_reg = 1'b0, error_bad_frame_next;
logic error_bad_fcs_reg = 1'b0, error_bad_fcs_next;
logic rx_bad_block_reg = 1'b0;
logic rx_sequence_error_reg = 1'b0;

logic [PTP_TS_W-1:0] ptp_ts_reg = '0;
logic [PTP_TS_W-1:0] ptp_ts_out_reg = '0, ptp_ts_out_next;
logic [PTP_TS_W-1:0] ptp_ts_adj_reg = '0;
logic ptp_ts_borrow_reg = '0;

logic [31:0] crc_state = '1;

wire [31:0] crc_next;

wire [7:0] crc_valid;
logic [7:0] crc_valid_save;

assign crc_valid[7] = crc_next == ~32'h2144df1c;
assign crc_valid[6] = crc_next == ~32'hc622f71d;
assign crc_valid[5] = crc_next == ~32'hb1c2a1a3;
assign crc_valid[4] = crc_next == ~32'h9d6cdf7e;
assign crc_valid[3] = crc_next == ~32'h6522df69;
assign crc_valid[2] = crc_next == ~32'he60914ae;
assign crc_valid[1] = crc_next == ~32'he38a6876;
assign crc_valid[0] = crc_next == ~32'h6b87b1ec;

logic [4+16-1:0] last_ts_reg = '0;
logic [4+16-1:0] ts_inc_reg = '0;

assign m_axis_rx.tdata = m_axis_rx_tdata_reg;
assign m_axis_rx.tkeep = m_axis_rx_tkeep_reg;
assign m_axis_rx.tstrb = m_axis_rx.tkeep;
assign m_axis_rx.tvalid = m_axis_rx_tvalid_reg;
assign m_axis_rx.tlast = m_axis_rx_tlast_reg;
assign m_axis_rx.tid = '0;
assign m_axis_rx.tdest = '0;
assign m_axis_rx.tuser[0] = m_axis_rx_tuser_reg;
if (PTP_TS_EN) begin
    assign m_axis_rx.tuser[1 +: PTP_TS_W] = ptp_ts_out_reg;
end

assign start_packet = start_packet_reg;
assign error_bad_frame = error_bad_frame_reg;
assign error_bad_fcs = error_bad_fcs_reg;
assign rx_bad_block = rx_bad_block_reg;
assign rx_sequence_error = rx_sequence_error_reg;

taxi_lfsr #(
    .LFSR_W(32),
    .LFSR_POLY(32'h4c11db7),
    .LFSR_GALOIS(1),
    .LFSR_FEED_FORWARD(0),
    .REVERSE(1),
    .DATA_W(64)
)
eth_crc (
    .data_in(input_data_d0),
    .state_in(crc_state),
    .data_out(),
    .state_out(crc_next)
);

// Mask input data
logic [DATA_W-1:0] encoded_rx_data_masked;

always_comb begin
    // minimal checks of control info to simplify datapath logic, full checks performed later
    encoded_rx_data_masked = encoded_rx_data;
    if (encoded_rx_hdr[0] == 0) begin
        // data
        encoded_rx_data_masked = encoded_rx_data;
    end else if (encoded_rx_data[7]) begin
        // terminate
        case (encoded_rx_data[6:4])
            3'd0: encoded_rx_data_masked = 64'd0;
            3'd1: encoded_rx_data_masked = {56'd0, encoded_rx_data[15:8]};
            3'd2: encoded_rx_data_masked = {48'd0, encoded_rx_data[23:8]};
            3'd3: encoded_rx_data_masked = {40'd0, encoded_rx_data[31:8]};
            3'd4: encoded_rx_data_masked = {32'd0, encoded_rx_data[39:8]};
            3'd5: encoded_rx_data_masked = {24'd0, encoded_rx_data[47:8]};
            3'd6: encoded_rx_data_masked = {16'd0, encoded_rx_data[55:8]};
            3'd7: encoded_rx_data_masked = {8'd0, encoded_rx_data[63:8]};
        endcase
    end else begin
        // start, OS, etc.
        encoded_rx_data_masked = encoded_rx_data;
    end
end

always_comb begin
    state_next = STATE_IDLE;

    reset_crc = 1'b0;

    m_axis_rx_tdata_next = input_data_d1;
    m_axis_rx_tkeep_next = 8'd0;
    m_axis_rx_tvalid_next = 1'b0;
    m_axis_rx_tlast_next = 1'b0;
    m_axis_rx_tuser_next = m_axis_rx_tuser_reg;
    m_axis_rx_tuser_next = 1'b0;

    ptp_ts_out_next = ptp_ts_out_reg;

    error_bad_frame_next = 1'b0;
    error_bad_fcs_next = 1'b0;

    case (state_reg)
        STATE_IDLE: begin
            // idle state - wait for packet
            reset_crc = 1'b1;

            if (input_type_d1 == INPUT_TYPE_START_0 && cfg_rx_enable) begin
                // start condition
                reset_crc = 1'b0;
                state_next = STATE_PAYLOAD;
            end else begin
                state_next = STATE_IDLE;
            end
        end
        STATE_PAYLOAD: begin
            // read payload
            m_axis_rx_tdata_next = input_data_d1;
            m_axis_rx_tkeep_next = 8'hff;
            m_axis_rx_tvalid_next = 1'b1;
            m_axis_rx_tlast_next = 1'b0;
            m_axis_rx_tuser_next = 1'b0;

            if (input_type_d0[3]) begin
                // INPUT_TYPE_TERM_*
                reset_crc = 1'b1;
            end

            if (PTP_TS_EN) begin
                ptp_ts_out_next = (!PTP_TS_FMT_TOD || ptp_ts_borrow_reg) ? ptp_ts_reg : ptp_ts_adj_reg;
            end

            if (input_type_d0 == INPUT_TYPE_DATA) begin
                state_next = STATE_PAYLOAD;
            end else if (input_type_d0[3]) begin
                // INPUT_TYPE_TERM_*
                if (input_type_d0 <= INPUT_TYPE_TERM_4) begin
                    // end this cycle
                    case (input_type_d0)
                        INPUT_TYPE_TERM_0: m_axis_rx_tkeep_next = 8'b00001111;
                        INPUT_TYPE_TERM_1: m_axis_rx_tkeep_next = 8'b00011111;
                        INPUT_TYPE_TERM_2: m_axis_rx_tkeep_next = 8'b00111111;
                        INPUT_TYPE_TERM_3: m_axis_rx_tkeep_next = 8'b01111111;
                        INPUT_TYPE_TERM_4: m_axis_rx_tkeep_next = 8'b11111111;
                        default:           m_axis_rx_tkeep_next = 8'b11111111;
                    endcase
                    m_axis_rx_tlast_next = 1'b1;
                    if ((input_type_d0 == INPUT_TYPE_TERM_0 && crc_valid_save[7]) ||
                        (input_type_d0 == INPUT_TYPE_TERM_1 && crc_valid[0]) ||
                        (input_type_d0 == INPUT_TYPE_TERM_2 && crc_valid[1]) ||
                        (input_type_d0 == INPUT_TYPE_TERM_3 && crc_valid[2]) ||
                        (input_type_d0 == INPUT_TYPE_TERM_4 && crc_valid[3])) begin
                        // CRC valid
                    end else begin
                        m_axis_rx_tuser_next = 1'b1;
                        error_bad_frame_next = 1'b1;
                        error_bad_fcs_next = 1'b1;
                    end
                    state_next = STATE_IDLE;
                end else begin
                    // need extra cycle
                    state_next = STATE_LAST;
                end
            end else begin
                // control or error characters in packet
                m_axis_rx_tlast_next = 1'b1;
                m_axis_rx_tuser_next = 1'b1;
                error_bad_frame_next = 1'b1;
                reset_crc = 1'b1;
                state_next = STATE_IDLE;
            end
        end
        STATE_LAST: begin
            // last cycle of packet
            m_axis_rx_tdata_next = input_data_d1;
            m_axis_rx_tkeep_next = 8'hff;
            m_axis_rx_tvalid_next = 1'b1;
            m_axis_rx_tlast_next = 1'b1;
            m_axis_rx_tuser_next = 1'b0;

            reset_crc = 1'b1;

            case (input_type_d1)
                INPUT_TYPE_TERM_5: m_axis_rx_tkeep_next = 8'b00000001;
                INPUT_TYPE_TERM_6: m_axis_rx_tkeep_next = 8'b00000011;
                INPUT_TYPE_TERM_7: m_axis_rx_tkeep_next = 8'b00000111;
                default:           m_axis_rx_tkeep_next = 8'b00000111;
            endcase

            if ((input_type_d1 == INPUT_TYPE_TERM_5 && crc_valid_save[4]) ||
                (input_type_d1 == INPUT_TYPE_TERM_6 && crc_valid_save[5]) ||
                (input_type_d1 == INPUT_TYPE_TERM_7 && crc_valid_save[6])) begin
                // CRC valid
            end else begin
                m_axis_rx_tuser_next = 1'b1;
                error_bad_frame_next = 1'b1;
                error_bad_fcs_next = 1'b1;
            end

            state_next = STATE_IDLE;
        end
        default: begin
            // invalid state, return to idle
            state_next = STATE_IDLE;
        end
    endcase
end

always_ff @(posedge clk) begin
    state_reg <= state_next;

    m_axis_rx_tdata_reg <= m_axis_rx_tdata_next;
    m_axis_rx_tkeep_reg <= m_axis_rx_tkeep_next;
    m_axis_rx_tvalid_reg <= m_axis_rx_tvalid_next;
    m_axis_rx_tlast_reg <= m_axis_rx_tlast_next;
    m_axis_rx_tuser_reg <= m_axis_rx_tuser_next;

    ptp_ts_out_reg <= ptp_ts_out_next;

    start_packet_reg <= 2'b00;
    error_bad_frame_reg <= error_bad_frame_next;
    error_bad_fcs_reg <= error_bad_fcs_next;
    rx_bad_block_reg <= 1'b0;
    rx_sequence_error_reg <= 1'b0;

    delay_type_valid <= 1'b0;

    swap_data <= encoded_rx_data_masked[63:32];

    if (PTP_TS_EN && PTP_TS_FMT_TOD) begin
        // ns field rollover
        ptp_ts_adj_reg[15:0] <= ptp_ts_reg[15:0];
        {ptp_ts_borrow_reg, ptp_ts_adj_reg[45:16]} <= $signed({1'b0, ptp_ts_reg[45:16]}) - $signed(31'd1000000000);
        ptp_ts_adj_reg[47:46] <= 0;
        ptp_ts_adj_reg[95:48] <= ptp_ts_reg[95:48] + 1;
    end

    if (encoded_rx_hdr == SYNC_CTRL && encoded_rx_data[7:0] == BLOCK_TYPE_START_0) begin
        lanes_swapped <= 1'b0;
        input_type_d0 <= INPUT_TYPE_START_0;
        input_data_d0 <= encoded_rx_data_masked;
    end else if (encoded_rx_hdr == SYNC_CTRL && (encoded_rx_data[7:0] == BLOCK_TYPE_START_4 || encoded_rx_data[7:0] == BLOCK_TYPE_OS_START)) begin
        lanes_swapped <= 1'b1;
        delay_type_valid <= 1'b1;

        if (delay_type_valid) begin
            input_type_d0 <= delay_type;
        end else begin
            input_type_d0 <= INPUT_TYPE_IDLE;
        end
        input_data_d0 <= {encoded_rx_data_masked[31:0], swap_data};
    end else if (lanes_swapped) begin
        if (delay_type_valid) begin
            input_type_d0 <= delay_type;
        end else if (encoded_rx_hdr == SYNC_DATA) begin
            input_type_d0 <= INPUT_TYPE_DATA;
        end else if (encoded_rx_hdr == SYNC_CTRL) begin
            case (encoded_rx_data[7:0])
                BLOCK_TYPE_TERM_0: input_type_d0 <= INPUT_TYPE_TERM_4;
                BLOCK_TYPE_TERM_1: input_type_d0 <= INPUT_TYPE_TERM_5;
                BLOCK_TYPE_TERM_2: input_type_d0 <= INPUT_TYPE_TERM_6;
                BLOCK_TYPE_TERM_3: input_type_d0 <= INPUT_TYPE_TERM_7;
                BLOCK_TYPE_TERM_4: begin
                    delay_type_valid <= 1'b1;
                    input_type_d0 <= INPUT_TYPE_DATA;
                end
                BLOCK_TYPE_TERM_5: begin
                    delay_type_valid <= 1'b1;
                    input_type_d0 <= INPUT_TYPE_DATA;
                end
                BLOCK_TYPE_TERM_6: begin
                    delay_type_valid <= 1'b1;
                    input_type_d0 <= INPUT_TYPE_DATA;
                end
                BLOCK_TYPE_TERM_7: begin
                    delay_type_valid <= 1'b1;
                    input_type_d0 <= INPUT_TYPE_DATA;
                end
                default: begin
                    rx_bad_block_reg <= 1'b1;
                    input_type_d0 <= INPUT_TYPE_ERROR;
                end
            endcase
        end else begin
            rx_bad_block_reg <= 1'b1;
            input_type_d0 <= INPUT_TYPE_ERROR;
        end
        if (delay_type_valid) begin
            // mask off trailing data
            input_data_d0 <= {32'd0, swap_data};
        end else begin
            input_data_d0 <= {encoded_rx_data_masked[31:0], swap_data};
        end
    end else begin
        if (encoded_rx_hdr == SYNC_DATA) begin
            input_type_d0 <= INPUT_TYPE_DATA;
        end else if (encoded_rx_hdr == SYNC_CTRL) begin
            case (encoded_rx_data[7:0])
                BLOCK_TYPE_TERM_0: input_type_d0 <= INPUT_TYPE_TERM_0;
                BLOCK_TYPE_TERM_1: input_type_d0 <= INPUT_TYPE_TERM_1;
                BLOCK_TYPE_TERM_2: input_type_d0 <= INPUT_TYPE_TERM_2;
                BLOCK_TYPE_TERM_3: input_type_d0 <= INPUT_TYPE_TERM_3;
                BLOCK_TYPE_TERM_4: input_type_d0 <= INPUT_TYPE_TERM_4;
                BLOCK_TYPE_TERM_5: input_type_d0 <= INPUT_TYPE_TERM_5;
                BLOCK_TYPE_TERM_6: input_type_d0 <= INPUT_TYPE_TERM_6;
                BLOCK_TYPE_TERM_7: input_type_d0 <= INPUT_TYPE_TERM_7;
                default: begin
                    rx_bad_block_reg <= 1'b1;
                    input_type_d0 <= INPUT_TYPE_ERROR;
                end
            endcase
        end else begin
            rx_bad_block_reg <= 1'b1;
            input_type_d0 <= INPUT_TYPE_ERROR;
        end
        input_data_d0 <= encoded_rx_data_masked;
    end

    if (encoded_rx_hdr == SYNC_DATA) begin
        delay_type <= INPUT_TYPE_DATA;
    end else if (encoded_rx_hdr == SYNC_CTRL) begin
        case (encoded_rx_data[7:0])
            BLOCK_TYPE_START_4: delay_type <= INPUT_TYPE_START_0;
            BLOCK_TYPE_TERM_0: delay_type <= INPUT_TYPE_TERM_4;
            BLOCK_TYPE_TERM_1: delay_type <= INPUT_TYPE_TERM_5;
            BLOCK_TYPE_TERM_2: delay_type <= INPUT_TYPE_TERM_6;
            BLOCK_TYPE_TERM_3: delay_type <= INPUT_TYPE_TERM_7;
            BLOCK_TYPE_TERM_4: delay_type <= INPUT_TYPE_TERM_0;
            BLOCK_TYPE_TERM_5: delay_type <= INPUT_TYPE_TERM_1;
            BLOCK_TYPE_TERM_6: delay_type <= INPUT_TYPE_TERM_2;
            BLOCK_TYPE_TERM_7: delay_type <= INPUT_TYPE_TERM_3;
            default: delay_type <= INPUT_TYPE_ERROR;
        endcase
    end else begin
        delay_type <= INPUT_TYPE_ERROR;
    end

    if (delay_type == INPUT_TYPE_START_0 && delay_type_valid) begin
        start_packet_reg <= 2'b10;
        if (PTP_TS_FMT_TOD) begin
            ptp_ts_reg[45:0] <= ptp_ts[45:0] + 46'(ts_inc_reg >> 1);
            ptp_ts_reg[95:48] <= ptp_ts[95:48];
        end else begin
            ptp_ts_reg <= ptp_ts + PTP_TS_W'(ts_inc_reg >> 1);
        end
    end

    if (input_type_d0 == INPUT_TYPE_START_0) begin
        if (!lanes_swapped) begin
            start_packet_reg <= 2'b01;
            ptp_ts_reg <= ptp_ts;
        end
    end

    input_type_d1 <= input_type_d0;
    input_data_d1 <= input_data_d0;

    if (reset_crc) begin
        crc_state <= '1;
    end else begin
        crc_state <= crc_next;
    end

    crc_valid_save <= crc_valid;

    last_ts_reg <= (4+16)'(ptp_ts);
    ts_inc_reg <= (4+16)'(ptp_ts) - last_ts_reg;

    if (rst) begin
        state_reg <= STATE_IDLE;

        m_axis_rx_tvalid_reg <= 1'b0;

        start_packet_reg <= 2'b00;
        error_bad_frame_reg <= 1'b0;
        error_bad_fcs_reg <= 1'b0;
        rx_bad_block_reg <= 1'b0;
        rx_sequence_error_reg <= 1'b0;

        input_type_d0 <= INPUT_TYPE_IDLE;
        input_type_d1 <= INPUT_TYPE_IDLE;

        lanes_swapped <= 1'b0;

        delay_type_valid <= 1'b0;
        delay_type <= INPUT_TYPE_IDLE;
    end
end

endmodule

`resetall
