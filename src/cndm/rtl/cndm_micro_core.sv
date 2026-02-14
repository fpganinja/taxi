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
 * Corundum-micro core logic
 */
module cndm_micro_core #(
    parameter PORTS = 2,
    parameter logic PTP_TS_EN = 1'b1,
    parameter logic PTP_TS_FMT_TOD = 1'b0,
    parameter PTP_CLK_PER_NS_NUM = 512,
    parameter PTP_CLK_PER_NS_DENOM = 165
)
(
    input  wire logic              clk,
    input  wire logic              rst,

    /*
     * Control register interface
     */
    taxi_axil_if.wr_slv            s_axil_wr,
    taxi_axil_if.rd_slv            s_axil_rd,

    /*
     * DMA
     */
    taxi_dma_desc_if.req_src       dma_rd_desc_req,
    taxi_dma_desc_if.sts_snk       dma_rd_desc_sts,
    taxi_dma_desc_if.req_src       dma_wr_desc_req,
    taxi_dma_desc_if.sts_snk       dma_wr_desc_sts,
    taxi_dma_ram_if.wr_slv         dma_ram_wr,
    taxi_dma_ram_if.rd_slv         dma_ram_rd,

    output wire logic [PORTS-1:0]  irq,

    /*
     * PTP
     */
    input  wire logic              ptp_clk = 1'b0,
    input  wire logic              ptp_rst = 1'b0,
    input  wire logic              ptp_sample_clk = 1'b0,
    input  wire logic              ptp_td_sdi = 1'b0,
    output wire logic              ptp_td_sdo,
    output wire logic              ptp_pps,
    output wire logic              ptp_pps_str,
    output wire logic              ptp_sync_locked,
    output wire logic [63:0]       ptp_sync_ts_rel,
    output wire logic              ptp_sync_ts_rel_step,
    output wire logic [95:0]       ptp_sync_ts_tod,
    output wire logic              ptp_sync_ts_tod_step,
    output wire logic              ptp_sync_pps,
    output wire logic              ptp_sync_pps_str,

    /*
     * Ethernet
     */
    input  wire logic              mac_tx_clk[PORTS],
    input  wire logic              mac_tx_rst[PORTS],
    taxi_axis_if.src               mac_axis_tx[PORTS],
    taxi_axis_if.snk               mac_axis_tx_cpl[PORTS],

    input  wire logic              mac_rx_clk[PORTS],
    input  wire logic              mac_rx_rst[PORTS],
    taxi_axis_if.snk               mac_axis_rx[PORTS]
);

localparam CL_PORTS = $clog2(PORTS);

localparam AXIL_ADDR_W = s_axil_wr.ADDR_W;
localparam AXIL_DATA_W = s_axil_wr.DATA_W;

localparam RAM_SEGS = dma_ram_wr.SEGS;
localparam RAM_SEG_ADDR_W = dma_ram_wr.SEG_ADDR_W;
localparam RAM_SEG_DATA_W = dma_ram_wr.SEG_DATA_W;
localparam RAM_SEG_BE_W = dma_ram_wr.SEG_BE_W;
localparam RAM_SEL_W = dma_ram_wr.SEL_W;

localparam PORT_OFFSET = PTP_TS_EN ? 2 : 1;

taxi_axil_if #(
    .DATA_W(s_axil_wr.DATA_W),
    .ADDR_W(16),
    .STRB_W(s_axil_wr.STRB_W),
    .AWUSER_EN(s_axil_wr.AWUSER_EN),
    .AWUSER_W(s_axil_wr.AWUSER_W),
    .WUSER_EN(s_axil_wr.WUSER_EN),
    .WUSER_W(s_axil_wr.WUSER_W),
    .BUSER_EN(s_axil_wr.BUSER_EN),
    .BUSER_W(s_axil_wr.BUSER_W),
    .ARUSER_EN(s_axil_wr.ARUSER_EN),
    .ARUSER_W(s_axil_wr.ARUSER_W),
    .RUSER_EN(s_axil_wr.RUSER_EN),
    .RUSER_W(s_axil_wr.RUSER_W)
)
s_axil_ctrl[PORTS+PORT_OFFSET]();

taxi_axil_interconnect_1s #(
    .M_COUNT($size(s_axil_ctrl)),
    .ADDR_W(s_axil_wr.ADDR_W),
    .M_REGIONS(1),
    .M_BASE_ADDR('0),
    .M_ADDR_W({$size(s_axil_ctrl){{1{32'd16}}}}),
    .M_SECURE({$size(s_axil_ctrl){1'b0}})
)
port_intercon_inst (
    .clk(clk),
    .rst(rst),

    /*
     * AXI4-lite slave interface
     */
    .s_axil_wr(s_axil_wr),
    .s_axil_rd(s_axil_rd),

    /*
     * AXI4-lite master interfaces
     */
    .m_axil_wr(s_axil_ctrl),
    .m_axil_rd(s_axil_ctrl)
);

logic s_axil_awready_reg = 1'b0;
logic s_axil_wready_reg = 1'b0;
logic s_axil_bvalid_reg = 1'b0;

logic s_axil_arready_reg = 1'b0;
logic [AXIL_DATA_W-1:0] s_axil_rdata_reg = '0;
logic s_axil_rvalid_reg = 1'b0;

assign s_axil_ctrl[0].awready = s_axil_awready_reg;
assign s_axil_ctrl[0].wready = s_axil_wready_reg;
assign s_axil_ctrl[0].bresp = '0;
assign s_axil_ctrl[0].buser = '0;
assign s_axil_ctrl[0].bvalid = s_axil_bvalid_reg;

assign s_axil_ctrl[0].arready = s_axil_arready_reg;
assign s_axil_ctrl[0].rdata = s_axil_rdata_reg;
assign s_axil_ctrl[0].rresp = '0;
assign s_axil_ctrl[0].ruser = '0;
assign s_axil_ctrl[0].rvalid = s_axil_rvalid_reg;

always_ff @(posedge clk) begin
    s_axil_awready_reg <= 1'b0;
    s_axil_wready_reg <= 1'b0;
    s_axil_bvalid_reg <= s_axil_bvalid_reg && !s_axil_ctrl[0].bready;

    s_axil_arready_reg <= 1'b0;
    s_axil_rvalid_reg <= s_axil_rvalid_reg && !s_axil_ctrl[0].rready;

    if (s_axil_ctrl[0].awvalid && s_axil_ctrl[0].wvalid && !s_axil_bvalid_reg) begin
        s_axil_awready_reg <= 1'b1;
        s_axil_wready_reg <= 1'b1;
        s_axil_bvalid_reg <= 1'b1;

        case ({s_axil_ctrl[0].awaddr[15:2], 2'b00})
            // 16'h0100: begin
            //     txq_en_reg <= s_axil_ctrl[0].wdata[0];
            //     txq_size_reg <= s_axil_ctrl[0].wdata[19:16];
            // end
            // 16'h0104: txq_prod_reg <= s_axil_ctrl[0].wdata[15:0];
            // 16'h0108: txq_base_addr_reg[31:0] <= s_axil_ctrl[0].wdata;
            // 16'h010c: txq_base_addr_reg[63:32] <= s_axil_ctrl[0].wdata;
            default: begin end
        endcase
    end

    if (s_axil_ctrl[0].arvalid && !s_axil_rvalid_reg) begin
        s_axil_rdata_reg <= '0;

        s_axil_arready_reg <= 1'b1;
        s_axil_rvalid_reg <= 1'b1;

        case ({s_axil_ctrl[0].araddr[15:2], 2'b00})
            16'h0100: s_axil_rdata_reg <= PORTS; // port count
            16'h0104: s_axil_rdata_reg <= PTP_TS_EN ? 32'h00020000 : 32'h00010000; // port offset
            16'h0108: s_axil_rdata_reg <= 32'h00010000; // port stride
            default: begin end
        endcase
    end

    if (rst) begin
        s_axil_awready_reg <= 1'b0;
        s_axil_wready_reg <= 1'b0;
        s_axil_bvalid_reg <= 1'b0;

        s_axil_arready_reg <= 1'b0;
        s_axil_rvalid_reg <= 1'b0;
    end
end

if (PTP_TS_EN) begin : ptp

    taxi_ptp_td_phc_axil #(
        .PTP_CLK_PER_NS_NUM(PTP_CLK_PER_NS_NUM),
        .PTP_CLK_PER_NS_DENOM(PTP_CLK_PER_NS_DENOM)
    )
    ptp_inst (
        .clk(clk),
        .rst(rst),

        /*
         * Control register interface
         */
        .s_axil_wr(s_axil_ctrl[1]),
        .s_axil_rd(s_axil_ctrl[1]),

        /*
         * PTP
         */
        .ptp_clk(ptp_clk),
        .ptp_rst(ptp_rst),
        .ptp_sample_clk(ptp_sample_clk),
        .ptp_td_sdo(ptp_td_sdo),
        .ptp_pps(ptp_pps),
        .ptp_pps_str(ptp_pps_str),
        .ptp_sync_locked(ptp_sync_locked),
        .ptp_sync_ts_rel(ptp_sync_ts_rel),
        .ptp_sync_ts_rel_step(ptp_sync_ts_rel_step),
        .ptp_sync_ts_tod(ptp_sync_ts_tod),
        .ptp_sync_ts_tod_step(ptp_sync_ts_tod_step),
        .ptp_sync_pps(ptp_sync_pps),
        .ptp_sync_pps_str(ptp_sync_pps_str)
    );

end else begin : ptp

    assign ptp_td_sdo = 1'b0;
    assign ptp_pps = 1'b0;
    assign ptp_pps_str = 1'b0;
    assign ptp_sync_locked = 1'b0;
    assign ptp_sync_ts_rel = '0;
    assign ptp_sync_ts_rel_step = 1'b0;
    assign ptp_sync_ts_tod = '0;
    assign ptp_sync_ts_tod_step = 1'b0;
    assign ptp_sync_pps = 1'b0;
    assign ptp_sync_pps_str = 1'b0;

end

taxi_dma_desc_if #(
    .SRC_ADDR_W(dma_rd_desc_req.SRC_ADDR_W),
    .SRC_SEL_EN(dma_rd_desc_req.SRC_SEL_EN),
    .SRC_SEL_W(dma_rd_desc_req.SRC_SEL_W),
    .SRC_ASID_EN(dma_rd_desc_req.SRC_ASID_EN),
    .DST_ADDR_W(dma_rd_desc_req.DST_ADDR_W),
    .DST_SEL_EN(dma_rd_desc_req.DST_SEL_EN),
    .DST_SEL_W(dma_rd_desc_req.DST_SEL_W-CL_PORTS),
    .DST_ASID_EN(dma_rd_desc_req.DST_ASID_EN),
    .IMM_EN(dma_rd_desc_req.IMM_EN),
    .LEN_W(dma_rd_desc_req.LEN_W),
    .TAG_W(dma_rd_desc_req.TAG_W-CL_PORTS),
    .ID_EN(dma_rd_desc_req.ID_EN),
    .DEST_EN(dma_rd_desc_req.DEST_EN),
    .USER_EN(dma_rd_desc_req.USER_EN)
) dma_rd_desc_int[PORTS]();

taxi_dma_desc_if #(
    .SRC_ADDR_W(dma_wr_desc_req.SRC_ADDR_W),
    .SRC_SEL_EN(dma_wr_desc_req.SRC_SEL_EN),
    .SRC_SEL_W(dma_wr_desc_req.SRC_SEL_W-CL_PORTS),
    .SRC_ASID_EN(dma_wr_desc_req.SRC_ASID_EN),
    .DST_ADDR_W(dma_wr_desc_req.DST_ADDR_W),
    .DST_SEL_EN(dma_wr_desc_req.DST_SEL_EN),
    .DST_SEL_W(dma_wr_desc_req.DST_SEL_W),
    .DST_ASID_EN(dma_wr_desc_req.DST_ASID_EN),
    .IMM_EN(dma_wr_desc_req.IMM_EN),
    .IMM_W(dma_wr_desc_req.IMM_W),
    .LEN_W(dma_wr_desc_req.LEN_W),
    .TAG_W(dma_wr_desc_req.TAG_W-CL_PORTS),
    .ID_EN(dma_wr_desc_req.ID_EN),
    .DEST_EN(dma_wr_desc_req.DEST_EN),
    .USER_EN(dma_wr_desc_req.USER_EN)
) dma_wr_desc_int[PORTS]();

taxi_dma_ram_if #(
    .SEGS(RAM_SEGS),
    .SEG_ADDR_W(RAM_SEG_ADDR_W),
    .SEG_DATA_W(RAM_SEG_DATA_W),
    .SEG_BE_W(RAM_SEG_BE_W),
    .SEL_W(RAM_SEL_W-CL_PORTS)
) dma_ram_int[PORTS]();

taxi_dma_if_mux #(
    .PORTS(PORTS),
    .ARB_ROUND_ROBIN(1),
    .ARB_LSB_HIGH_PRIO(1)
)
dma_mux_inst (
    .clk(clk),
    .rst(rst),

    /*
     * DMA descriptors from clients
     */
    .client_rd_req(dma_rd_desc_int),
    .client_rd_sts(dma_rd_desc_int),
    .client_wr_req(dma_wr_desc_int),
    .client_wr_sts(dma_wr_desc_int),

    /*
     * DMA descriptors to DMA engines
     */
    .dma_rd_req(dma_rd_desc_req),
    .dma_rd_sts(dma_rd_desc_sts),
    .dma_wr_req(dma_wr_desc_req),
    .dma_wr_sts(dma_wr_desc_sts),

    /*
     * RAM interface (from DMA interface)
     */
    .dma_ram_wr(dma_ram_wr),
    .dma_ram_rd(dma_ram_rd),

    /*
     * RAM interface (towards RAM)
     */
    .client_ram_wr(dma_ram_int),
    .client_ram_rd(dma_ram_int)
);

for (genvar p = 0; p < PORTS; p = p + 1) begin : port

    cndm_micro_port #(
        .PTP_TS_EN(PTP_TS_EN),
        .PTP_TS_FMT_TOD(PTP_TS_FMT_TOD)
    )
    port_inst (
        .clk(clk),
        .rst(rst),

        /*
         * Control register interface
         */
        .s_axil_wr(s_axil_ctrl[PORT_OFFSET+p]),
        .s_axil_rd(s_axil_ctrl[PORT_OFFSET+p]),

        /*
         * DMA
         */
        .dma_rd_desc_req(dma_rd_desc_int[p]),
        .dma_rd_desc_sts(dma_rd_desc_int[p]),
        .dma_wr_desc_req(dma_wr_desc_int[p]),
        .dma_wr_desc_sts(dma_wr_desc_int[p]),
        .dma_ram_wr(dma_ram_int[p]),
        .dma_ram_rd(dma_ram_int[p]),

        .irq(irq[p]),

        /*
         * PTP
         */
        .ptp_clk(ptp_clk),
        .ptp_rst(ptp_rst),
        .ptp_td_sdi(ptp_td_sdo),

        /*
         * Ethernet
         */
        .mac_tx_clk(mac_tx_clk[p]),
        .mac_tx_rst(mac_tx_rst[p]),
        .mac_axis_tx(mac_axis_tx[p]),
        .mac_axis_tx_cpl(mac_axis_tx_cpl[p]),

        .mac_rx_clk(mac_rx_clk[p]),
        .mac_rx_rst(mac_rx_rst[p]),
        .mac_axis_rx(mac_axis_rx[p])
    );

end

endmodule

`resetall
