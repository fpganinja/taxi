// SPDX-License-Identifier: CERN-OHL-S-2.0
/*

Copyright (c) 2026 FPGA Ninja, LLC

Authors:
- Alex Forencich

*/

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * APB to AXI4 lite adapter
 */
module taxi_apb_axil_adapter
(
    input  wire logic    clk,
    input  wire logic    rst,

    /*
     * APB slave interface
     */
    taxi_apb_if.slv      s_apb,

    /*
     * AXI4-Lite master interface
     */
    taxi_axil_if.wr_mst  m_axil_wr,
    taxi_axil_if.rd_mst  m_axil_rd
);

// extract parameters
localparam APB_DATA_W = s_apb.DATA_W;
localparam APB_ADDR_W = s_apb.ADDR_W;
localparam APB_STRB_W = s_apb.STRB_W;
localparam logic PAUSER_EN = (m_axil_wr.AWUSER_EN || m_axil_wr.ARUSER_EN) && s_apb.PAUSER_EN;
localparam PAUSER_W = s_apb.PAUSER_W;
localparam logic PWUSER_EN = m_axil_wr.WUSER_EN && s_apb.PWUSER_EN;
localparam PWUSER_W = s_apb.PWUSER_W;
localparam logic PRUSER_EN = m_axil_rd.RUSER_EN && s_apb.PRUSER_EN;
localparam PRUSER_W = s_apb.PRUSER_W;
localparam logic PBUSER_EN = m_axil_wr.BUSER_EN && s_apb.PBUSER_EN;
localparam PBUSER_W = s_apb.PBUSER_W;

localparam AXIL_DATA_W = m_axil_rd.DATA_W;
localparam AXIL_ADDR_W = m_axil_rd.ADDR_W;
localparam AXIL_STRB_W = m_axil_rd.STRB_W;
localparam logic AWUSER_EN = m_axil_wr.AWUSER_EN && s_apb.PAUSER_EN;
localparam AWUSER_W = m_axil_wr.AWUSER_W;
localparam logic WUSER_EN = m_axil_wr.WUSER_EN && s_apb.PWUSER_EN;
localparam WUSER_W = m_axil_wr.WUSER_W;
localparam logic BUSER_EN = m_axil_wr.BUSER_EN && s_apb.PBUSER_EN;
localparam BUSER_W = m_axil_wr.BUSER_W;
localparam logic ARUSER_EN = m_axil_rd.ARUSER_EN && s_apb.PAUSER_EN;
localparam ARUSER_W = m_axil_rd.ARUSER_W;
localparam logic RUSER_EN = m_axil_rd.RUSER_EN && s_apb.PRUSER_EN;
localparam RUSER_W = m_axil_rd.RUSER_W;
localparam AUSER_W = ARUSER_W > AWUSER_W ? ARUSER_W : AWUSER_W;

localparam APB_ADDR_BIT_OFFSET = $clog2(APB_STRB_W);
localparam AXIL_ADDR_BIT_OFFSET = $clog2(AXIL_STRB_W);
localparam APB_BYTE_LANES = APB_STRB_W;
localparam AXIL_BYTE_LANES = AXIL_STRB_W;
localparam APB_BYTE_W = APB_DATA_W/APB_BYTE_LANES;
localparam AXIL_BYTE_W = AXIL_DATA_W/AXIL_BYTE_LANES;
localparam APB_ADDR_MASK = {APB_ADDR_W{1'b1}} << APB_ADDR_BIT_OFFSET;
localparam AXIL_ADDR_MASK = {AXIL_ADDR_W{1'b1}} << AXIL_ADDR_BIT_OFFSET;

// check configuration
if (APB_BYTE_W * APB_STRB_W != APB_DATA_W)
    $fatal(0, "Error: APB interface data width not evenly divisible (instance %m)");

if (AXIL_BYTE_W * AXIL_STRB_W != AXIL_DATA_W)
    $fatal(0, "Error: AXI lite interface data width not evenly divisible (instance %m)");

if (APB_BYTE_W != AXIL_BYTE_W)
    $fatal(0, "Error: byte size mismatch (instance %m)");

if (2**$clog2(APB_BYTE_LANES) != APB_BYTE_LANES)
    $fatal(0, "Error: APB interface byte lane count must be even power of two (instance %m)");

if (2**$clog2(AXIL_BYTE_LANES) != AXIL_BYTE_LANES)
    $fatal(0, "Error: AXI lite interface byte lane count must be even power of two (instance %m)");

if (m_axil_wr.DATA_W != m_axil_rd.DATA_W)
    $fatal(0, "Error: AXI interface configuration mismatch (instance %m)");

if (AXIL_BYTE_LANES == APB_BYTE_LANES) begin : bypass
    // same width; translate

    typedef enum logic [0:0] {
        STATE_IDLE,
        STATE_DATA
    } state_t;

    state_t state_reg = STATE_IDLE, state_next;

    logic s_apb_pready_reg = 1'b0, s_apb_pready_next;
    logic [APB_DATA_W-1:0] s_apb_prdata_reg = '0, s_apb_prdata_next;
    logic s_apb_pslverr_reg = 1'b0, s_apb_pslverr_next;
    logic [PRUSER_W-1:0] s_apb_pruser_reg = '0, s_apb_pruser_next;
    logic [PBUSER_W-1:0] s_apb_pbuser_reg = '0, s_apb_pbuser_next;

    logic [AXIL_ADDR_W-1:0] m_axil_addr_reg = '0, m_axil_addr_next;
    logic [2:0] m_axil_prot_reg = 3'd0, m_axil_prot_next;
    logic [AUSER_W-1:0] m_axil_auser_reg = '0, m_axil_auser_next;
    logic m_axil_awvalid_reg = 1'b0, m_axil_awvalid_next;
    logic [AXIL_DATA_W-1:0] m_axil_wdata_reg = '0, m_axil_wdata_next;
    logic [AXIL_STRB_W-1:0] m_axil_wstrb_reg = '0, m_axil_wstrb_next;
    logic [WUSER_W-1:0] m_axil_wuser_reg = '0, m_axil_wuser_next;
    logic m_axil_wvalid_reg = 1'b0, m_axil_wvalid_next;
    logic m_axil_bready_reg = 1'b0, m_axil_bready_next;
    logic m_axil_arvalid_reg = 1'b0, m_axil_arvalid_next;
    logic m_axil_rready_reg = 1'b0, m_axil_rready_next;

    assign s_apb.pready = s_apb_pready_reg;
    assign s_apb.prdata = s_apb_prdata_reg;
    assign s_apb.pslverr = s_apb_pslverr_reg;
    assign s_apb.pruser = PRUSER_EN ? s_apb_pruser_reg : '0;
    assign s_apb.pbuser = PBUSER_EN ? s_apb_pbuser_reg : '0;

    assign m_axil_wr.awaddr = m_axil_addr_reg;
    assign m_axil_wr.awprot = m_axil_prot_reg;
    assign m_axil_wr.awuser = AWUSER_EN ? m_axil_auser_reg : '0;
    assign m_axil_wr.awvalid = m_axil_awvalid_reg;
    assign m_axil_wr.wdata = m_axil_wdata_reg;
    assign m_axil_wr.wstrb = m_axil_wstrb_reg;
    assign m_axil_wr.wuser = WUSER_EN ? m_axil_wuser_reg : '0;
    assign m_axil_wr.wvalid = m_axil_wvalid_reg;
    assign m_axil_wr.bready = m_axil_bready_reg;

    assign m_axil_rd.araddr = m_axil_addr_reg;
    assign m_axil_rd.arprot = m_axil_prot_reg;
    assign m_axil_rd.aruser = ARUSER_EN ? m_axil_auser_reg : '0;
    assign m_axil_rd.arvalid = m_axil_arvalid_reg;
    assign m_axil_rd.rready = m_axil_rready_reg;

    always_comb begin
        state_next = STATE_IDLE;

        s_apb_pready_next = 1'b0;
        s_apb_prdata_next = s_apb_prdata_reg;
        s_apb_pslverr_next = s_apb_pslverr_reg;
        s_apb_pruser_next = s_apb_pruser_reg;
        s_apb_pbuser_next = s_apb_pbuser_reg;

        m_axil_addr_next = m_axil_addr_reg;
        m_axil_prot_next = m_axil_prot_reg;
        m_axil_auser_next = m_axil_auser_reg;
        m_axil_awvalid_next = m_axil_awvalid_reg && !m_axil_wr.awready;
        m_axil_wdata_next = m_axil_wdata_reg;
        m_axil_wstrb_next = m_axil_wstrb_reg;
        m_axil_wuser_next = m_axil_wuser_reg;
        m_axil_wvalid_next = m_axil_wvalid_reg && !m_axil_wr.wready;
        m_axil_bready_next = 1'b0;
        m_axil_arvalid_next = m_axil_arvalid_reg && !m_axil_rd.arready;
        m_axil_rready_next = 1'b0;

        case (state_reg)
            STATE_IDLE: begin
                m_axil_addr_next = s_apb.paddr;
                m_axil_prot_next = s_apb.pprot;
                m_axil_wdata_next = s_apb.pwdata;
                m_axil_wstrb_next = s_apb.pstrb;
                m_axil_auser_next = s_apb.pauser;
                m_axil_wuser_next = s_apb.pwuser;

                if (s_apb.psel && s_apb.penable && !s_apb.pready) begin
                    if (s_apb.pwrite) begin
                        m_axil_awvalid_next = 1'b1;
                        m_axil_wvalid_next = 1'b1;
                        m_axil_bready_next = 1'b1;
                    end else begin
                        m_axil_arvalid_next = 1'b1;
                        m_axil_rready_next = 1'b1;
                    end
                    state_next = STATE_DATA;
                end else begin
                    state_next = STATE_IDLE;
                end
            end
            STATE_DATA: begin
                if (s_apb.pwrite) begin
                    m_axil_bready_next = 1'b1;
                end else begin
                    m_axil_rready_next = 1'b1;
                end

                s_apb_pready_next = 1'b0;
                s_apb_prdata_next = m_axil_rd.rdata;
                s_apb_pslverr_next = s_apb.pwrite ? m_axil_wr.bresp[1] : m_axil_rd.rresp[1];
                s_apb_pruser_next = m_axil_rd.ruser;
                s_apb_pbuser_next = m_axil_wr.buser;

                if (s_apb.pwrite ? (m_axil_wr.bready && m_axil_wr.bvalid) : (m_axil_rd.rready && m_axil_rd.rvalid)) begin
                    m_axil_bready_next = 1'b0;
                    m_axil_rready_next = 1'b0;
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

        m_axil_addr_reg <= m_axil_addr_next;
        m_axil_prot_reg <= m_axil_prot_next;
        m_axil_auser_reg <= m_axil_auser_next;
        m_axil_awvalid_reg <= m_axil_awvalid_next;
        m_axil_wdata_reg <= m_axil_wdata_next;
        m_axil_wstrb_reg <= m_axil_wstrb_next;
        m_axil_wuser_reg <= m_axil_wuser_next;
        m_axil_wvalid_reg <= m_axil_wvalid_next;
        m_axil_bready_reg <= m_axil_bready_next;
        m_axil_arvalid_reg <= m_axil_arvalid_next;
        m_axil_rready_reg <= m_axil_rready_next;

        if (rst) begin
            state_reg <= STATE_IDLE;

            s_apb_pready_reg <= 1'b0;

            m_axil_awvalid_reg <= 1'b0;
            m_axil_wvalid_reg <= 1'b0;
            m_axil_bready_reg <= 1'b0;
            m_axil_arvalid_reg <= 1'b0;
            m_axil_rready_reg <= 1'b0;
        end
    end

end else if (AXIL_BYTE_LANES > APB_BYTE_LANES) begin : upsize
    // output is wider; upsize

    typedef enum logic [0:0] {
        STATE_IDLE,
        STATE_DATA
    } state_t;

    state_t state_reg = STATE_IDLE, state_next;

    logic s_apb_pready_reg = 1'b0, s_apb_pready_next;
    logic [APB_DATA_W-1:0] s_apb_prdata_reg = '0, s_apb_prdata_next;
    logic s_apb_pslverr_reg = 1'b0, s_apb_pslverr_next;
    logic [PRUSER_W-1:0] s_apb_pruser_reg = '0, s_apb_pruser_next;
    logic [PBUSER_W-1:0] s_apb_pbuser_reg = '0, s_apb_pbuser_next;

    logic [AXIL_ADDR_W-1:0] m_axil_addr_reg = '0, m_axil_addr_next;
    logic [2:0] m_axil_prot_reg = 3'd0, m_axil_prot_next;
    logic [AUSER_W-1:0] m_axil_auser_reg = '0, m_axil_auser_next;
    logic m_axil_awvalid_reg = 1'b0, m_axil_awvalid_next;
    logic [AXIL_DATA_W-1:0] m_axil_wdata_reg = '0, m_axil_wdata_next;
    logic [AXIL_STRB_W-1:0] m_axil_wstrb_reg = '0, m_axil_wstrb_next;
    logic [WUSER_W-1:0] m_axil_wuser_reg = '0, m_axil_wuser_next;
    logic m_axil_wvalid_reg = 1'b0, m_axil_wvalid_next;
    logic m_axil_bready_reg = 1'b0, m_axil_bready_next;
    logic m_axil_arvalid_reg = 1'b0, m_axil_arvalid_next;
    logic m_axil_rready_reg = 1'b0, m_axil_rready_next;

    assign s_apb.pready = s_apb_pready_reg;
    assign s_apb.prdata = s_apb_prdata_reg;
    assign s_apb.pslverr = s_apb_pslverr_reg;
    assign s_apb.pruser = PRUSER_EN ? s_apb_pruser_reg : '0;
    assign s_apb.pbuser = PBUSER_EN ? s_apb_pbuser_reg : '0;

    assign m_axil_wr.awaddr = m_axil_addr_reg;
    assign m_axil_wr.awprot = m_axil_prot_reg;
    assign m_axil_wr.awuser = AWUSER_EN ? m_axil_auser_reg : '0;
    assign m_axil_wr.awvalid = m_axil_awvalid_reg;
    assign m_axil_wr.wdata = m_axil_wdata_reg;
    assign m_axil_wr.wstrb = m_axil_wstrb_reg;
    assign m_axil_wr.wuser = WUSER_EN ? m_axil_wuser_reg : '0;
    assign m_axil_wr.wvalid = m_axil_wvalid_reg;
    assign m_axil_wr.bready = m_axil_bready_reg;

    assign m_axil_rd.araddr = m_axil_addr_reg;
    assign m_axil_rd.arprot = m_axil_prot_reg;
    assign m_axil_rd.aruser = ARUSER_EN ? m_axil_auser_reg : '0;
    assign m_axil_rd.arvalid = m_axil_arvalid_reg;
    assign m_axil_rd.rready = m_axil_rready_reg;

    always_comb begin
        state_next = STATE_IDLE;

        s_apb_pready_next = 1'b0;
        s_apb_prdata_next = s_apb_prdata_reg;
        s_apb_pslverr_next = s_apb_pslverr_reg;
        s_apb_pruser_next = s_apb_pruser_reg;
        s_apb_pbuser_next = s_apb_pbuser_reg;

        m_axil_addr_next = m_axil_addr_reg;
        m_axil_prot_next = m_axil_prot_reg;
        m_axil_auser_next = m_axil_auser_reg;
        m_axil_awvalid_next = m_axil_awvalid_reg && !m_axil_wr.awready;
        m_axil_wdata_next = m_axil_wdata_reg;
        m_axil_wstrb_next = m_axil_wstrb_reg;
        m_axil_wuser_next = m_axil_wuser_reg;
        m_axil_wvalid_next = m_axil_wvalid_reg && !m_axil_wr.wready;
        m_axil_bready_next = 1'b0;
        m_axil_arvalid_next = m_axil_arvalid_reg && !m_axil_rd.arready;
        m_axil_rready_next = 1'b0;

        case (state_reg)
            STATE_IDLE: begin
                m_axil_addr_next = s_apb.paddr;
                m_axil_prot_next = s_apb.pprot;
                m_axil_wdata_next = {(AXIL_BYTE_LANES/APB_BYTE_LANES){s_apb.pwdata}};
                m_axil_wstrb_next = '0;
                m_axil_wstrb_next[s_apb.paddr[AXIL_ADDR_BIT_OFFSET - 1:APB_ADDR_BIT_OFFSET] * APB_STRB_W +: APB_STRB_W] = s_apb.pstrb;
                m_axil_auser_next = s_apb.pauser;
                m_axil_wuser_next = s_apb.pwuser;

                if (s_apb.psel && s_apb.penable && !s_apb.pready) begin
                    if (s_apb.pwrite) begin
                        m_axil_awvalid_next = 1'b1;
                        m_axil_wvalid_next = 1'b1;
                        m_axil_bready_next = 1'b1;
                    end else begin
                        m_axil_arvalid_next = 1'b1;
                        m_axil_rready_next = 1'b1;
                    end
                    state_next = STATE_DATA;
                end else begin
                    state_next = STATE_IDLE;
                end
            end
            STATE_DATA: begin
                if (s_apb.pwrite) begin
                    m_axil_bready_next = 1'b1;
                end else begin
                    m_axil_rready_next = 1'b1;
                end

                s_apb_pready_next = 1'b0;
                s_apb_prdata_next = m_axil_rd.rdata[m_axil_addr_reg[AXIL_ADDR_BIT_OFFSET - 1:APB_ADDR_BIT_OFFSET] * APB_DATA_W +: APB_DATA_W];
                s_apb_pslverr_next = s_apb.pwrite ? m_axil_wr.bresp[1] : m_axil_rd.rresp[1];
                s_apb_pruser_next = m_axil_rd.ruser;
                s_apb_pbuser_next = m_axil_wr.buser;

                if (s_apb.pwrite ? (m_axil_wr.bready && m_axil_wr.bvalid) : (m_axil_rd.rready && m_axil_rd.rvalid)) begin
                    m_axil_bready_next = 1'b0;
                    m_axil_rready_next = 1'b0;
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

        m_axil_addr_reg <= m_axil_addr_next;
        m_axil_prot_reg <= m_axil_prot_next;
        m_axil_auser_reg <= m_axil_auser_next;
        m_axil_awvalid_reg <= m_axil_awvalid_next;
        m_axil_wdata_reg <= m_axil_wdata_next;
        m_axil_wstrb_reg <= m_axil_wstrb_next;
        m_axil_wuser_reg <= m_axil_wuser_next;
        m_axil_wvalid_reg <= m_axil_wvalid_next;
        m_axil_bready_reg <= m_axil_bready_next;
        m_axil_arvalid_reg <= m_axil_arvalid_next;
        m_axil_rready_reg <= m_axil_rready_next;

        if (rst) begin
            state_reg <= STATE_IDLE;

            s_apb_pready_reg <= 1'b0;

            m_axil_awvalid_reg <= 1'b0;
            m_axil_wvalid_reg <= 1'b0;
            m_axil_bready_reg <= 1'b0;
            m_axil_arvalid_reg <= 1'b0;
            m_axil_rready_reg <= 1'b0;
        end
    end

end else begin : downsize
    // output is narrower; downsize

    // output bus is wider
    localparam DATA_W = APB_DATA_W;
    localparam STRB_W = APB_STRB_W;
    // required number of segments in wider bus
    localparam SEG_COUNT = APB_BYTE_LANES / AXIL_BYTE_LANES;
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
    logic [APB_DATA_W-1:0] s_apb_prdata_reg = '0, s_apb_prdata_next;
    logic s_apb_pslverr_reg = 1'b0, s_apb_pslverr_next;
    logic [PRUSER_W-1:0] s_apb_pruser_reg = '0, s_apb_pruser_next;
    logic [PBUSER_W-1:0] s_apb_pbuser_reg = '0, s_apb_pbuser_next;

    logic [AXIL_ADDR_W-1:0] m_axil_addr_reg = '0, m_axil_addr_next;
    logic [2:0] m_axil_prot_reg = 3'd0, m_axil_prot_next;
    logic [AUSER_W-1:0] m_axil_auser_reg = '0, m_axil_auser_next;
    logic m_axil_awvalid_reg = 1'b0, m_axil_awvalid_next;
    logic [AXIL_DATA_W-1:0] m_axil_wdata_reg = '0, m_axil_wdata_next;
    logic [AXIL_STRB_W-1:0] m_axil_wstrb_reg = '0, m_axil_wstrb_next;
    logic [WUSER_W-1:0] m_axil_wuser_reg = '0, m_axil_wuser_next;
    logic m_axil_wvalid_reg = 1'b0, m_axil_wvalid_next;
    logic m_axil_bready_reg = 1'b0, m_axil_bready_next;
    logic m_axil_arvalid_reg = 1'b0, m_axil_arvalid_next;
    logic m_axil_rready_reg = 1'b0, m_axil_rready_next;

    assign s_apb.pready = s_apb_pready_reg;
    assign s_apb.prdata = s_apb_prdata_reg;
    assign s_apb.pslverr = s_apb_pslverr_reg;
    assign s_apb.pruser = PRUSER_EN ? s_apb_pruser_reg : '0;
    assign s_apb.pbuser = PBUSER_EN ? s_apb_pbuser_reg : '0;

    assign m_axil_wr.awaddr = m_axil_addr_reg;
    assign m_axil_wr.awprot = m_axil_prot_reg;
    assign m_axil_wr.awuser = AWUSER_EN ? m_axil_auser_reg : '0;
    assign m_axil_wr.awvalid = m_axil_awvalid_reg;
    assign m_axil_wr.wdata = m_axil_wdata_reg;
    assign m_axil_wr.wstrb = m_axil_wstrb_reg;
    assign m_axil_wr.wuser = WUSER_EN ? m_axil_wuser_reg : '0;
    assign m_axil_wr.wvalid = m_axil_wvalid_reg;
    assign m_axil_wr.bready = m_axil_bready_reg;

    assign m_axil_rd.araddr = m_axil_addr_reg;
    assign m_axil_rd.arprot = m_axil_prot_reg;
    assign m_axil_rd.aruser = ARUSER_EN ? m_axil_auser_reg : '0;
    assign m_axil_rd.arvalid = m_axil_arvalid_reg;
    assign m_axil_rd.rready = m_axil_rready_reg;

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

        m_axil_addr_next = m_axil_addr_reg;
        m_axil_prot_next = m_axil_prot_reg;
        m_axil_auser_next = m_axil_auser_reg;
        m_axil_awvalid_next = m_axil_awvalid_reg && !m_axil_wr.awready;
        m_axil_wdata_next = m_axil_wdata_reg;
        m_axil_wstrb_next = m_axil_wstrb_reg;
        m_axil_wuser_next = m_axil_wuser_reg;
        m_axil_wvalid_next = m_axil_wvalid_reg && !m_axil_wr.wready;
        m_axil_bready_next = 1'b0;
        m_axil_arvalid_next = m_axil_arvalid_reg && !m_axil_rd.arready;
        m_axil_rready_next = 1'b0;

        case (state_reg)
            STATE_IDLE: begin
                current_seg_next = s_apb.paddr[AXIL_ADDR_BIT_OFFSET +: SEG_COUNT_W];

                m_axil_addr_next = s_apb.paddr;
                m_axil_prot_next = s_apb.pprot;
                data_next = s_apb.pwdata;
                strb_next = s_apb.pstrb;
                m_axil_wdata_next = data_next[current_seg_next*SEG_DATA_W +: SEG_DATA_W];
                m_axil_wstrb_next = strb_next[current_seg_next*SEG_STRB_W +: SEG_STRB_W];
                m_axil_auser_next = s_apb.pauser;
                m_axil_wuser_next = s_apb.pwuser;

                s_apb_pslverr_next = 1'b0;

                if (s_apb.psel && s_apb.penable && !s_apb.pready) begin
                    if (s_apb.pwrite) begin
                        m_axil_awvalid_next = 1'b1;
                        m_axil_wvalid_next = 1'b1;
                        m_axil_bready_next = 1'b1;
                    end else begin
                        m_axil_arvalid_next = 1'b1;
                        m_axil_rready_next = 1'b1;
                    end
                    state_next = STATE_DATA;
                end else begin
                    state_next = STATE_IDLE;
                end
            end
            STATE_DATA: begin
                if (s_apb.pwrite) begin
                    m_axil_bready_next = 1'b1;
                end else begin
                    m_axil_rready_next = 1'b1;
                end

                s_apb_pready_next = 1'b0;
                s_apb_prdata_next[current_seg_reg*SEG_DATA_W +: SEG_DATA_W] = m_axil_rd.rdata;
                if (s_apb.pwrite ? m_axil_wr.bresp[1] : m_axil_rd.rresp[1]) begin
                    s_apb_pslverr_next = 1'b1;
                end
                s_apb_pruser_next = m_axil_rd.ruser;
                s_apb_pbuser_next = m_axil_wr.buser;

                if (s_apb.pwrite ? (m_axil_wr.bready && m_axil_wr.bvalid) : (m_axil_rd.rready && m_axil_rd.rvalid)) begin
                    m_axil_bready_next = 1'b0;
                    m_axil_rready_next = 1'b0;
                    current_seg_next = current_seg_reg + 1;
                    m_axil_addr_next = (m_axil_addr_reg & AXIL_ADDR_MASK) + SEG_STRB_W;
                    m_axil_wdata_next = data_next[current_seg_next*SEG_DATA_W +: SEG_DATA_W];
                    m_axil_wstrb_next = strb_next[current_seg_next*SEG_STRB_W +: SEG_STRB_W];
                    if (current_seg_reg == SEG_COUNT_W'(SEG_COUNT-1)) begin
                        s_apb_pready_next = 1'b1;
                        state_next = STATE_IDLE;
                    end else begin
                        if (s_apb.pwrite) begin
                            m_axil_awvalid_next = 1'b1;
                            m_axil_wvalid_next = 1'b1;
                            m_axil_bready_next = 1'b1;
                        end else begin
                            m_axil_arvalid_next = 1'b1;
                            m_axil_rready_next = 1'b1;
                        end
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

        m_axil_addr_reg <= m_axil_addr_next;
        m_axil_prot_reg <= m_axil_prot_next;
        m_axil_auser_reg <= m_axil_auser_next;
        m_axil_awvalid_reg <= m_axil_awvalid_next;
        m_axil_wdata_reg <= m_axil_wdata_next;
        m_axil_wstrb_reg <= m_axil_wstrb_next;
        m_axil_wuser_reg <= m_axil_wuser_next;
        m_axil_wvalid_reg <= m_axil_wvalid_next;
        m_axil_bready_reg <= m_axil_bready_next;
        m_axil_arvalid_reg <= m_axil_arvalid_next;
        m_axil_rready_reg <= m_axil_rready_next;

        if (rst) begin
            state_reg <= STATE_IDLE;

            s_apb_pready_reg <= 1'b0;

            m_axil_awvalid_reg <= 1'b0;
            m_axil_wvalid_reg <= 1'b0;
            m_axil_bready_reg <= 1'b0;
            m_axil_arvalid_reg <= 1'b0;
            m_axil_rready_reg <= 1'b0;
        end
    end

end

endmodule

`resetall
