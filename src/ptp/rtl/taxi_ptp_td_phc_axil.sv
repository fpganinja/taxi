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
 * PTP time distribution PHC with AXI-lite register interface
 */
module taxi_ptp_td_phc_axil #
(
    parameter PTP_CLK_PER_NS_NUM = 512,
    parameter PTP_CLK_PER_NS_DENOM = 165,
    parameter PTP_CLOCK_CDC_PIPELINE = 0
)
(
    input  wire logic         clk,
    input  wire logic         rst,

    /*
     * Control register interface
     */
     taxi_axil_if.wr_slv      s_axil_wr,
     taxi_axil_if.rd_slv      s_axil_rd,

    /*
     * PTP clock
     */
    input  wire logic         ptp_clk,
    input  wire logic         ptp_rst,
    input  wire logic         ptp_sample_clk,
    output wire logic         ptp_td_sdo,
    output wire logic         ptp_pps,
    output wire logic         ptp_pps_str,
    output wire logic         ptp_sync_locked,
    output wire logic [63:0]  ptp_sync_ts_rel,
    output wire logic         ptp_sync_ts_rel_step,
    output wire logic [95:0]  ptp_sync_ts_tod,
    output wire logic         ptp_sync_ts_tod_step,
    output wire logic         ptp_sync_pps,
    output wire logic         ptp_sync_pps_str
);

localparam AXIL_DATA_W = s_axil_wr.DATA_W;
localparam AXIL_ADDR_W = s_axil_wr.ADDR_W;
localparam AXIL_STRB_W = s_axil_wr.STRB_W;

localparam PTP_NS_W = 8;
localparam PTP_FNS_W = 32;

localparam PTP_CLK_PER_NS = PTP_CLK_PER_NS_NUM / PTP_CLK_PER_NS_DENOM;
localparam PTP_CLK_PER_NS_REM = PTP_CLK_PER_NS_NUM - PTP_CLK_PER_NS*PTP_CLK_PER_NS_DENOM;
localparam PTP_CLK_PER_FNS = (PTP_CLK_PER_NS_REM * {32'd1, {PTP_FNS_W{1'b0}}}) / (32+PTP_FNS_W)'(PTP_CLK_PER_NS_DENOM);
localparam PTP_CLK_PER_FNS_REM = (PTP_CLK_PER_NS_REM * {32'd1, {PTP_FNS_W{1'b0}}}) - PTP_CLK_PER_FNS*PTP_CLK_PER_NS_DENOM;

// check configuration
if (AXIL_DATA_W != 32)
    $fatal(0, "Error: Register interface width must be 32 (instance %m)");

if (AXIL_STRB_W * 8 != AXIL_DATA_W)
    $fatal(0, "Error: Register interface requires byte (8-bit) granularity (instance %m)");

if (AXIL_ADDR_W < 7)
    $fatal(0, "Error: Register address width too narrow (instance %m)");

logic [95:0] get_ptp_ts_tod_reg = '0;
logic [29:0] set_ptp_ts_tod_ns_reg = '0;
logic [47:0] set_ptp_ts_tod_s_reg = '0;

logic set_ptp_ts_tod_req_reg = 1'b0;
(* async_reg = "true", shreg_extract = "no" *)
logic set_ptp_ts_tod_req_sync1_reg = 1'b0,  set_ptp_ts_tod_req_sync2_reg = 1'b0;

logic set_ptp_ts_tod_ack_reg = 1'b0;
(* async_reg = "true", shreg_extract = "no" *)
logic set_ptp_ts_tod_ack_sync1_reg = 1'b0,  set_ptp_ts_tod_ack_sync2_reg = 1'b0;

logic set_ptp_ts_tod_valid_reg = 1'b0;
wire set_ptp_ts_tod_ready;

logic [29:0] offset_ptp_ts_tod_ns_reg = '0;

logic offset_ptp_ts_tod_req_reg = 1'b0;
(* async_reg = "true", shreg_extract = "no" *)
logic offset_ptp_ts_tod_req_sync1_reg = 1'b0,  offset_ptp_ts_tod_req_sync2_reg = 1'b0;

logic offset_ptp_ts_tod_ack_reg = 1'b0;
(* async_reg = "true", shreg_extract = "no" *)
logic offset_ptp_ts_tod_ack_sync1_reg = 1'b0,  offset_ptp_ts_tod_ack_sync2_reg = 1'b0;

logic offset_ptp_ts_tod_valid_reg = 1'b0;
wire offset_ptp_ts_tod_ready;

logic [63:0] get_ptp_ts_rel_reg = '0;
logic [47:0] set_ptp_ts_rel_ns_reg = '0;

logic set_ptp_ts_rel_req_reg = 1'b0;
(* async_reg = "true", shreg_extract = "no" *)
logic set_ptp_ts_rel_req_sync1_reg = 1'b0,  set_ptp_ts_rel_req_sync2_reg = 1'b0;

logic set_ptp_ts_rel_ack_reg = 1'b0;
(* async_reg = "true", shreg_extract = "no" *)
logic set_ptp_ts_rel_ack_sync1_reg = 1'b0,  set_ptp_ts_rel_ack_sync2_reg = 1'b0;

logic set_ptp_ts_rel_valid_reg = 1'b0;
wire set_ptp_ts_rel_ready;

logic [31:0] offset_ptp_ts_rel_ns_reg = '0;

logic offset_ptp_ts_rel_req_reg = 1'b0;
(* async_reg = "true", shreg_extract = "no" *)
logic offset_ptp_ts_rel_req_sync1_reg = 1'b0,  offset_ptp_ts_rel_req_sync2_reg = 1'b0;

logic offset_ptp_ts_rel_ack_reg = 1'b0;
(* async_reg = "true", shreg_extract = "no" *)
logic offset_ptp_ts_rel_ack_sync1_reg = 1'b0,  offset_ptp_ts_rel_ack_sync2_reg = 1'b0;

logic offset_ptp_ts_rel_valid_reg = 1'b0;
wire offset_ptp_ts_rel_ready;

logic [PTP_NS_W-1:0] set_ptp_period_ns_reg = PTP_NS_W'(PTP_CLK_PER_NS);
logic [PTP_FNS_W-1:0] set_ptp_period_fns_reg = PTP_FNS_W'(PTP_CLK_PER_FNS);

logic set_ptp_period_req_reg = 1'b0;
(* async_reg = "true", shreg_extract = "no" *)
logic set_ptp_period_req_sync1_reg = 1'b0,  set_ptp_period_req_sync2_reg = 1'b0;

logic set_ptp_period_ack_reg = 1'b0;
(* async_reg = "true", shreg_extract = "no" *)
logic set_ptp_period_ack_sync1_reg = 1'b0,  set_ptp_period_ack_sync2_reg = 1'b0;

logic set_ptp_period_valid_reg = 1'b0;
wire set_ptp_period_ready;

logic [31:0] offset_ptp_ts_fns_reg = '0;

logic offset_ptp_ts_req_reg = 1'b0;
(* async_reg = "true", shreg_extract = "no" *)
logic offset_ptp_ts_req_sync1_reg = 1'b0,  offset_ptp_ts_req_sync2_reg = 1'b0;

logic offset_ptp_ts_ack_reg = 1'b0;
(* async_reg = "true", shreg_extract = "no" *)
logic offset_ptp_ts_ack_sync1_reg = 1'b0,  offset_ptp_ts_ack_sync2_reg = 1'b0;

logic offset_ptp_ts_valid_reg = 1'b0;
wire offset_ptp_ts_ready;

always_ff @(posedge ptp_clk) begin
    set_ptp_ts_tod_req_sync1_reg <= set_ptp_ts_tod_req_reg;
    set_ptp_ts_tod_req_sync2_reg <= set_ptp_ts_tod_req_sync1_reg;
    offset_ptp_ts_tod_req_sync1_reg <= offset_ptp_ts_tod_req_reg;
    offset_ptp_ts_tod_req_sync2_reg <= offset_ptp_ts_tod_req_sync1_reg;
    set_ptp_ts_rel_req_sync1_reg <= set_ptp_ts_rel_req_reg;
    set_ptp_ts_rel_req_sync2_reg <= set_ptp_ts_rel_req_sync1_reg;
    offset_ptp_ts_rel_req_sync1_reg <= offset_ptp_ts_rel_req_reg;
    offset_ptp_ts_rel_req_sync2_reg <= offset_ptp_ts_rel_req_sync1_reg;
    set_ptp_period_req_sync1_reg <= set_ptp_period_req_reg;
    set_ptp_period_req_sync2_reg <= set_ptp_period_req_sync1_reg;
    offset_ptp_ts_req_sync1_reg <= offset_ptp_ts_req_reg;
    offset_ptp_ts_req_sync2_reg <= offset_ptp_ts_req_sync1_reg;
end

always_ff @(posedge clk) begin
    set_ptp_ts_tod_ack_sync1_reg <= set_ptp_ts_tod_ack_reg;
    set_ptp_ts_tod_ack_sync2_reg <= set_ptp_ts_tod_ack_sync1_reg;
    offset_ptp_ts_tod_ack_sync1_reg <= offset_ptp_ts_tod_ack_reg;
    offset_ptp_ts_tod_ack_sync2_reg <= offset_ptp_ts_tod_ack_sync1_reg;
    set_ptp_ts_rel_ack_sync1_reg <= set_ptp_ts_rel_ack_reg;
    set_ptp_ts_rel_ack_sync2_reg <= set_ptp_ts_rel_ack_sync1_reg;
    offset_ptp_ts_rel_ack_sync1_reg <= offset_ptp_ts_rel_ack_reg;
    offset_ptp_ts_rel_ack_sync2_reg <= offset_ptp_ts_rel_ack_sync1_reg;
    set_ptp_period_ack_sync1_reg <= set_ptp_period_ack_reg;
    set_ptp_period_ack_sync2_reg <= set_ptp_period_ack_sync1_reg;
    offset_ptp_ts_ack_sync1_reg <= offset_ptp_ts_ack_reg;
    offset_ptp_ts_ack_sync2_reg <= offset_ptp_ts_ack_sync1_reg;
end

always_ff @(posedge ptp_clk) begin
    if (set_ptp_ts_tod_ack_reg) begin
        set_ptp_ts_tod_ack_reg <= set_ptp_ts_tod_req_sync2_reg;
    end else begin
        if (set_ptp_ts_tod_valid_reg && set_ptp_ts_tod_ready) begin
            set_ptp_ts_tod_valid_reg <= 1'b0;
            set_ptp_ts_tod_ack_reg <= 1'b1;
        end else begin
            set_ptp_ts_tod_valid_reg <= set_ptp_ts_tod_req_sync2_reg;
        end
    end

    if (offset_ptp_ts_tod_ack_reg) begin
        offset_ptp_ts_tod_ack_reg <= offset_ptp_ts_tod_req_sync2_reg;
    end else begin
        if (offset_ptp_ts_tod_valid_reg && offset_ptp_ts_tod_ready) begin
            offset_ptp_ts_tod_valid_reg <= 1'b0;
            offset_ptp_ts_tod_ack_reg <= 1'b1;
        end else begin
            offset_ptp_ts_tod_valid_reg <= offset_ptp_ts_tod_req_sync2_reg;
        end
    end

    if (set_ptp_ts_rel_ack_reg) begin
        set_ptp_ts_rel_ack_reg <= set_ptp_ts_rel_req_sync2_reg;
    end else begin
        if (set_ptp_ts_rel_valid_reg && set_ptp_ts_rel_ready) begin
            set_ptp_ts_rel_valid_reg <= 1'b0;
            set_ptp_ts_rel_ack_reg <= 1'b1;
        end else begin
            set_ptp_ts_rel_valid_reg <= set_ptp_ts_rel_req_sync2_reg;
        end
    end

    if (offset_ptp_ts_rel_ack_reg) begin
        offset_ptp_ts_rel_ack_reg <= offset_ptp_ts_rel_req_sync2_reg;
    end else begin
        if (offset_ptp_ts_rel_valid_reg && offset_ptp_ts_rel_ready) begin
            offset_ptp_ts_rel_valid_reg <= 1'b0;
            offset_ptp_ts_rel_ack_reg <= 1'b1;
        end else begin
            offset_ptp_ts_rel_valid_reg <= offset_ptp_ts_rel_req_sync2_reg;
        end
    end

    if (set_ptp_period_ack_reg) begin
        set_ptp_period_ack_reg <= set_ptp_period_req_sync2_reg;
    end else begin
        if (set_ptp_period_valid_reg && set_ptp_period_ready) begin
            set_ptp_period_valid_reg <= 1'b0;
            set_ptp_period_ack_reg <= 1'b1;
        end else begin
            set_ptp_period_valid_reg <= set_ptp_period_req_sync2_reg;
        end
    end

    if (offset_ptp_ts_ack_reg) begin
        offset_ptp_ts_ack_reg <= offset_ptp_ts_req_sync2_reg;
    end else begin
        if (offset_ptp_ts_valid_reg && offset_ptp_ts_ready) begin
            offset_ptp_ts_valid_reg <= 1'b0;
            offset_ptp_ts_ack_reg <= 1'b1;
        end else begin
            offset_ptp_ts_valid_reg <= offset_ptp_ts_req_sync2_reg;
        end
    end

    if (ptp_rst) begin
        set_ptp_ts_tod_ack_reg <= 1'b0;
        set_ptp_ts_tod_valid_reg <= 1'b0;
        offset_ptp_ts_tod_ack_reg <= 1'b0;
        offset_ptp_ts_tod_valid_reg <= 1'b0;
        set_ptp_ts_rel_ack_reg <= 1'b0;
        set_ptp_ts_rel_valid_reg <= 1'b0;
        offset_ptp_ts_rel_ack_reg <= 1'b0;
        offset_ptp_ts_rel_valid_reg <= 1'b0;
        set_ptp_period_ack_reg <= 1'b0;
        set_ptp_period_valid_reg <= 1'b0;
        offset_ptp_ts_ack_reg <= 1'b0;
        offset_ptp_ts_valid_reg <= 1'b0;
    end
end

logic s_axil_awready_reg = 1'b0;
logic s_axil_wready_reg = 1'b0;
logic s_axil_bvalid_reg = 1'b0;

logic s_axil_arready_reg = 1'b0;
logic [AXIL_DATA_W-1:0] s_axil_rdata_reg = '0;
logic s_axil_rvalid_reg = 1'b0;

assign s_axil_wr.awready = s_axil_awready_reg;
assign s_axil_wr.wready = s_axil_wready_reg;
assign s_axil_wr.bresp = '0;
assign s_axil_wr.buser = '0;
assign s_axil_wr.bvalid = s_axil_bvalid_reg;

assign s_axil_rd.arready = s_axil_arready_reg;
assign s_axil_rd.rdata = s_axil_rdata_reg;
assign s_axil_rd.rresp = '0;
assign s_axil_rd.ruser = '0;
assign s_axil_rd.rvalid = s_axil_rvalid_reg;

always_ff @(posedge clk) begin
    s_axil_awready_reg <= 1'b0;
    s_axil_wready_reg <= 1'b0;
    s_axil_bvalid_reg <= s_axil_bvalid_reg && !s_axil_wr.bready;

    s_axil_arready_reg <= 1'b0;
    s_axil_rvalid_reg <= s_axil_rvalid_reg && !s_axil_rd.rready;

    set_ptp_ts_tod_req_reg <= set_ptp_ts_tod_req_reg && !set_ptp_ts_tod_ack_sync2_reg;
    offset_ptp_ts_tod_req_reg <= offset_ptp_ts_tod_req_reg && !offset_ptp_ts_tod_ack_sync2_reg;
    set_ptp_ts_rel_req_reg <= set_ptp_ts_rel_req_reg && !set_ptp_ts_rel_ack_sync2_reg;
    offset_ptp_ts_rel_req_reg <= offset_ptp_ts_rel_req_reg && !offset_ptp_ts_rel_ack_sync2_reg;
    offset_ptp_ts_req_reg <= offset_ptp_ts_req_reg && !offset_ptp_ts_ack_sync2_reg;
    set_ptp_period_req_reg <= set_ptp_period_req_reg && !set_ptp_period_ack_sync2_reg;

    if (s_axil_wr.awvalid && s_axil_wr.wvalid && !s_axil_bvalid_reg) begin
        s_axil_awready_reg <= 1'b1;
        s_axil_wready_reg <= 1'b1;
        s_axil_bvalid_reg <= 1'b1;

        case (7'({s_axil_wr.awaddr >> 2, 2'b00}))
            // PHC
            7'h50: begin
                // PTP offset ToD
                if (!offset_ptp_ts_tod_req_reg || offset_ptp_ts_tod_ack_sync2_reg) begin
                    offset_ptp_ts_tod_ns_reg <= 30'(s_axil_wr.wdata);
                    offset_ptp_ts_tod_req_reg <= s_axil_wr.wdata != 0;
                end
            end
            7'h54: begin
                // PTP set ToD ns
                if (!set_ptp_ts_tod_req_reg || set_ptp_ts_tod_ack_sync2_reg) begin
                    set_ptp_ts_tod_ns_reg <= 30'(s_axil_wr.wdata);
                end
            end
            7'h58: begin
                // PTP set ToD sec l
                if (!set_ptp_ts_tod_req_reg || set_ptp_ts_tod_ack_sync2_reg) begin
                    set_ptp_ts_tod_s_reg[31:0] <= s_axil_wr.wdata;
                end
            end
            7'h5C: begin
                // PTP set ToD sec h
                if (!set_ptp_ts_tod_req_reg || set_ptp_ts_tod_ack_sync2_reg) begin
                    set_ptp_ts_tod_s_reg[47:32] <= 16'(s_axil_wr.wdata);
                    set_ptp_ts_tod_req_reg <= 1'b1;
                end
            end
            7'h60: begin
                // PTP set rel ns l
                if (!set_ptp_ts_rel_req_reg || set_ptp_ts_rel_ack_sync2_reg) begin
                    set_ptp_ts_rel_ns_reg[31:0] <= s_axil_wr.wdata;
                end
            end
            7'h64: begin
                // PTP set rel ns h
                if (!set_ptp_ts_rel_req_reg || set_ptp_ts_rel_ack_sync2_reg) begin
                    set_ptp_ts_rel_ns_reg[47:32] <= 16'(s_axil_wr.wdata);
                    set_ptp_ts_rel_req_reg <= 1'b1;
                end
            end
            7'h68: begin
                // PTP offset rel
                if (!offset_ptp_ts_rel_req_reg || offset_ptp_ts_rel_ack_sync2_reg) begin
                    offset_ptp_ts_rel_ns_reg <= s_axil_wr.wdata;
                    offset_ptp_ts_rel_req_reg <= s_axil_wr.wdata != 0;
                end
            end
            7'h6C: begin
                // PTP offset FNS
                if (!offset_ptp_ts_req_reg || offset_ptp_ts_ack_sync2_reg) begin
                    offset_ptp_ts_fns_reg <= s_axil_wr.wdata;
                    offset_ptp_ts_req_reg <= s_axil_wr.wdata != 0;
                end
            end
            7'h78: begin
                // PTP period fns
                if (!set_ptp_period_req_reg || set_ptp_period_ack_sync2_reg) begin
                    set_ptp_period_fns_reg <= PTP_FNS_W'(s_axil_wr.wdata);
                end
            end
            7'h7C: begin
                // PTP period ns
                if (!set_ptp_period_req_reg || set_ptp_period_ack_sync2_reg) begin
                    set_ptp_period_ns_reg <= PTP_NS_W'(s_axil_wr.wdata);
                    set_ptp_period_req_reg <= 1'b1;
                end
            end
            default: begin end
        endcase
    end

    if (s_axil_rd.arvalid && !s_axil_rvalid_reg) begin
        s_axil_rdata_reg <= '0;

        s_axil_arready_reg <= 1'b1;
        s_axil_rvalid_reg <= 1'b1;

        case (7'({s_axil_rd.araddr >> 2, 2'b00}))
            7'h0C: begin
                // PHC control
                s_axil_rdata_reg[8] <= ptp_sync_pps_str;  // PPS
                s_axil_rdata_reg[16] <= ptp_sync_locked;  // Locked
                s_axil_rdata_reg[24] <= set_ptp_ts_tod_req_reg || set_ptp_ts_tod_ack_sync2_reg;        // ToD set pending
                s_axil_rdata_reg[25] <= offset_ptp_ts_tod_req_reg || offset_ptp_ts_tod_ack_sync2_reg;  // ToD offset pending
                s_axil_rdata_reg[26] <= set_ptp_ts_rel_req_reg || set_ptp_ts_rel_ack_sync2_reg;        // Relative set pending
                s_axil_rdata_reg[27] <= offset_ptp_ts_rel_req_reg || offset_ptp_ts_rel_ack_sync2_reg;  // Relative offset pending
                s_axil_rdata_reg[28] <= set_ptp_period_req_reg || set_ptp_period_ack_sync2_reg;        // Period set pending
                s_axil_rdata_reg[29] <= offset_ptp_ts_req_reg || offset_ptp_ts_ack_sync2_reg;          // FNS offset pending
            end
            7'h10: s_axil_rdata_reg <= {ptp_sync_ts_tod[15:0], 16'd0};  // PTP cur fns
            7'h14: s_axil_rdata_reg <= ptp_sync_ts_tod[47:16];          // PTP cur ToD ns
            7'h18: s_axil_rdata_reg <= ptp_sync_ts_tod[79:48];          // PTP cur ToD sec l
            7'h1C: s_axil_rdata_reg <= 32'(ptp_sync_ts_tod[95:80]);     // PTP cur ToD sec h
            7'h20: s_axil_rdata_reg <= ptp_sync_ts_rel[47:16];          // PTP cur rel ns l
            7'h24: s_axil_rdata_reg <= 32'(ptp_sync_ts_rel[63:48]);     // PTP cur rel ns h
            7'h28: s_axil_rdata_reg <= '0;                              // PTP cur PTM l
            7'h2C: s_axil_rdata_reg <= '0;                              // PTP cur PTM h
            7'h30: begin
                // PTP snapshot fns
                get_ptp_ts_tod_reg <= ptp_sync_ts_tod;
                get_ptp_ts_rel_reg <= ptp_sync_ts_rel;
                s_axil_rdata_reg <= {ptp_sync_ts_tod[15:0], 16'd0};
            end
            7'h34: s_axil_rdata_reg <= 32'(get_ptp_ts_tod_reg[45:16]);  // PTP snapshot ToD ns
            7'h38: s_axil_rdata_reg <= get_ptp_ts_tod_reg[79:48];       // PTP snapshot ToD sec l
            7'h3C: s_axil_rdata_reg <= 32'(get_ptp_ts_tod_reg[95:80]);  // PTP snapshot ToD sec h
            7'h40: s_axil_rdata_reg <= get_ptp_ts_rel_reg[47:16];       // PTP snapshot rel ns l
            7'h44: s_axil_rdata_reg <= 32'(get_ptp_ts_rel_reg[63:48]);  // PTP snapshot rel ns h
            7'h48: s_axil_rdata_reg <= '0;                              // PTP snapshot PTM l
            7'h4C: s_axil_rdata_reg <= '0;                              // PTP snapshot PTM h
            7'h50: s_axil_rdata_reg <= 32'(offset_ptp_ts_tod_ns_reg);   // PTP offset ToD
            7'h54: s_axil_rdata_reg <= 32'(set_ptp_ts_tod_ns_reg);      // PTP set ToD ns
            7'h58: s_axil_rdata_reg <= set_ptp_ts_tod_s_reg[31:0];      // PTP set ToD sec l
            7'h5C: s_axil_rdata_reg <= set_ptp_ts_tod_s_reg[47:16];     // PTP set ToD sec h
            7'h60: s_axil_rdata_reg <= set_ptp_ts_rel_ns_reg[31:0];     // PTP set rel ns l
            7'h64: s_axil_rdata_reg <= set_ptp_ts_rel_ns_reg[47:16];    // PTP set rel ns h
            7'h68: s_axil_rdata_reg <= offset_ptp_ts_rel_ns_reg;        // PTP offset rel
            7'h6C: s_axil_rdata_reg <= offset_ptp_ts_fns_reg;           // PTP offset FNS
            7'h70: s_axil_rdata_reg <= 32'(PTP_CLK_PER_FNS);            // PTP nom period fns
            7'h74: s_axil_rdata_reg <= 32'(PTP_CLK_PER_NS);             // PTP nom period ns
            7'h78: s_axil_rdata_reg <= set_ptp_period_fns_reg;          // PTP period fns
            7'h7C: s_axil_rdata_reg <= 32'(set_ptp_period_ns_reg);      // PTP period ns
            default: begin end
        endcase
    end

    if (rst) begin
        s_axil_awready_reg <= 1'b0;
        s_axil_wready_reg <= 1'b0;
        s_axil_bvalid_reg <= 1'b0;

        s_axil_arready_reg <= 1'b0;
        s_axil_rvalid_reg <= 1'b0;

        set_ptp_period_ns_reg <= PTP_NS_W'(PTP_CLK_PER_NS);
        set_ptp_period_fns_reg <= PTP_FNS_W'(PTP_CLK_PER_FNS);

        set_ptp_ts_tod_req_reg <= 1'b0;
        offset_ptp_ts_tod_req_reg <= 1'b0;
        set_ptp_ts_rel_req_reg <= 1'b0;
        offset_ptp_ts_rel_req_reg <= 1'b0;
        offset_ptp_ts_req_reg <= 1'b0;
        set_ptp_period_req_reg <= 1'b0;
    end
end

// PTP clock
taxi_ptp_td_phc #(
    .PERIOD_NS_NUM(PTP_CLK_PER_NS_NUM),
    .PERIOD_NS_DENOM(PTP_CLK_PER_NS_DENOM)
)
ptp_td_phc_inst (
    .clk(ptp_clk),
    .rst(ptp_rst),

    /*
     * ToD timestamp control
     */
    .input_ts_tod_s(set_ptp_ts_tod_s_reg),
    .input_ts_tod_ns(set_ptp_ts_tod_ns_reg),
    .input_ts_tod_valid(set_ptp_ts_tod_valid_reg),
    .input_ts_tod_ready(set_ptp_ts_tod_ready),
    .input_ts_tod_offset_ns(offset_ptp_ts_tod_ns_reg),
    .input_ts_tod_offset_valid(offset_ptp_ts_tod_valid_reg),
    .input_ts_tod_offset_ready(offset_ptp_ts_tod_ready),

    /*
     * Relative timestamp control
     */
    .input_ts_rel_ns(set_ptp_ts_rel_ns_reg),
    .input_ts_rel_valid(set_ptp_ts_rel_valid_reg),
    .input_ts_rel_ready(set_ptp_ts_rel_ready),
    .input_ts_rel_offset_ns(offset_ptp_ts_rel_ns_reg),
    .input_ts_rel_offset_valid(offset_ptp_ts_rel_valid_reg),
    .input_ts_rel_offset_ready(offset_ptp_ts_rel_ready),

    /*
     * Fractional ns control
     */
    .input_ts_offset_fns(offset_ptp_ts_fns_reg),
    .input_ts_offset_valid(offset_ptp_ts_valid_reg),
    .input_ts_offset_ready(offset_ptp_ts_ready),

    /*
     * Period control
     */
    .input_period_ns(set_ptp_period_ns_reg),
    .input_period_fns(set_ptp_period_fns_reg),
    .input_period_valid(set_ptp_period_valid_reg),
    .input_period_ready(set_ptp_period_ready),
    .input_drift_num('0),
    .input_drift_denom('0),
    .input_drift_valid(1'b0),
    .input_drift_ready(),

    /*
     * Time distribution serial data output
     */
    .ptp_td_sdo(ptp_td_sdo),

    /*
     * PPS output
     */
    .output_pps(ptp_pps),
    .output_pps_str(ptp_pps_str)
);

// sync to core clock domain
taxi_ptp_td_leaf #(
    .TS_REL_EN(1),
    .TS_TOD_EN(1),
    .TS_FNS_W(16),
    .TS_REL_NS_W(48),
    .TS_TOD_S_W(48),
    .TS_REL_W(64),
    .TS_TOD_W(96),
    .TD_SDI_PIPELINE(PTP_CLOCK_CDC_PIPELINE)
)
ptp_td_leaf_inst (
    .clk(clk),
    .rst(rst),
    .sample_clk(ptp_sample_clk),

    /*
     * PTP clock interface
     */
    .ptp_clk(ptp_clk),
    .ptp_rst(ptp_rst),
    .ptp_td_sdi(ptp_td_sdo),

    /*
     * Timestamp output
     */
    .output_ts_rel(ptp_sync_ts_rel),
    .output_ts_rel_step(ptp_sync_ts_rel_step),
    .output_ts_tod(ptp_sync_ts_tod),
    .output_ts_tod_step(ptp_sync_ts_tod_step),

    /*
     * PPS output (ToD format only)
     */
    .output_pps(ptp_sync_pps),
    .output_pps_str(ptp_sync_pps_str),

    /*
     * Status
     */
    .locked(ptp_sync_locked)
);

endmodule

`resetall
