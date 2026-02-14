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
    parameter logic PTP_TS_EN = 1'b1,
    parameter logic PTP_TS_FMT_TOD = 1'b0
)
(
    input  wire logic         clk,
    input  wire logic         rst,

    /*
     * Control register interface
     */
    taxi_axil_if.wr_slv       s_axil_wr,
    taxi_axil_if.rd_slv       s_axil_rd,

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

localparam AXIL_ADDR_W = s_axil_wr.ADDR_W;
localparam AXIL_DATA_W = s_axil_wr.DATA_W;

localparam RAM_SEGS = dma_ram_wr.SEGS;
localparam RAM_SEG_ADDR_W = dma_ram_wr.SEG_ADDR_W;
localparam RAM_SEG_DATA_W = dma_ram_wr.SEG_DATA_W;
localparam RAM_SEG_BE_W = dma_ram_wr.SEG_BE_W;
localparam RAM_SEL_W = dma_ram_wr.SEL_W;

logic         txq_en_reg = '0;
logic [3:0]   txq_size_reg = '0;
logic [63:0]  txq_base_addr_reg = '0;
logic [15:0]  txq_prod_reg = '0;
wire [15:0]   txq_cons;
logic         rxq_en_reg = '0;
logic [3:0]   rxq_size_reg = '0;
logic [63:0]  rxq_base_addr_reg = '0;
logic [15:0]  rxq_prod_reg = '0;
wire [15:0]   rxq_cons;

logic         txcq_en_reg = '0;
logic [3:0]   txcq_size_reg = '0;
logic [63:0]  txcq_base_addr_reg = '0;
wire [15:0]   txcq_prod;
logic         rxcq_en_reg = '0;
logic [3:0]   rxcq_size_reg = '0;
logic [63:0]  rxcq_base_addr_reg = '0;
wire [15:0]   rxcq_prod;

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

    if (s_axil_wr.awvalid && s_axil_wr.wvalid && !s_axil_bvalid_reg) begin
        s_axil_awready_reg <= 1'b1;
        s_axil_wready_reg <= 1'b1;
        s_axil_bvalid_reg <= 1'b1;

        case ({s_axil_wr.awaddr[15:2], 2'b00})
            16'h0100: begin
                txq_en_reg <= s_axil_wr.wdata[0];
                txq_size_reg <= s_axil_wr.wdata[19:16];
            end
            16'h0104: txq_prod_reg <= s_axil_wr.wdata[15:0];
            16'h0108: txq_base_addr_reg[31:0] <= s_axil_wr.wdata;
            16'h010c: txq_base_addr_reg[63:32] <= s_axil_wr.wdata;

            16'h0200: begin
                rxq_en_reg <= s_axil_wr.wdata[0];
                rxq_size_reg <= s_axil_wr.wdata[19:16];
            end
            16'h0204: rxq_prod_reg <= s_axil_wr.wdata[15:0];
            16'h0208: rxq_base_addr_reg[31:0] <= s_axil_wr.wdata;
            16'h020c: rxq_base_addr_reg[63:32] <= s_axil_wr.wdata;

            16'h0300: begin
                txcq_en_reg <= s_axil_wr.wdata[0];
                txcq_size_reg <= s_axil_wr.wdata[19:16];
            end
            16'h0308: txcq_base_addr_reg[31:0] <= s_axil_wr.wdata;
            16'h030c: txcq_base_addr_reg[63:32] <= s_axil_wr.wdata;

            16'h0400: begin
                rxcq_en_reg <= s_axil_wr.wdata[0];
                rxcq_size_reg <= s_axil_wr.wdata[19:16];
            end
            16'h0408: rxcq_base_addr_reg[31:0] <= s_axil_wr.wdata;
            16'h040c: rxcq_base_addr_reg[63:32] <= s_axil_wr.wdata;
            default: begin end
        endcase
    end

    if (s_axil_rd.arvalid && !s_axil_rvalid_reg) begin
        s_axil_rdata_reg <= '0;

        s_axil_arready_reg <= 1'b1;
        s_axil_rvalid_reg <= 1'b1;

        case ({s_axil_rd.araddr[15:2], 2'b00})
            16'h0100: begin
                s_axil_rdata_reg[0] <= txq_en_reg;
                s_axil_rdata_reg[19:16] <= txq_size_reg;
            end
            16'h0104: begin
                s_axil_rdata_reg[15:0] <= txq_prod_reg;
                s_axil_rdata_reg[31:16] <= txq_cons;
            end
            16'h0108: s_axil_rdata_reg <= txq_base_addr_reg[31:0];
            16'h010c: s_axil_rdata_reg <= txq_base_addr_reg[63:32];

            16'h0200: begin
                s_axil_rdata_reg[0] <= rxq_en_reg;
                s_axil_rdata_reg[19:16] <= rxq_size_reg;
            end
            16'h0204: begin
                s_axil_rdata_reg[15:0] <= rxq_prod_reg;
                s_axil_rdata_reg[31:16] <= rxq_cons;
            end
            16'h0208: s_axil_rdata_reg <= rxq_base_addr_reg[31:0];
            16'h020c: s_axil_rdata_reg <= rxq_base_addr_reg[63:32];

            16'h0300: begin
                s_axil_rdata_reg[0] <= txcq_en_reg;
                s_axil_rdata_reg[19:16] <= txcq_size_reg;
            end
            16'h0304: s_axil_rdata_reg[15:0] <= txcq_prod;
            16'h0308: s_axil_rdata_reg <= txcq_base_addr_reg[31:0];
            16'h030c: s_axil_rdata_reg <= txcq_base_addr_reg[63:32];

            16'h0400: begin
                s_axil_rdata_reg[0] <= rxcq_en_reg;
                s_axil_rdata_reg[19:16] <= rxcq_size_reg;
            end
            16'h0404: s_axil_rdata_reg[15:0] <= rxcq_prod;
            16'h0408: s_axil_rdata_reg <= rxcq_base_addr_reg[31:0];
            16'h040c: s_axil_rdata_reg <= rxcq_base_addr_reg[63:32];
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

wire [1:0] desc_req;

taxi_axis_if #(
    .DATA_W(16*8),
    .KEEP_EN(1),
    .LAST_EN(1),
    .ID_EN(0),
    .DEST_EN(1), // TODO
    .USER_EN(1),
    .USER_W(1)
) axis_desc[2]();

taxi_axis_if #(
    .DATA_W(16*8),
    .KEEP_EN(1),
    .LAST_EN(1),
    .ID_EN(1), // TODO
    .DEST_EN(0),
    .USER_EN(0)
) axis_cpl[2]();

cndm_micro_desc_rd
desc_rd_inst (
    .clk(clk),
    .rst(rst),

    /*
     * DMA
     */
    .dma_rd_desc_req(dma_rd_desc_int[0]),
    .dma_rd_desc_sts(dma_rd_desc_int[0]),
    .dma_ram_wr(dma_ram_wr_int[0]),

    .txq_en(txq_en_reg),
    .txq_size(txq_size_reg),
    .txq_base_addr(txq_base_addr_reg),
    .txq_prod(txq_prod_reg),
    .txq_cons(txq_cons),
    .rxq_en(rxq_en_reg),
    .rxq_size(rxq_size_reg),
    .rxq_base_addr(rxq_base_addr_reg),
    .rxq_prod(rxq_prod_reg),
    .rxq_cons(rxq_cons),

    .desc_req(desc_req),
    .axis_desc(axis_desc)
);

cndm_micro_cpl_wr
cpl_wr_inst (
    .clk(clk),
    .rst(rst),

    /*
     * DMA
     */
    .dma_wr_desc_req(dma_wr_desc_int[0]),
    .dma_wr_desc_sts(dma_wr_desc_int[0]),
    .dma_ram_rd(dma_ram_rd_int[0]),

    .txcq_en(txcq_en_reg),
    .txcq_size(txcq_size_reg),
    .txcq_base_addr(txcq_base_addr_reg),
    .txcq_prod(txcq_prod),
    .rxcq_en(rxcq_en_reg),
    .rxcq_size(rxcq_size_reg),
    .rxcq_base_addr(rxcq_base_addr_reg),
    .rxcq_prod(rxcq_prod),

    .axis_cpl(axis_cpl),
    .irq(irq)
);

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
    .axis_desc(axis_desc[0]),
    .tx_data(mac_tx_int),
    .tx_cpl(mac_tx_cpl_int),
    .axis_cpl(axis_cpl[0])
);

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
    .axis_desc(axis_desc[1]),
    .axis_cpl(axis_cpl[1])
);

endmodule

`resetall
