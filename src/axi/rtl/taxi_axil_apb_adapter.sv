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
 * AXI4 lite to APB adapter
 */
module taxi_axil_apb_adapter
(
    input  wire logic    clk,
    input  wire logic    rst,

    /*
     * AXI4-Lite slave interface
     */
    taxi_axil_if.wr_slv  s_axil_wr,
    taxi_axil_if.rd_slv  s_axil_rd,

    /*
     * APB master interface
     */
    taxi_apb_if.mst      m_apb
);

// extract parameters
localparam AXIL_DATA_W = s_axil_rd.DATA_W;
localparam AXIL_ADDR_W = s_axil_rd.ADDR_W;
localparam AXIL_STRB_W = s_axil_rd.STRB_W;
localparam logic AWUSER_EN = s_axil_wr.AWUSER_EN && m_apb.PAUSER_EN;
localparam AWUSER_W = s_axil_wr.AWUSER_W;
localparam logic WUSER_EN = s_axil_wr.WUSER_EN && m_apb.PWUSER_EN;
localparam WUSER_W = s_axil_wr.WUSER_W;
localparam logic BUSER_EN = s_axil_wr.BUSER_EN && m_apb.PBUSER_EN;
localparam BUSER_W = s_axil_wr.BUSER_W;
localparam logic ARUSER_EN = s_axil_rd.ARUSER_EN && m_apb.PAUSER_EN;
localparam ARUSER_W = s_axil_rd.ARUSER_W;
localparam logic RUSER_EN = s_axil_rd.RUSER_EN && m_apb.PRUSER_EN;
localparam RUSER_W = s_axil_rd.RUSER_W;

localparam APB_DATA_W = m_apb.DATA_W;
localparam APB_ADDR_W = m_apb.ADDR_W;
localparam APB_STRB_W = m_apb.STRB_W;
localparam logic PAUSER_EN = (s_axil_wr.AWUSER_EN || s_axil_wr.ARUSER_EN) && m_apb.PAUSER_EN;
localparam PAUSER_W = m_apb.PAUSER_W;
localparam logic PWUSER_EN = s_axil_wr.WUSER_EN && m_apb.PWUSER_EN;
localparam PWUSER_W = m_apb.PWUSER_W;
localparam logic PRUSER_EN = s_axil_rd.RUSER_EN && m_apb.PRUSER_EN;
localparam PRUSER_W = m_apb.PRUSER_W;
localparam logic PBUSER_EN = s_axil_wr.BUSER_EN && m_apb.PBUSER_EN;
localparam PBUSER_W = m_apb.PBUSER_W;

localparam AXIL_ADDR_BIT_OFFSET = $clog2(AXIL_STRB_W);
localparam APB_ADDR_BIT_OFFSET = $clog2(APB_STRB_W);
localparam AXIL_BYTE_LANES = AXIL_STRB_W;
localparam APB_BYTE_LANES = APB_STRB_W;
localparam AXIL_BYTE_W = AXIL_DATA_W/AXIL_BYTE_LANES;
localparam APB_BYTE_W = APB_DATA_W/APB_BYTE_LANES;
localparam AXIL_ADDR_MASK = {AXIL_ADDR_W{1'b1}} << AXIL_ADDR_BIT_OFFSET;
localparam APB_ADDR_MASK = {APB_ADDR_W{1'b1}} << APB_ADDR_BIT_OFFSET;

// check configuration
if (AXIL_BYTE_W * AXIL_STRB_W != AXIL_DATA_W)
    $fatal(0, "Error: AXI slave interface data width not evenly divisible (instance %m)");

if (APB_BYTE_W * APB_STRB_W != APB_DATA_W)
    $fatal(0, "Error: APB master interface data width not evenly divisible (instance %m)");

if (AXIL_BYTE_W != APB_BYTE_W)
    $fatal(0, "Error: byte size mismatch (instance %m)");

if (2**$clog2(AXIL_BYTE_LANES) != AXIL_BYTE_LANES)
    $fatal(0, "Error: AXI slave interface byte lane count must be even power of two (instance %m)");

if (2**$clog2(APB_BYTE_LANES) != APB_BYTE_LANES)
    $fatal(0, "Error: APB master interface byte lane count must be even power of two (instance %m)");

if (s_axil_wr.DATA_W != s_axil_rd.DATA_W)
    $fatal(0, "Error: AXI interface configuration mismatch (instance %m)");

localparam [1:0]
    AXI_RESP_OKAY = 2'b00,
    AXI_RESP_EXOKAY = 2'b01,
    AXI_RESP_SLVERR = 2'b10,
    AXI_RESP_DECERR = 2'b11;

if (APB_BYTE_LANES == AXIL_BYTE_LANES) begin : translate
    // same width; translate

    typedef enum logic [0:0] {
        STATE_IDLE,
        STATE_DATA
    } state_t;

    state_t state_reg = STATE_IDLE, state_next;

    logic last_read_reg = 1'b0, last_read_next;

    logic s_axil_awready_reg = 1'b0, s_axil_awready_next;
    logic s_axil_wready_reg = 1'b0, s_axil_wready_next;
    logic [BUSER_W-1:0] s_axil_buser_reg = '0, s_axil_buser_next;
    logic s_axil_bvalid_reg = 1'b0, s_axil_bvalid_next;

    logic s_axil_arready_reg = 1'b0, s_axil_arready_next;
    logic [AXIL_DATA_W-1:0] s_axil_rdata_reg = '0, s_axil_rdata_next;
    logic [RUSER_W-1:0] s_axil_ruser_reg = '0, s_axil_ruser_next;
    logic s_axil_rvalid_reg = 1'b0, s_axil_rvalid_next;

    logic [1:0] s_axil_resp_reg = '0, s_axil_resp_next;

    logic [APB_ADDR_W-1:0] m_apb_paddr_reg = '0, m_apb_paddr_next;
    logic [2:0] m_apb_pprot_reg = '0, m_apb_pprot_next;
    logic m_apb_psel_reg = 1'b0, m_apb_psel_next;
    logic m_apb_penable_reg = 1'b0, m_apb_penable_next;
    logic m_apb_pwrite_reg = 1'b0, m_apb_pwrite_next;
    logic [APB_DATA_W-1:0] m_apb_pwdata_reg = '0, m_apb_pwdata_next;
    logic [APB_STRB_W-1:0] m_apb_pstrb_reg = '0, m_apb_pstrb_next;
    logic [PAUSER_W-1:0] m_apb_pauser_reg = '0, m_apb_pauser_next;
    logic [PWUSER_W-1:0] m_apb_pwuser_reg = '0, m_apb_pwuser_next;

    assign s_axil_wr.awready = s_axil_awready_reg;
    assign s_axil_wr.wready = s_axil_wready_reg;
    assign s_axil_wr.bresp = s_axil_resp_reg;
    assign s_axil_wr.buser = BUSER_EN ? s_axil_buser_reg : '0;
    assign s_axil_wr.bvalid = s_axil_bvalid_reg;

    assign s_axil_rd.arready = s_axil_arready_reg;
    assign s_axil_rd.rdata = s_axil_rdata_reg;
    assign s_axil_rd.rresp = s_axil_resp_reg;
    assign s_axil_rd.ruser = RUSER_EN ? s_axil_ruser_reg : '0;
    assign s_axil_rd.rvalid = s_axil_rvalid_reg;

    assign m_apb.paddr = m_apb_paddr_reg;
    assign m_apb.pprot = m_apb_pprot_reg;
    assign m_apb.psel = m_apb_psel_reg;
    assign m_apb.penable = m_apb_penable_reg;
    assign m_apb.pwrite = m_apb_pwrite_reg;
    assign m_apb.pwdata = m_apb_pwdata_reg;
    assign m_apb.pstrb = m_apb_pstrb_reg;
    assign m_apb.pauser = PAUSER_EN ? m_apb_pauser_reg : '0;
    assign m_apb.pwuser = PWUSER_EN ? m_apb_pwuser_reg : '0;

    logic read_eligible;
    logic write_eligible;

    always_comb begin
        state_next = STATE_IDLE;

        last_read_next = last_read_reg;

        s_axil_awready_next = 1'b0;
        s_axil_wready_next = 1'b0;
        s_axil_buser_next = s_axil_buser_reg;
        s_axil_bvalid_next = s_axil_bvalid_reg && !s_axil_wr.bready;

        s_axil_arready_next = 1'b0;
        s_axil_rdata_next = s_axil_rdata_reg;
        s_axil_ruser_next = s_axil_ruser_reg;
        s_axil_rvalid_next = s_axil_rvalid_reg && !s_axil_rd.rready;

        s_axil_resp_next = s_axil_resp_reg;

        m_apb_paddr_next = m_apb_paddr_reg;
        m_apb_pprot_next = m_apb_pprot_reg;
        m_apb_psel_next = m_apb_psel_reg;
        m_apb_penable_next = m_apb_penable_reg;
        m_apb_pwrite_next = m_apb_pwrite_reg;
        m_apb_pwdata_next = m_apb_pwdata_reg;
        m_apb_pstrb_next = m_apb_pstrb_reg;
        m_apb_pauser_next = m_apb_pauser_reg;
        m_apb_pwuser_next = m_apb_pwuser_reg;

        write_eligible = s_axil_wr.awvalid && s_axil_wr.wvalid && (!s_axil_wr.bvalid || s_axil_wr.bready) && (!s_axil_wr.awready && !s_axil_wr.wready);
        read_eligible = s_axil_rd.arvalid && (!s_axil_rd.rvalid || s_axil_rd.rready) && (!s_axil_rd.arready);

        case (state_reg)
            STATE_IDLE: begin
                m_apb_pwdata_next = s_axil_wr.wdata;
                m_apb_pstrb_next = s_axil_wr.wstrb;
                m_apb_pwuser_next = s_axil_wr.wuser;

                if (write_eligible && (!read_eligible || last_read_reg)) begin
                    // start write
                    last_read_next = 1'b0;

                    s_axil_awready_next = 1'b1;
                    s_axil_wready_next = 1'b1;

                    m_apb_paddr_next = APB_ADDR_W'(s_axil_wr.awaddr);
                    m_apb_pprot_next = s_axil_wr.awprot;
                    m_apb_pauser_next = s_axil_wr.awuser;
                    m_apb_pwrite_next = 1'b1;
                    m_apb_psel_next = 1'b1;

                    state_next = STATE_DATA;
                end else if (read_eligible) begin
                    // start read
                    last_read_next = 1'b1;

                    s_axil_arready_next = 1'b1;

                    m_apb_paddr_next = APB_ADDR_W'(s_axil_rd.araddr);
                    m_apb_pprot_next = s_axil_rd.arprot;
                    m_apb_pauser_next = s_axil_rd.aruser;
                    m_apb_pwrite_next = 1'b0;
                    m_apb_psel_next = 1'b1;

                    state_next = STATE_DATA;
                end else begin
                    state_next = STATE_IDLE;
                end
            end
            STATE_DATA: begin
                s_axil_buser_next = m_apb.pbuser;
                s_axil_rdata_next = m_apb.prdata;
                s_axil_ruser_next = m_apb.pruser;
                s_axil_resp_next = m_apb.pslverr ? AXI_RESP_SLVERR : AXI_RESP_OKAY;

                m_apb_psel_next = 1'b1;
                m_apb_penable_next = 1'b1;

                if (m_apb.psel && m_apb.penable && m_apb.pready) begin
                    if (m_apb_pwrite_reg) begin
                        s_axil_bvalid_next = 1'b1;
                    end else begin
                        s_axil_rvalid_next = 1'b1;
                    end

                    m_apb_psel_next = 1'b0;
                    m_apb_penable_next = 1'b0;

                    state_next = STATE_IDLE;
                end else begin
                    state_next = STATE_DATA;
                end
            end
            default: begin
                state_next = STATE_IDLE;
            end
        endcase
    end

    always_ff @(posedge clk) begin
        state_reg <= state_next;

        last_read_reg <= last_read_next;

        s_axil_awready_reg <= s_axil_awready_next;
        s_axil_wready_reg <= s_axil_wready_next;
        s_axil_buser_reg <= s_axil_buser_next;
        s_axil_bvalid_reg <= s_axil_bvalid_next;

        s_axil_arready_reg <= s_axil_arready_next;
        s_axil_rdata_reg <= s_axil_rdata_next;
        s_axil_ruser_reg <= s_axil_ruser_next;
        s_axil_rvalid_reg <= s_axil_rvalid_next;

        s_axil_resp_reg <= s_axil_resp_next;

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

            last_read_reg <= 1'b0;

            s_axil_awready_reg <= 1'b0;
            s_axil_wready_reg <= 1'b0;
            s_axil_bvalid_reg <= 1'b0;
            s_axil_arready_reg <= 1'b0;
            s_axil_rvalid_reg <= 1'b0;

            m_apb_psel_reg <= 1'b0;
            m_apb_penable_reg <= 1'b0;
        end
    end

end else if (APB_BYTE_LANES > AXIL_BYTE_LANES) begin : upsize
    // output is wider; upsize

    typedef enum logic [0:0] {
        STATE_IDLE,
        STATE_DATA
    } state_t;

    state_t state_reg = STATE_IDLE, state_next;

    logic last_read_reg = 1'b0, last_read_next;

    logic s_axil_awready_reg = 1'b0, s_axil_awready_next;
    logic s_axil_wready_reg = 1'b0, s_axil_wready_next;
    logic [BUSER_W-1:0] s_axil_buser_reg = '0, s_axil_buser_next;
    logic s_axil_bvalid_reg = 1'b0, s_axil_bvalid_next;

    logic s_axil_arready_reg = 1'b0, s_axil_arready_next;
    logic [AXIL_DATA_W-1:0] s_axil_rdata_reg = '0, s_axil_rdata_next;
    logic [RUSER_W-1:0] s_axil_ruser_reg = '0, s_axil_ruser_next;
    logic s_axil_rvalid_reg = 1'b0, s_axil_rvalid_next;

    logic [1:0] s_axil_resp_reg = '0, s_axil_resp_next;

    logic [APB_ADDR_W-1:0] m_apb_paddr_reg = '0, m_apb_paddr_next;
    logic [2:0] m_apb_pprot_reg = '0, m_apb_pprot_next;
    logic m_apb_psel_reg = 1'b0, m_apb_psel_next;
    logic m_apb_penable_reg = 1'b0, m_apb_penable_next;
    logic m_apb_pwrite_reg = 1'b0, m_apb_pwrite_next;
    logic [APB_DATA_W-1:0] m_apb_pwdata_reg = '0, m_apb_pwdata_next;
    logic [APB_STRB_W-1:0] m_apb_pstrb_reg = '0, m_apb_pstrb_next;
    logic [PAUSER_W-1:0] m_apb_pauser_reg = '0, m_apb_pauser_next;
    logic [PWUSER_W-1:0] m_apb_pwuser_reg = '0, m_apb_pwuser_next;

    assign s_axil_wr.awready = s_axil_awready_reg;
    assign s_axil_wr.wready = s_axil_wready_reg;
    assign s_axil_wr.bresp = s_axil_resp_reg;
    assign s_axil_wr.buser = BUSER_EN ? s_axil_buser_reg : '0;
    assign s_axil_wr.bvalid = s_axil_bvalid_reg;

    assign s_axil_rd.arready = s_axil_arready_reg;
    assign s_axil_rd.rdata = s_axil_rdata_reg;
    assign s_axil_rd.rresp = s_axil_resp_reg;
    assign s_axil_rd.ruser = RUSER_EN ? s_axil_ruser_reg : '0;
    assign s_axil_rd.rvalid = s_axil_rvalid_reg;

    assign m_apb.paddr = m_apb_paddr_reg;
    assign m_apb.pprot = m_apb_pprot_reg;
    assign m_apb.psel = m_apb_psel_reg;
    assign m_apb.penable = m_apb_penable_reg;
    assign m_apb.pwrite = m_apb_pwrite_reg;
    assign m_apb.pwdata = m_apb_pwdata_reg;
    assign m_apb.pstrb = m_apb_pstrb_reg;
    assign m_apb.pauser = PAUSER_EN ? m_apb_pauser_reg : '0;
    assign m_apb.pwuser = PWUSER_EN ? m_apb_pwuser_reg : '0;

    logic read_eligible;
    logic write_eligible;

    always_comb begin
        state_next = STATE_IDLE;

        last_read_next = last_read_reg;

        s_axil_awready_next = 1'b0;
        s_axil_wready_next = 1'b0;
        s_axil_buser_next = s_axil_buser_reg;
        s_axil_bvalid_next = s_axil_bvalid_reg && !s_axil_wr.bready;

        s_axil_arready_next = 1'b0;
        s_axil_rdata_next = s_axil_rdata_reg;
        s_axil_ruser_next = s_axil_ruser_reg;
        s_axil_rvalid_next = s_axil_rvalid_reg && !s_axil_rd.rready;

        s_axil_resp_next = s_axil_resp_reg;

        m_apb_paddr_next = m_apb_paddr_reg;
        m_apb_pprot_next = m_apb_pprot_reg;
        m_apb_psel_next = m_apb_psel_reg;
        m_apb_penable_next = m_apb_penable_reg;
        m_apb_pwrite_next = m_apb_pwrite_reg;
        m_apb_pwdata_next = m_apb_pwdata_reg;
        m_apb_pstrb_next = m_apb_pstrb_reg;
        m_apb_pauser_next = m_apb_pauser_reg;
        m_apb_pwuser_next = m_apb_pwuser_reg;

        write_eligible = s_axil_wr.awvalid && s_axil_wr.wvalid && (!s_axil_wr.bvalid || s_axil_wr.bready) && (!s_axil_wr.awready && !s_axil_wr.wready);
        read_eligible = s_axil_rd.arvalid && (!s_axil_rd.rvalid || s_axil_rd.rready) && (!s_axil_rd.arready);

        case (state_reg)
            STATE_IDLE: begin
                m_apb_pwdata_next = {(APB_BYTE_LANES/AXIL_BYTE_LANES){s_axil_wr.wdata}};
                m_apb_pstrb_next = '0;
                m_apb_pstrb_next[s_axil_wr.awaddr[APB_ADDR_BIT_OFFSET - 1:AXIL_ADDR_BIT_OFFSET] * AXIL_STRB_W +: AXIL_STRB_W] = s_axil_wr.wstrb;
                m_apb_pwuser_next = s_axil_wr.wuser;

                if (write_eligible && (!read_eligible || last_read_reg)) begin
                    // start write
                    last_read_next = 1'b0;

                    s_axil_awready_next = 1'b1;
                    s_axil_wready_next = 1'b1;

                    m_apb_paddr_next = APB_ADDR_W'(s_axil_wr.awaddr);
                    m_apb_pprot_next = s_axil_wr.awprot;
                    m_apb_pauser_next = s_axil_wr.awuser;
                    m_apb_pwrite_next = 1'b1;
                    m_apb_psel_next = 1'b1;

                    state_next = STATE_DATA;
                end else if (read_eligible) begin
                    // start read
                    last_read_next = 1'b1;

                    s_axil_arready_next = 1'b1;

                    m_apb_paddr_next = APB_ADDR_W'(s_axil_rd.araddr);
                    m_apb_pprot_next = s_axil_rd.arprot;
                    m_apb_pauser_next = s_axil_rd.aruser;
                    m_apb_pwrite_next = 1'b0;
                    m_apb_psel_next = 1'b1;

                    state_next = STATE_DATA;
                end else begin
                    state_next = STATE_IDLE;
                end
            end
            STATE_DATA: begin
                if (m_apb_pwrite_reg) begin
                    s_axil_buser_next = m_apb.pbuser;
                end else begin
                    s_axil_rdata_next = m_apb.prdata[m_apb_paddr_reg[APB_ADDR_BIT_OFFSET - 1:AXIL_ADDR_BIT_OFFSET] * AXIL_DATA_W +: AXIL_DATA_W];
                    s_axil_ruser_next = m_apb.pruser;
                    s_axil_resp_next = m_apb.pslverr ? AXI_RESP_SLVERR : AXI_RESP_OKAY;
                end

                m_apb_psel_next = 1'b1;
                m_apb_penable_next = 1'b1;

                if (m_apb.psel && m_apb.penable && m_apb.pready) begin
                    if (m_apb_pwrite_reg) begin
                        s_axil_bvalid_next = 1'b1;
                    end else begin
                        s_axil_rvalid_next = 1'b1;
                    end

                    m_apb_psel_next = 1'b0;
                    m_apb_penable_next = 1'b0;

                    state_next = STATE_IDLE;
                end else begin
                    state_next = STATE_DATA;
                end
            end
            default: begin
                state_next = STATE_IDLE;
            end
        endcase
    end

    always_ff @(posedge clk) begin
        state_reg <= state_next;

        last_read_reg <= last_read_next;

        s_axil_awready_reg <= s_axil_awready_next;
        s_axil_wready_reg <= s_axil_wready_next;
        s_axil_buser_reg <= s_axil_buser_next;
        s_axil_bvalid_reg <= s_axil_bvalid_next;

        s_axil_arready_reg <= s_axil_arready_next;
        s_axil_rdata_reg <= s_axil_rdata_next;
        s_axil_ruser_reg <= s_axil_ruser_next;
        s_axil_rvalid_reg <= s_axil_rvalid_next;

        s_axil_resp_reg <= s_axil_resp_next;

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

            last_read_reg <= 1'b0;

            s_axil_awready_reg <= 1'b0;
            s_axil_wready_reg <= 1'b0;
            s_axil_bvalid_reg <= 1'b0;
            s_axil_arready_reg <= 1'b0;
            s_axil_rvalid_reg <= 1'b0;

            m_apb_psel_reg <= 1'b0;
            m_apb_penable_reg <= 1'b0;
        end
    end

end else begin : downsize
    // output is narrower; downsize

    // output bus is wider
    localparam DATA_W = AXIL_DATA_W;
    localparam STRB_W = AXIL_STRB_W;
    // required number of segments in wider bus
    localparam SEG_COUNT = AXIL_BYTE_LANES / APB_BYTE_LANES;
    localparam SEG_COUNT_W = $clog2(SEG_COUNT);
    // data width and keep width per segment
    localparam SEG_DATA_W = DATA_W / SEG_COUNT;
    localparam SEG_STRB_W = STRB_W / SEG_COUNT;

    typedef enum logic [0:0] {
        STATE_IDLE,
        STATE_DATA
    } state_t;

    state_t state_reg = STATE_IDLE, state_next;

    logic last_read_reg = 1'b0, last_read_next;

    logic [DATA_W-1:0] data_reg = '0, data_next;
    logic [STRB_W-1:0] strb_reg = '0, strb_next;

    logic [SEG_COUNT_W-1:0] current_seg_reg = '0, current_seg_next;

    logic s_axil_awready_reg = 1'b0, s_axil_awready_next;
    logic s_axil_wready_reg = 1'b0, s_axil_wready_next;
    logic [BUSER_W-1:0] s_axil_buser_reg = '0, s_axil_buser_next;
    logic s_axil_bvalid_reg = 1'b0, s_axil_bvalid_next;

    logic s_axil_arready_reg = 1'b0, s_axil_arready_next;
    logic [AXIL_DATA_W-1:0] s_axil_rdata_reg = '0, s_axil_rdata_next;
    logic [RUSER_W-1:0] s_axil_ruser_reg = '0, s_axil_ruser_next;
    logic s_axil_rvalid_reg = 1'b0, s_axil_rvalid_next;

    logic [1:0] s_axil_resp_reg = '0, s_axil_resp_next;

    logic [APB_ADDR_W-1:0] m_apb_paddr_reg = '0, m_apb_paddr_next;
    logic [2:0] m_apb_pprot_reg = '0, m_apb_pprot_next;
    logic m_apb_psel_reg = 1'b0, m_apb_psel_next;
    logic m_apb_penable_reg = 1'b0, m_apb_penable_next;
    logic m_apb_pwrite_reg = 1'b0, m_apb_pwrite_next;
    logic [APB_DATA_W-1:0] m_apb_pwdata_reg = '0, m_apb_pwdata_next;
    logic [APB_STRB_W-1:0] m_apb_pstrb_reg = '0, m_apb_pstrb_next;
    logic [PAUSER_W-1:0] m_apb_pauser_reg = '0, m_apb_pauser_next;
    logic [PWUSER_W-1:0] m_apb_pwuser_reg = '0, m_apb_pwuser_next;

    assign s_axil_wr.awready = s_axil_awready_reg;
    assign s_axil_wr.wready = s_axil_wready_reg;
    assign s_axil_wr.bresp = s_axil_resp_reg;
    assign s_axil_wr.buser = BUSER_EN ? s_axil_buser_reg : '0;
    assign s_axil_wr.bvalid = s_axil_bvalid_reg;

    assign s_axil_rd.arready = s_axil_arready_reg;
    assign s_axil_rd.rdata = s_axil_rdata_reg;
    assign s_axil_rd.rresp = s_axil_resp_reg;
    assign s_axil_rd.ruser = RUSER_EN ? s_axil_ruser_reg : '0;
    assign s_axil_rd.rvalid = s_axil_rvalid_reg;

    assign m_apb.paddr = m_apb_paddr_reg;
    assign m_apb.pprot = m_apb_pprot_reg;
    assign m_apb.psel = m_apb_psel_reg;
    assign m_apb.penable = m_apb_penable_reg;
    assign m_apb.pwrite = m_apb_pwrite_reg;
    assign m_apb.pwdata = m_apb_pwdata_reg;
    assign m_apb.pstrb = m_apb_pstrb_reg;
    assign m_apb.pauser = PAUSER_EN ? m_apb_pauser_reg : '0;
    assign m_apb.pwuser = PWUSER_EN ? m_apb_pwuser_reg : '0;

    logic read_eligible;
    logic write_eligible;

    always_comb begin
        state_next = STATE_IDLE;

        last_read_next = last_read_reg;

        data_next = data_reg;
        strb_next = strb_reg;

        current_seg_next = current_seg_reg;

        s_axil_awready_next = 1'b0;
        s_axil_wready_next = 1'b0;
        s_axil_buser_next = s_axil_buser_reg;
        s_axil_bvalid_next = s_axil_bvalid_reg && !s_axil_wr.bready;

        s_axil_arready_next = 1'b0;
        s_axil_rdata_next = s_axil_rdata_reg;
        s_axil_ruser_next = s_axil_ruser_reg;
        s_axil_rvalid_next = s_axil_rvalid_reg && !s_axil_rd.rready;

        s_axil_resp_next = s_axil_resp_reg;

        m_apb_paddr_next = m_apb_paddr_reg;
        m_apb_pprot_next = m_apb_pprot_reg;
        m_apb_psel_next = m_apb_psel_reg;
        m_apb_penable_next = m_apb_penable_reg;
        m_apb_pwrite_next = m_apb_pwrite_reg;
        m_apb_pwdata_next = m_apb_pwdata_reg;
        m_apb_pstrb_next = m_apb_pstrb_reg;
        m_apb_pauser_next = m_apb_pauser_reg;
        m_apb_pwuser_next = m_apb_pwuser_reg;

        write_eligible = s_axil_wr.awvalid && s_axil_wr.wvalid && (!s_axil_wr.bvalid || s_axil_wr.bready) && (!s_axil_wr.awready && !s_axil_wr.wready);
        read_eligible = s_axil_rd.arvalid && (!s_axil_rd.rvalid || s_axil_rd.rready) && (!s_axil_rd.arready);

        case (state_reg)
            STATE_IDLE: begin
                current_seg_next = s_axil_wr.awaddr[APB_ADDR_BIT_OFFSET +: SEG_COUNT_W];
                data_next = s_axil_wr.wdata;
                strb_next = s_axil_wr.wstrb;
                m_apb_pwdata_next = data_next[current_seg_next*SEG_DATA_W +: SEG_DATA_W];
                m_apb_pstrb_next = strb_next[current_seg_next*SEG_STRB_W +: SEG_STRB_W];

                s_axil_resp_next = AXI_RESP_OKAY;

                m_apb_pwuser_next = s_axil_wr.wuser;

                if (write_eligible && (!read_eligible || last_read_reg)) begin
                    // start write
                    last_read_next = 1'b0;

                    current_seg_next = s_axil_wr.awaddr[APB_ADDR_BIT_OFFSET +: SEG_COUNT_W];

                    s_axil_awready_next = 1'b1;
                    s_axil_wready_next = 1'b1;

                    m_apb_paddr_next = APB_ADDR_W'(s_axil_wr.awaddr);
                    m_apb_pprot_next = s_axil_wr.awprot;
                    m_apb_pauser_next = s_axil_wr.awuser;
                    m_apb_pwrite_next = 1'b1;
                    m_apb_psel_next = 1'b1;

                    state_next = STATE_DATA;
                end else if (read_eligible) begin
                    // start read
                    last_read_next = 1'b1;

                    current_seg_next = s_axil_rd.araddr[APB_ADDR_BIT_OFFSET +: SEG_COUNT_W];

                    s_axil_arready_next = 1'b1;

                    m_apb_paddr_next = APB_ADDR_W'(s_axil_rd.araddr);
                    m_apb_pprot_next = s_axil_rd.arprot;
                    m_apb_pauser_next = s_axil_rd.aruser;
                    m_apb_pwrite_next = 1'b0;
                    m_apb_psel_next = 1'b1;

                    state_next = STATE_DATA;
                end else begin
                    state_next = STATE_IDLE;
                end
            end
            STATE_DATA: begin
                m_apb_psel_next = 1'b1;
                m_apb_penable_next = 1'b1;

                if (m_apb_pwrite_reg) begin
                    s_axil_buser_next = m_apb.pbuser;
                end else begin
                    s_axil_rdata_next[current_seg_reg*SEG_DATA_W +: SEG_DATA_W] = m_apb.prdata;
                    s_axil_ruser_next = m_apb.pruser;
                end

                if (m_apb.psel && m_apb.penable && m_apb.pready) begin
                    if (m_apb.pslverr) begin
                        s_axil_resp_next = AXI_RESP_SLVERR;
                    end

                    m_apb_penable_next = 1'b0;
                    current_seg_next = current_seg_reg + 1;
                    m_apb_paddr_next = (m_apb_paddr_reg & APB_ADDR_MASK) + SEG_STRB_W;
                    m_apb_pwdata_next = data_next[current_seg_next*SEG_DATA_W +: SEG_DATA_W];
                    m_apb_pstrb_next = strb_next[current_seg_next*SEG_STRB_W +: SEG_STRB_W];
                    if (current_seg_reg == SEG_COUNT_W'(SEG_COUNT-1)) begin
                        if (m_apb_pwrite_reg) begin
                            s_axil_bvalid_next = 1'b1;
                        end else begin
                            s_axil_rvalid_next = 1'b1;
                        end

                        m_apb_psel_next = 1'b0;

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

        last_read_reg <= last_read_next;

        data_reg <= data_next;
        strb_reg <= strb_next;

        current_seg_reg <= current_seg_next;

        s_axil_awready_reg <= s_axil_awready_next;
        s_axil_wready_reg <= s_axil_wready_next;
        s_axil_buser_reg <= s_axil_buser_next;
        s_axil_bvalid_reg <= s_axil_bvalid_next;

        s_axil_arready_reg <= s_axil_arready_next;
        s_axil_rdata_reg <= s_axil_rdata_next;
        s_axil_ruser_reg <= s_axil_ruser_next;
        s_axil_rvalid_reg <= s_axil_rvalid_next;

        s_axil_resp_reg <= s_axil_resp_next;

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

            last_read_reg <= 1'b0;

            s_axil_awready_reg <= 1'b0;
            s_axil_wready_reg <= 1'b0;
            s_axil_bvalid_reg <= 1'b0;
            s_axil_arready_reg <= 1'b0;
            s_axil_rvalid_reg <= 1'b0;

            m_apb_psel_reg <= 1'b0;
            m_apb_penable_reg <= 1'b0;
        end
    end

end

endmodule

`resetall
