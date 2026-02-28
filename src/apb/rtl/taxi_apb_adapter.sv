// SPDX-License-Identifier: CERN-OHL-S-2.0
/*

Copyright (c) 2025 FPGA Ninja, LLC

Authors:
- Alex Forencich

*/

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * APB width adapter
 */
module taxi_apb_adapter
(
    input  wire logic  clk,
    input  wire logic  rst,

    /*
     * APB slave interface
     */
    taxi_apb_if.slv    s_apb,

    /*
     * APB master interface
     */
    taxi_apb_if.mst    m_apb
);

// extract parameters
localparam S_DATA_W = s_apb.DATA_W;
localparam ADDR_W = s_apb.ADDR_W;
localparam S_STRB_W = s_apb.STRB_W;
localparam logic PAUSER_EN = s_apb.PAUSER_EN && m_apb.PAUSER_EN;
localparam PAUSER_W = s_apb.PAUSER_W;
localparam logic PWUSER_EN = s_apb.PWUSER_EN && m_apb.PWUSER_EN;
localparam PWUSER_W = s_apb.PWUSER_W;
localparam logic PRUSER_EN = s_apb.PRUSER_EN && m_apb.PRUSER_EN;
localparam PRUSER_W = s_apb.PRUSER_W;
localparam logic PBUSER_EN = s_apb.PBUSER_EN && m_apb.PBUSER_EN;
localparam PBUSER_W = s_apb.PBUSER_W;

localparam M_DATA_W = m_apb.DATA_W;
localparam M_STRB_W = m_apb.STRB_W;

localparam S_ADDR_BIT_OFFSET = $clog2(S_STRB_W);
localparam M_ADDR_BIT_OFFSET = $clog2(M_STRB_W);
localparam S_BYTE_LANES = S_STRB_W;
localparam M_BYTE_LANES = M_STRB_W;
localparam S_BYTE_W = S_DATA_W/S_BYTE_LANES;
localparam M_BYTE_W = M_DATA_W/M_BYTE_LANES;
localparam S_ADDR_MASK = {ADDR_W{1'b1}} << S_ADDR_BIT_OFFSET;
localparam M_ADDR_MASK = {ADDR_W{1'b1}} << M_ADDR_BIT_OFFSET;

// check configuration
if (S_BYTE_W * S_STRB_W != S_DATA_W)
    $fatal(0, "Error: APB slave interface data width not evenly divisible (instance %m)");

if (M_BYTE_W * M_STRB_W != M_DATA_W)
    $fatal(0, "Error: APB master interface data width not evenly divisible (instance %m)");

if (S_BYTE_W != M_BYTE_W)
    $fatal(0, "Error: byte size mismatch (instance %m)");

if (2**$clog2(S_BYTE_LANES) != S_BYTE_LANES)
    $fatal(0, "Error: APB slave interface byte lane count must be even power of two (instance %m)");

if (2**$clog2(M_BYTE_LANES) != M_BYTE_LANES)
    $fatal(0, "Error: APB master interface byte lane count must be even power of two (instance %m)");

if (M_BYTE_LANES == S_BYTE_LANES) begin : bypass
    // same width; bypass

    assign m_apb.paddr = s_apb.paddr;
    assign m_apb.pprot = s_apb.pprot;
    assign m_apb.psel = s_apb.psel;
    assign m_apb.penable = s_apb.penable;
    assign m_apb.pwrite = s_apb.pwrite;
    assign m_apb.pwdata = s_apb.pwdata;
    assign m_apb.pstrb = s_apb.pstrb;
    assign s_apb.pready = m_apb.pready;
    assign s_apb.prdata = m_apb.prdata;
    assign s_apb.pslverr = m_apb.pslverr;
    assign m_apb.pauser = PAUSER_EN ? s_apb.pauser : '0;
    assign m_apb.pwuser = PWUSER_EN ? s_apb.pwuser : '0;
    assign s_apb.pruser = PRUSER_EN ? m_apb.pruser : '0;
    assign s_apb.pbuser = PBUSER_EN ? m_apb.pbuser : '0;

end else if (M_BYTE_LANES > S_BYTE_LANES) begin : upsize
    // output is wider; upsize

    typedef enum logic [0:0] {
        STATE_IDLE,
        STATE_DATA
    } state_t;

    state_t state_reg = STATE_IDLE, state_next;

    logic s_apb_pready_reg = 1'b0, s_apb_pready_next;
    logic [S_DATA_W-1:0] s_apb_prdata_reg = '0, s_apb_prdata_next;
    logic s_apb_pslverr_reg = 1'b0, s_apb_pslverr_next;
    logic [PRUSER_W-1:0] s_apb_pruser_reg = '0, s_apb_pruser_next;
    logic [PBUSER_W-1:0] s_apb_pbuser_reg = '0, s_apb_pbuser_next;

    logic [ADDR_W-1:0] m_apb_paddr_reg = '0, m_apb_paddr_next;
    logic [2:0] m_apb_pprot_reg = '0, m_apb_pprot_next;
    logic m_apb_psel_reg = 1'b0, m_apb_psel_next;
    logic m_apb_penable_reg = 1'b0, m_apb_penable_next;
    logic m_apb_pwrite_reg = 1'b0, m_apb_pwrite_next;
    logic [M_DATA_W-1:0] m_apb_pwdata_reg = '0, m_apb_pwdata_next;
    logic [M_STRB_W-1:0] m_apb_pstrb_reg = '0, m_apb_pstrb_next;
    logic [PAUSER_W-1:0] m_apb_pauser_reg = '0, m_apb_pauser_next;
    logic [PWUSER_W-1:0] m_apb_pwuser_reg = '0, m_apb_pwuser_next;

    assign s_apb.pready = s_apb_pready_reg;
    assign s_apb.prdata = s_apb_prdata_reg;
    assign s_apb.pslverr = s_apb_pslverr_reg;
    assign s_apb.pruser = PRUSER_EN ? s_apb_pruser_reg : '0;
    assign s_apb.pbuser = PBUSER_EN ? s_apb_pbuser_reg : '0;

    assign m_apb.paddr = m_apb_paddr_reg;
    assign m_apb.pprot = m_apb_pprot_reg;
    assign m_apb.psel = m_apb_psel_reg;
    assign m_apb.penable = m_apb_penable_reg;
    assign m_apb.pwrite = m_apb_pwrite_reg;
    assign m_apb.pwdata = m_apb_pwdata_reg;
    assign m_apb.pstrb = m_apb_pstrb_reg;
    assign m_apb.pauser = PAUSER_EN ? m_apb_pauser_reg : '0;
    assign m_apb.pwuser = PWUSER_EN ? m_apb_pwuser_reg : '0;

    always_comb begin
        state_next = STATE_IDLE;

        s_apb_pready_next = 1'b0;
        s_apb_prdata_next = s_apb_prdata_reg;
        s_apb_pslverr_next = s_apb_pslverr_reg;
        s_apb_pruser_next = s_apb_pruser_reg;
        s_apb_pbuser_next = s_apb_pbuser_reg;

        m_apb_paddr_next = m_apb_paddr_reg;
        m_apb_pprot_next = m_apb_pprot_reg;
        m_apb_psel_next = 1'b0;
        m_apb_penable_next = 1'b0;
        m_apb_pwrite_next = m_apb_pwrite_reg;
        m_apb_pwdata_next = m_apb_pwdata_reg;
        m_apb_pstrb_next = m_apb_pstrb_reg;
        m_apb_pauser_next = m_apb_pauser_reg;
        m_apb_pwuser_next = m_apb_pwuser_reg;

        case (state_reg)
            STATE_IDLE: begin
                m_apb_paddr_next = s_apb.paddr;
                m_apb_pprot_next = s_apb.pprot;
                m_apb_pwrite_next = s_apb.pwrite;
                m_apb_pwdata_next = {(M_BYTE_LANES/S_BYTE_LANES){s_apb.pwdata}};
                m_apb_pstrb_next = '0;
                m_apb_pstrb_next[s_apb.paddr[M_ADDR_BIT_OFFSET - 1:S_ADDR_BIT_OFFSET] * S_STRB_W +: S_STRB_W] = s_apb.pstrb;
                m_apb_pauser_next = s_apb.pauser;
                m_apb_pwuser_next = s_apb.pwuser;

                if (s_apb.psel && s_apb.penable && !s_apb.pready) begin
                    m_apb_psel_next = 1'b1;
                    state_next = STATE_DATA;
                end else begin
                    state_next = STATE_IDLE;
                end
            end
            STATE_DATA: begin
                m_apb_psel_next = 1'b1;
                m_apb_penable_next = 1'b1;

                s_apb_pready_next = 1'b0;
                s_apb_prdata_next = m_apb.prdata[m_apb_paddr_reg[M_ADDR_BIT_OFFSET - 1:S_ADDR_BIT_OFFSET] * S_DATA_W +: S_DATA_W];
                s_apb_pslverr_next = m_apb.pslverr;
                s_apb_pruser_next = m_apb.pruser;
                s_apb_pbuser_next = m_apb.pbuser;

                if (m_apb.psel && m_apb.penable && m_apb.pready) begin
                    m_apb_psel_next = 1'b0;
                    m_apb_penable_next = 1'b0;
                    s_apb_pready_next = 1'b1;
                    state_next = STATE_IDLE;
                end else begin
                    state_next = STATE_DATA;
                end
            end
        endcase
    end

    always_ff @(posedge clk) begin
        state_reg <= state_next;

        s_apb_pready_reg <= s_apb_pready_next;
        s_apb_prdata_reg <= s_apb_prdata_next;
        s_apb_pslverr_reg <= s_apb_pslverr_next;
        s_apb_pruser_reg <= s_apb_pruser_next;
        s_apb_pbuser_reg <= s_apb_pbuser_next;

        m_apb_paddr_reg <= m_apb_paddr_next;
        m_apb_pprot_reg <= m_apb_pprot_next;
        m_apb_psel_reg <= m_apb_psel_next;
        m_apb_penable_reg <= m_apb_penable_next;
        m_apb_pwrite_reg <= m_apb_pwrite_next;
        m_apb_pwdata_reg <= m_apb_pwdata_next;
        m_apb_pstrb_reg <= m_apb_pstrb_next;
        m_apb_pauser_reg <= m_apb_pauser_next;
        m_apb_pwuser_reg <= m_apb_pwuser_next;

        if (rst) begin
            state_reg <= STATE_IDLE;

            s_apb_pready_reg <= 1'b0;

            m_apb_psel_reg <= 1'b0;
            m_apb_penable_reg <= 1'b0;
        end
    end

end else begin : downsize
    // output is narrower; downsize

    // output bus is wider
    localparam DATA_W = S_DATA_W;
    localparam STRB_W = S_STRB_W;
    // required number of segments in wider bus
    localparam SEG_COUNT = S_BYTE_LANES / M_BYTE_LANES;
    localparam SEG_COUNT_W = $clog2(SEG_COUNT);
    // data width and keep width per segment
    localparam SEG_DATA_W = DATA_W / SEG_COUNT;
    localparam SEG_STRB_W = STRB_W / SEG_COUNT;

    typedef enum logic [0:0] {
        STATE_IDLE,
        STATE_DATA
    } state_t;

    state_t state_reg = STATE_IDLE, state_next;

    logic [DATA_W-1:0] data_reg = '0, data_next;
    logic [STRB_W-1:0] strb_reg = '0, strb_next;

    logic [SEG_COUNT_W-1:0] current_seg_reg = '0, current_seg_next;

    logic s_apb_pready_reg = 1'b0, s_apb_pready_next;
    logic [S_DATA_W-1:0] s_apb_prdata_reg = '0, s_apb_prdata_next;
    logic s_apb_pslverr_reg = 1'b0, s_apb_pslverr_next;
    logic [PRUSER_W-1:0] s_apb_pruser_reg = '0, s_apb_pruser_next;
    logic [PBUSER_W-1:0] s_apb_pbuser_reg = '0, s_apb_pbuser_next;

    logic [ADDR_W-1:0] m_apb_paddr_reg = '0, m_apb_paddr_next;
    logic [2:0] m_apb_pprot_reg = '0, m_apb_pprot_next;
    logic m_apb_psel_reg = 1'b0, m_apb_psel_next;
    logic m_apb_penable_reg = 1'b0, m_apb_penable_next;
    logic m_apb_pwrite_reg = 1'b0, m_apb_pwrite_next;
    logic [M_DATA_W-1:0] m_apb_pwdata_reg = '0, m_apb_pwdata_next;
    logic [M_STRB_W-1:0] m_apb_pstrb_reg = '0, m_apb_pstrb_next;
    logic [PAUSER_W-1:0] m_apb_pauser_reg = '0, m_apb_pauser_next;
    logic [PWUSER_W-1:0] m_apb_pwuser_reg = '0, m_apb_pwuser_next;

    assign s_apb.pready = s_apb_pready_reg;
    assign s_apb.prdata = s_apb_prdata_reg;
    assign s_apb.pslverr = s_apb_pslverr_reg;
    assign s_apb.pruser = PRUSER_EN ? s_apb_pruser_reg : '0;
    assign s_apb.pbuser = PBUSER_EN ? s_apb_pbuser_reg : '0;

    assign m_apb.paddr = m_apb_paddr_reg;
    assign m_apb.pprot = m_apb_pprot_reg;
    assign m_apb.psel = m_apb_psel_reg;
    assign m_apb.penable = m_apb_penable_reg;
    assign m_apb.pwrite = m_apb_pwrite_reg;
    assign m_apb.pwdata = m_apb_pwdata_reg;
    assign m_apb.pstrb = m_apb_pstrb_reg;
    assign m_apb.pauser = PAUSER_EN ? m_apb_pauser_reg : '0;
    assign m_apb.pwuser = PWUSER_EN ? m_apb_pwuser_reg : '0;

    always_comb begin
        state_next = STATE_IDLE;

        data_next = data_reg;
        strb_next = strb_reg;

        current_seg_next = current_seg_reg;

        s_apb_pready_next = 1'b0;
        s_apb_prdata_next = s_apb_prdata_reg;
        s_apb_pslverr_next = s_apb_pslverr_reg;
        s_apb_pruser_next = s_apb_pruser_reg;
        s_apb_pbuser_next = s_apb_pbuser_reg;

        m_apb_paddr_next = m_apb_paddr_reg;
        m_apb_pprot_next = m_apb_pprot_reg;
        m_apb_psel_next = 1'b0;
        m_apb_penable_next = 1'b0;
        m_apb_pwrite_next = m_apb_pwrite_reg;
        m_apb_pwdata_next = m_apb_pwdata_reg;
        m_apb_pstrb_next = m_apb_pstrb_reg;
        m_apb_pauser_next = m_apb_pauser_reg;
        m_apb_pwuser_next = m_apb_pwuser_reg;

        case (state_reg)
            STATE_IDLE: begin
                current_seg_next = s_apb.paddr[M_ADDR_BIT_OFFSET +: SEG_COUNT_W];

                m_apb_paddr_next = s_apb.paddr;
                m_apb_pprot_next = s_apb.pprot;
                m_apb_pwrite_next = s_apb.pwrite;
                data_next = s_apb.pwdata;
                strb_next = s_apb.pstrb;
                m_apb_pwdata_next = data_next[current_seg_next*SEG_DATA_W +: SEG_DATA_W];
                m_apb_pstrb_next = strb_next[current_seg_next*SEG_STRB_W +: SEG_STRB_W];
                m_apb_pauser_next = s_apb.pauser;
                m_apb_pwuser_next = s_apb.pwuser;

                s_apb_pslverr_next = 1'b0;

                if (s_apb.psel && s_apb.penable && !s_apb.pready) begin
                    m_apb_psel_next = 1'b1;
                    state_next = STATE_DATA;
                end else begin
                    state_next = STATE_IDLE;
                end
            end
            STATE_DATA: begin
                m_apb_psel_next = 1'b1;
                m_apb_penable_next = 1'b1;

                s_apb_pready_next = 1'b0;
                s_apb_prdata_next[current_seg_reg*SEG_DATA_W +: SEG_DATA_W] = m_apb.prdata;
                if (m_apb.pslverr) begin
                    s_apb_pslverr_next = 1'b1;
                end
                s_apb_pruser_next = m_apb.pruser;
                s_apb_pbuser_next = m_apb.pbuser;

                if (m_apb.psel && m_apb.penable && m_apb.pready) begin
                    m_apb_penable_next = 1'b0;
                    current_seg_next = current_seg_reg + 1;
                    m_apb_paddr_next = (m_apb_paddr_reg & M_ADDR_MASK) + SEG_STRB_W;
                    m_apb_pwdata_next = data_next[current_seg_next*SEG_DATA_W +: SEG_DATA_W];
                    m_apb_pstrb_next = strb_next[current_seg_next*SEG_STRB_W +: SEG_STRB_W];
                    if (current_seg_reg == SEG_COUNT_W'(SEG_COUNT-1)) begin
                        m_apb_psel_next = 1'b0;
                        s_apb_pready_next = 1'b1;
                        state_next = STATE_IDLE;
                    end else begin
                        state_next = STATE_DATA;
                    end
                end else begin
                    state_next = STATE_DATA;
                end
            end
        endcase
    end

    always_ff @(posedge clk) begin
        state_reg <= state_next;

        data_reg <= data_next;
        strb_reg <= strb_next;

        current_seg_reg <= current_seg_next;

        s_apb_pready_reg <= s_apb_pready_next;
        s_apb_prdata_reg <= s_apb_prdata_next;
        s_apb_pslverr_reg <= s_apb_pslverr_next;
        s_apb_pruser_reg <= s_apb_pruser_next;
        s_apb_pbuser_reg <= s_apb_pbuser_next;

        m_apb_paddr_reg <= m_apb_paddr_next;
        m_apb_pprot_reg <= m_apb_pprot_next;
        m_apb_psel_reg <= m_apb_psel_next;
        m_apb_penable_reg <= m_apb_penable_next;
        m_apb_pwrite_reg <= m_apb_pwrite_next;
        m_apb_pwdata_reg <= m_apb_pwdata_next;
        m_apb_pstrb_reg <= m_apb_pstrb_next;
        m_apb_pauser_reg <= m_apb_pauser_next;
        m_apb_pwuser_reg <= m_apb_pwuser_next;

        if (rst) begin
            state_reg <= STATE_IDLE;

            s_apb_pready_reg <= 1'b0;

            m_apb_psel_reg <= 1'b0;
            m_apb_penable_reg <= 1'b0;
        end
    end

end

endmodule

`resetall
