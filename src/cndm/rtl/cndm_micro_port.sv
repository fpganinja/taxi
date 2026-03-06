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
 * Corundum-micro port module
 */
module cndm_micro_port #(
    // Queue configuration
    parameter WQN_W = 5,
    parameter CQN_W = WQN_W,

    // PTP configuration
    parameter logic PTP_TS_EN = 1'b1,
    parameter logic PTP_TS_FMT_TOD = 1'b0
)
(
    input  wire logic         clk,
    input  wire logic         rst,

    /*
     * Control register interface
     */
    taxi_axil_if.wr_slv       s_axil_ctrl_wr,
    taxi_axil_if.rd_slv       s_axil_ctrl_rd,

    /*
     * Datapath control register interface
     */
    taxi_apb_if.slv           s_apb_dp_ctrl,

    /*
     * DMA
     */
    taxi_dma_desc_if.req_src  dma_rd_desc_req,
    taxi_dma_desc_if.sts_snk  dma_rd_desc_sts,
    taxi_dma_desc_if.req_src  dma_wr_desc_req,
    taxi_dma_desc_if.sts_snk  dma_wr_desc_sts,
    taxi_dma_ram_if.wr_slv    dma_ram_wr,
    taxi_dma_ram_if.rd_slv    dma_ram_rd,

    output wire logic         irq,

    /*
     * PTP
     */
    input  wire logic         ptp_clk = 1'b0,
    input  wire logic         ptp_rst = 1'b0,
    input  wire logic         ptp_td_sdi = 1'b0,

    /*
     * Ethernet
     */
    input  wire logic         mac_tx_clk,
    input  wire logic         mac_tx_rst,
    taxi_axis_if.src          mac_axis_tx,
    taxi_axis_if.snk          mac_axis_tx_cpl,

    input  wire logic         mac_rx_clk,
    input  wire logic         mac_rx_rst,
    taxi_axis_if.snk          mac_axis_rx
);

localparam AXIL_ADDR_W = s_axil_ctrl_wr.ADDR_W;
localparam AXIL_DATA_W = s_axil_ctrl_wr.DATA_W;

localparam RAM_SEGS = dma_ram_wr.SEGS;
localparam RAM_SEG_ADDR_W = dma_ram_wr.SEG_ADDR_W;
localparam RAM_SEG_DATA_W = dma_ram_wr.SEG_DATA_W;
localparam RAM_SEG_BE_W = dma_ram_wr.SEG_BE_W;
localparam RAM_SEL_W = dma_ram_wr.SEL_W;

taxi_axil_if #(
    .DATA_W(s_axil_ctrl_wr.DATA_W),
    .ADDR_W(15),
    .STRB_W(s_axil_ctrl_wr.STRB_W),
    .AWUSER_EN(s_axil_ctrl_wr.AWUSER_EN),
    .AWUSER_W(s_axil_ctrl_wr.AWUSER_W),
    .WUSER_EN(s_axil_ctrl_wr.WUSER_EN),
    .WUSER_W(s_axil_ctrl_wr.WUSER_W),
    .BUSER_EN(s_axil_ctrl_wr.BUSER_EN),
    .BUSER_W(s_axil_ctrl_wr.BUSER_W),
    .ARUSER_EN(s_axil_ctrl_wr.ARUSER_EN),
    .ARUSER_W(s_axil_ctrl_wr.ARUSER_W),
    .RUSER_EN(s_axil_ctrl_wr.RUSER_EN),
    .RUSER_W(s_axil_ctrl_wr.RUSER_W)
)
axil_ctrl[2]();

taxi_axil_interconnect_1s #(
    .M_COUNT($size(axil_ctrl)),
    .ADDR_W(s_axil_ctrl_wr.ADDR_W),
    .M_REGIONS(1),
    .M_BASE_ADDR('0),
    .M_ADDR_W({$size(axil_ctrl){{1{32'd15}}}}),
    .M_SECURE({$size(axil_ctrl){1'b0}})
)
port_intercon_inst (
    .clk(clk),
    .rst(rst),

    /*
     * AXI4-lite slave interface
     */
    .s_axil_wr(s_axil_ctrl_wr),
    .s_axil_rd(s_axil_ctrl_rd),

    /*
     * AXI4-lite master interfaces
     */
    .m_axil_wr(axil_ctrl),
    .m_axil_rd(axil_ctrl)
);

taxi_apb_if #(
    .DATA_W(32),
    .ADDR_W(15)
)
apb_dp_ctrl[2]();

taxi_apb_interconnect #(
    .M_CNT($size(apb_dp_ctrl)),
    .ADDR_W(s_apb_dp_ctrl.ADDR_W),
    .M_REGIONS(1),
    .M_BASE_ADDR('0),
    .M_ADDR_W({$size(apb_dp_ctrl){{1{32'd15}}}}),
    .M_SECURE({$size(apb_dp_ctrl){1'b0}})
)
port_dp_intercon_inst (
    .clk(clk),
    .rst(rst),

    /*
     * APB slave interface
     */
    .s_apb(s_apb_dp_ctrl),

    /*
     * APB master interfaces
     */
    .m_apb(apb_dp_ctrl)
);

taxi_dma_desc_if #(
    .SRC_ADDR_W(dma_rd_desc_req.SRC_ADDR_W),
    .SRC_SEL_EN(dma_rd_desc_req.SRC_SEL_EN),
    .SRC_SEL_W(dma_rd_desc_req.SRC_SEL_W),
    .SRC_ASID_EN(dma_rd_desc_req.SRC_ASID_EN),
    .DST_ADDR_W(dma_rd_desc_req.DST_ADDR_W),
    .DST_SEL_EN(dma_rd_desc_req.DST_SEL_EN),
    .DST_SEL_W(dma_rd_desc_req.DST_SEL_W-1),
    .DST_ASID_EN(dma_rd_desc_req.DST_ASID_EN),
    .IMM_EN(dma_rd_desc_req.IMM_EN),
    .LEN_W(dma_rd_desc_req.LEN_W),
    .TAG_W(dma_rd_desc_req.TAG_W-1),
    .ID_EN(dma_rd_desc_req.ID_EN),
    .DEST_EN(dma_rd_desc_req.DEST_EN),
    .USER_EN(dma_rd_desc_req.USER_EN)
) dma_rd_desc_int[2]();

taxi_dma_ram_if #(
    .SEGS(RAM_SEGS),
    .SEG_ADDR_W(RAM_SEG_ADDR_W),
    .SEG_DATA_W(RAM_SEG_DATA_W),
    .SEG_BE_W(RAM_SEG_BE_W),
    .SEL_W(RAM_SEL_W-1)
) dma_ram_wr_int[2]();

taxi_dma_if_mux_rd #(
    .PORTS(2),
    .ARB_ROUND_ROBIN(1),
    .ARB_LSB_HIGH_PRIO(1)
)
rd_dma_mux_inst (
    .clk(clk),
    .rst(rst),

    /*
     * DMA descriptors from clients
     */
    .client_req(dma_rd_desc_int),
    .client_sts(dma_rd_desc_int),

    /*
     * DMA descriptors to DMA engines
     */
    .dma_req(dma_rd_desc_req),
    .dma_sts(dma_rd_desc_sts),

    /*
     * RAM interface (from DMA interface)
     */
    .dma_ram_wr(dma_ram_wr),

    /*
     * RAM interface (towards RAM)
     */
    .client_ram_wr(dma_ram_wr_int)
);

taxi_dma_desc_if #(
    .SRC_ADDR_W(dma_wr_desc_req.SRC_ADDR_W),
    .SRC_SEL_EN(dma_wr_desc_req.SRC_SEL_EN),
    .SRC_SEL_W(dma_wr_desc_req.SRC_SEL_W-1),
    .SRC_ASID_EN(dma_wr_desc_req.SRC_ASID_EN),
    .DST_ADDR_W(dma_wr_desc_req.DST_ADDR_W),
    .DST_SEL_EN(dma_wr_desc_req.DST_SEL_EN),
    .DST_SEL_W(dma_wr_desc_req.DST_SEL_W),
    .DST_ASID_EN(dma_wr_desc_req.DST_ASID_EN),
    .IMM_EN(dma_wr_desc_req.IMM_EN),
    .IMM_W(dma_wr_desc_req.IMM_W),
    .LEN_W(dma_wr_desc_req.LEN_W),
    .TAG_W(dma_wr_desc_req.TAG_W-1),
    .ID_EN(dma_wr_desc_req.ID_EN),
    .DEST_EN(dma_wr_desc_req.DEST_EN),
    .USER_EN(dma_wr_desc_req.USER_EN)
) dma_wr_desc_int[2]();

taxi_dma_ram_if #(
    .SEGS(RAM_SEGS),
    .SEG_ADDR_W(RAM_SEG_ADDR_W),
    .SEG_DATA_W(RAM_SEG_DATA_W),
    .SEG_BE_W(RAM_SEG_BE_W),
    .SEL_W(RAM_SEL_W-1)
) dma_ram_rd_int[2]();

taxi_dma_if_mux_wr #(
    .PORTS(2),
    .ARB_ROUND_ROBIN(1),
    .ARB_LSB_HIGH_PRIO(1)
)
wr_dma_mux_inst (
    .clk(clk),
    .rst(rst),

    /*
     * DMA descriptors from clients
     */
    .client_req(dma_wr_desc_int),
    .client_sts(dma_wr_desc_int),

    /*
     * DMA descriptors to DMA engines
     */
    .dma_req(dma_wr_desc_req),
    .dma_sts(dma_wr_desc_sts),

    /*
     * RAM interface (from DMA interface)
     */
    .dma_ram_rd(dma_ram_rd),

    /*
     * RAM interface (towards RAM)
     */
    .client_ram_rd(dma_ram_rd_int)
);

// descriptor fetch
wire [1:0] desc_req;

taxi_axis_if #(
    .DATA_W(16*8),
    .KEEP_EN(1),
    .LAST_EN(1),
    .ID_EN(1),
    .ID_W(1),
    .DEST_EN(1),
    .DEST_W(WQN_W),
    .USER_EN(1),
    .USER_W(1)
) axis_desc();

cndm_micro_desc_rd #(
    .WQN_W(WQN_W),
    .CQN_W(CQN_W)
)
desc_rd_inst (
    .clk(clk),
    .rst(rst),

    /*
     * Control register interface
     */
    .s_axil_ctrl_wr(axil_ctrl[0]),
    .s_axil_ctrl_rd(axil_ctrl[0]),

    /*
     * Datapath control register interface
     */
    .s_apb_dp_ctrl(apb_dp_ctrl[0]),

    /*
     * DMA
     */
    .dma_rd_desc_req(dma_rd_desc_int[0]),
    .dma_rd_desc_sts(dma_rd_desc_int[0]),
    .dma_ram_wr(dma_ram_wr_int[0]),

    .desc_req(desc_req),
    .m_axis_desc(axis_desc)
);

// desc demux
taxi_axis_if #(
    .DATA_W(axis_desc.DATA_W),
    .KEEP_EN(axis_desc.KEEP_EN),
    .KEEP_W(axis_desc.KEEP_W),
    .LAST_EN(axis_desc.LAST_EN),
    .ID_EN(axis_desc.ID_EN),
    .ID_W(axis_desc.ID_W),
    .DEST_EN(axis_desc.DEST_EN),
    .DEST_W(axis_desc.DEST_W),
    .USER_EN(axis_desc.USER_EN),
    .USER_W(axis_desc.USER_W)
) axis_desc_txrx[2]();

taxi_axis_demux #(
    .M_COUNT(2),
    .TID_ROUTE(1)
)
desc_demux_inst (
    .clk(clk),
    .rst(rst),

    /*
     * AXI4-Stream input (sink)
     */
    .s_axis(axis_desc),

    /*
     * AXI4-Stream output (source)
     */
    .m_axis(axis_desc_txrx),

    /*
     * Control
     */
    .enable(1'b1),
    .drop(1'b0),
    .select('0)
);

// completion write
taxi_axis_if #(
    .DATA_W(16*8),
    .KEEP_EN(1),
    .LAST_EN(1),
    .ID_EN(0),
    .DEST_EN(1),
    .DEST_W(CQN_W),
    .USER_EN(0)
) axis_cpl();

taxi_axis_if #(
    .DATA_W(axis_cpl.DATA_W),
    .KEEP_EN(axis_cpl.KEEP_EN),
    .KEEP_W(axis_cpl.KEEP_W),
    .LAST_EN(axis_cpl.LAST_EN),
    .ID_EN(axis_cpl.ID_EN),
    .ID_W(axis_cpl.ID_W),
    .DEST_EN(axis_cpl.DEST_EN),
    .DEST_W(axis_cpl.DEST_W),
    .USER_EN(axis_cpl.USER_EN),
    .USER_W(axis_cpl.USER_W)
) axis_cpl_txrx[2]();

taxi_axis_arb_mux #(
    .S_COUNT(2),
    .ARB_ROUND_ROBIN(1),
    .ARB_LSB_HIGH_PRIO(1)
)
cpl_mux_inst (
    .clk(clk),
    .rst(rst),

    /*
     * AXI4-Stream input (sink)
     */
    .s_axis(axis_cpl_txrx),

    /*
     * AXI4-Stream output (source)
     */
    .m_axis(axis_cpl)
);

cndm_micro_cpl_wr #(
    .CQN_W(CQN_W)
)
cpl_wr_inst (
    .clk(clk),
    .rst(rst),

    /*
     * Control register interface
     */
    .s_axil_ctrl_wr(axil_ctrl[1]),
    .s_axil_ctrl_rd(axil_ctrl[1]),

    /*
     * Datapath control register interface
     */
    .s_apb_dp_ctrl(apb_dp_ctrl[1]),

    /*
     * DMA
     */
    .dma_wr_desc_req(dma_wr_desc_int[0]),
    .dma_wr_desc_sts(dma_wr_desc_int[0]),
    .dma_ram_rd(dma_ram_rd_int[0]),

    .s_axis_cpl(axis_cpl),
    .irq(irq)
);

// TX path
taxi_axis_if #(
    .DATA_W(mac_axis_tx.DATA_W),
    .USER_EN(1),
    .USER_W(1)
) mac_tx_int();

taxi_axis_async_fifo #(
    .DEPTH(16384),
    .RAM_PIPELINE(2),
    .FRAME_FIFO(1),
    .USER_BAD_FRAME_VALUE(1'b1),
    .USER_BAD_FRAME_MASK(1'b1),
    .DROP_OVERSIZE_FRAME(1),
    .DROP_BAD_FRAME(1),
    .DROP_WHEN_FULL(1)
)
tx_fifo (
    /*
     * AXI4-Stream input (sink)
     */
    .s_clk(clk),
    .s_rst(rst),
    .s_axis(mac_tx_int),

    /*
     * AXI4-Stream output (source)
     */
    .m_clk(mac_tx_clk),
    .m_rst(mac_tx_rst),
    .m_axis(mac_axis_tx),

    /*
     * Pause
     */
    .s_pause_req(1'b0),
    .s_pause_ack(),
    .m_pause_req(1'b0),
    .m_pause_ack(),

    /*
     * Status
     */
    .s_status_depth(),
    .s_status_depth_commit(),
    .s_status_overflow(),
    .s_status_bad_frame(),
    .s_status_good_frame(),
    .m_status_depth(),
    .m_status_depth_commit(),
    .m_status_overflow(),
    .m_status_bad_frame(),
    .m_status_good_frame()
);

taxi_axis_if #(
    .DATA_W(mac_axis_tx_cpl.DATA_W),
    .KEEP_EN(mac_axis_tx_cpl.KEEP_EN),
    .KEEP_W(mac_axis_tx_cpl.KEEP_W),
    .USER_EN(1),
    .USER_W(mac_axis_tx_cpl.USER_W)
)
mac_tx_cpl_int();

taxi_axis_async_fifo #(
    .DEPTH(256),
    .RAM_PIPELINE(2),
    .FRAME_FIFO(0),
    .USER_BAD_FRAME_VALUE(1'b1),
    .USER_BAD_FRAME_MASK(1'b1),
    .DROP_OVERSIZE_FRAME(0),
    .DROP_BAD_FRAME(0),
    .DROP_WHEN_FULL(0)
)
tx_cpl_fifo (
    /*
     * AXI4-Stream input (sink)
     */
    .s_clk(mac_tx_clk),
    .s_rst(mac_tx_rst),
    .s_axis(mac_axis_tx_cpl),

    /*
     * AXI4-Stream output (source)
     */
    .m_clk(clk),
    .m_rst(rst),
    .m_axis(mac_tx_cpl_int),

    /*
     * Pause
     */
    .s_pause_req(1'b0),
    .s_pause_ack(),
    .m_pause_req(1'b0),
    .m_pause_ack(),

    /*
     * Status
     */
    .s_status_depth(),
    .s_status_depth_commit(),
    .s_status_overflow(),
    .s_status_bad_frame(),
    .s_status_good_frame(),
    .m_status_depth(),
    .m_status_depth_commit(),
    .m_status_overflow(),
    .m_status_bad_frame(),
    .m_status_good_frame()
);

cndm_micro_tx #(
    .PTP_TS_EN(PTP_TS_EN),
    .PTP_TS_FMT_TOD(PTP_TS_FMT_TOD)
)
tx_inst (
    .clk(clk),
    .rst(rst),

    /*
     * PTP
     */
    .ptp_clk(ptp_clk),
    .ptp_rst(ptp_rst),
    .ptp_td_sdi(ptp_td_sdi),

    /*
     * DMA
     */
    .dma_rd_desc_req(dma_rd_desc_int[1]),
    .dma_rd_desc_sts(dma_rd_desc_int[1]),
    .dma_ram_wr(dma_ram_wr_int[1]),

    .desc_req(desc_req[0]),
    .s_axis_desc(axis_desc_txrx[0]),
    .tx_data(mac_tx_int),
    .tx_cpl(mac_tx_cpl_int),
    .m_axis_cpl(axis_cpl_txrx[0])
);

// RX path
taxi_axis_if #(
    .DATA_W(mac_axis_rx.DATA_W),
    .USER_EN(1),
    .USER_W(mac_axis_rx.USER_W)
) mac_rx_int();

taxi_axis_async_fifo #(
    .DEPTH(16384),
    .RAM_PIPELINE(2),
    .FRAME_FIFO(1),
    .USER_BAD_FRAME_VALUE(1'b1),
    .USER_BAD_FRAME_MASK(1'b1),
    .DROP_OVERSIZE_FRAME(1),
    .DROP_BAD_FRAME(1),
    .DROP_WHEN_FULL(1)
)
rx_fifo (
    /*
     * AXI4-Stream input (sink)
     */
    .s_clk(mac_rx_clk),
    .s_rst(mac_rx_rst),
    .s_axis(mac_axis_rx),

    /*
     * AXI4-Stream output (source)
     */
    .m_clk(clk),
    .m_rst(rst),
    .m_axis(mac_rx_int),

    /*
     * Pause
     */
    .s_pause_req(1'b0),
    .s_pause_ack(),
    .m_pause_req(1'b0),
    .m_pause_ack(),

    /*
     * Status
     */
    .s_status_depth(),
    .s_status_depth_commit(),
    .s_status_overflow(),
    .s_status_bad_frame(),
    .s_status_good_frame(),
    .m_status_depth(),
    .m_status_depth_commit(),
    .m_status_overflow(),
    .m_status_bad_frame(),
    .m_status_good_frame()
);

cndm_micro_rx #(
    .PTP_TS_EN(PTP_TS_EN),
    .PTP_TS_FMT_TOD(PTP_TS_FMT_TOD)
)
rx_inst (
    .clk(clk),
    .rst(rst),

    /*
     * PTP
     */
    .ptp_clk(ptp_clk),
    .ptp_rst(ptp_rst),
    .ptp_td_sdi(ptp_td_sdi),

    /*
     * DMA
     */
    .dma_wr_desc_req(dma_wr_desc_int[1]),
    .dma_wr_desc_sts(dma_wr_desc_int[1]),
    .dma_ram_rd(dma_ram_rd_int[1]),

    .rx_data(mac_rx_int),
    .desc_req(desc_req[1]),
    .s_axis_desc(axis_desc_txrx[1]),
    .m_axis_cpl(axis_cpl_txrx[1])
);

endmodule

`resetall
