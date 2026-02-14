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
 * Corundum-micro receive datapath
 */
module cndm_micro_rx #(
    parameter logic PTP_TS_EN = 1'b1,
    parameter logic PTP_TS_FMT_TOD = 1'b0
)
(
    input  wire logic         clk,
    input  wire logic         rst,

    /*
     * PTP
     */
    input  wire logic         ptp_clk = 1'b0,
    input  wire logic         ptp_rst = 1'b0,
    input  wire logic         ptp_td_sdi = 1'b0,

    /*
     * DMA
     */
    taxi_dma_desc_if.req_src  dma_wr_desc_req,
    taxi_dma_desc_if.sts_snk  dma_wr_desc_sts,
    taxi_dma_ram_if.rd_slv    dma_ram_rd,

    taxi_axis_if.snk          rx_data,
    output wire logic         desc_req,
    taxi_axis_if.snk          axis_desc,
    taxi_axis_if.src          axis_cpl
);

localparam RAM_ADDR_W = 16;

taxi_dma_desc_if #(
    .SRC_ADDR_W(RAM_ADDR_W),
    .SRC_SEL_EN(1'b0),
    .SRC_ASID_EN(1'b0),
    .DST_ADDR_W(RAM_ADDR_W),
    .DST_SEL_EN(1'b0),
    .DST_ASID_EN(1'b0),
    .IMM_EN(1'b0),
    .LEN_W(16),
    .TAG_W(1),
    .ID_EN(0),
    .DEST_EN(0),
    .USER_EN(1),
    .USER_W(rx_data.USER_W)
) dma_desc();

localparam [2:0]
    STATE_IDLE = 0,
    STATE_RX_DATA = 1,
    STATE_READ_DESC = 2,
    STATE_WRITE_DATA = 3;

logic [2:0] state_reg = STATE_IDLE;

logic desc_req_reg = 1'b0;

assign desc_req = desc_req_reg;

wire [95:0] rx_ptp_ts;
wire rx_ptp_ts_valid;

if (PTP_TS_EN) begin

    if (PTP_TS_FMT_TOD) begin

        assign rx_ptp_ts = dma_desc.sts_user[dma_desc.USER_W-1:1];
        assign rx_ptp_ts_valid = dma_desc.sts_valid;

    end else begin

        taxi_axis_if #(
            .DATA_W(48),
            .KEEP_EN(0),
            .KEEP_W(1),
            .STRB_EN(0),
            .LAST_EN(0),
            .ID_EN(0),
            .DEST_EN(0),
            .USER_EN(1),
            .USER_W(1)
        ) ptp_ts_rel();

        assign ptp_ts_rel.tdata = dma_desc.sts_user[dma_desc.USER_W-1:1];
        assign ptp_ts_rel.tuser = dma_desc.sts_user[0];
        assign ptp_ts_rel.tvalid = dma_desc.sts_valid;

        taxi_axis_if #(
            .DATA_W(96),
            .KEEP_EN(0),
            .KEEP_W(1),
            .STRB_EN(0),
            .LAST_EN(0),
            .ID_EN(0),
            .DEST_EN(0),
            .USER_EN(1),
            .USER_W(1)
        ) ptp_ts_tod();

        assign rx_ptp_ts = ptp_ts_tod.tdata;
        assign rx_ptp_ts_valid = ptp_ts_tod.tvalid;

        taxi_ptp_td_rel2tod #(
            .TS_FNS_W(16),
            .TS_REL_NS_W(ptp_ts_rel.DATA_W-16),
            .TS_TOD_S_W(48),
            .TS_REL_W(ptp_ts_rel.DATA_W),
            .TS_TOD_W(96),
            .TD_SDI_PIPELINE(2)
        )
        rel2tod_inst (
            .clk(clk),
            .rst(rst),

            /*
            * PTP clock interface
            */
            .ptp_clk(ptp_clk),
            .ptp_rst(ptp_rst),
            .ptp_td_sdi(ptp_td_sdi),

            /*
            * Timestamp conversion
            */
            .s_axis_ts_rel(ptp_ts_rel),
            .m_axis_ts_tod(ptp_ts_tod)
        );

    end

end else begin

    assign rx_ptp_ts = '0;
    assign rx_ptp_ts_valid = 1'b0;

end

always_ff @(posedge clk) begin
    desc_req_reg <= 1'b0;

    axis_desc.tready <= 1'b0;

    dma_wr_desc_req.req_src_sel <= '0;
    dma_wr_desc_req.req_src_asid <= '0;
    dma_wr_desc_req.req_dst_sel <= '0;
    dma_wr_desc_req.req_dst_asid <= '0;
    dma_wr_desc_req.req_imm <= '0;
    dma_wr_desc_req.req_imm_en <= '0;
    dma_wr_desc_req.req_tag <= '0;
    dma_wr_desc_req.req_id <= '0;
    dma_wr_desc_req.req_dest <= '0;
    dma_wr_desc_req.req_user <= '0;
    dma_wr_desc_req.req_valid <= dma_wr_desc_req.req_valid && !dma_wr_desc_req.req_ready;

    dma_desc.req_src_addr <= '0;
    dma_desc.req_src_sel <= '0;
    dma_desc.req_src_asid <= '0;
    dma_desc.req_dst_addr <= '0;
    dma_desc.req_dst_sel <= '0;
    dma_desc.req_dst_asid <= '0;
    dma_desc.req_imm <= '0;
    dma_desc.req_imm_en <= '0;
    dma_desc.req_len <= 4096;
    dma_desc.req_tag <= '0;
    dma_desc.req_id <= '0;
    dma_desc.req_dest <= '0;
    dma_desc.req_user <= '0;
    dma_desc.req_valid <= dma_desc.req_valid && !dma_desc.req_ready;

    axis_cpl.tkeep <= '0;
    axis_cpl.tid <= '0;
    axis_cpl.tdest <= '0;
    axis_cpl.tuser <= '0;
    axis_cpl.tlast <= 1'b1;
    axis_cpl.tvalid <= axis_cpl.tvalid && !axis_cpl.tready;

    if (rx_ptp_ts_valid) begin
        axis_cpl.tdata[127:112] <= rx_ptp_ts[63:48]; // sec
        axis_cpl.tdata[95:64]   <= rx_ptp_ts[47:16]; // ns
        axis_cpl.tdata[111:96]  <= rx_ptp_ts[15:0];  // fns
    end

    case (state_reg)
        STATE_IDLE: begin
            dma_desc.req_valid <= 1'b1;
            state_reg <= STATE_RX_DATA;
        end
        STATE_RX_DATA: begin
            dma_wr_desc_req.req_len <= 20'(dma_desc.sts_len);
            axis_cpl.tdata[47:32] <= 16'(dma_desc.sts_len);
            if (dma_desc.sts_valid) begin
                desc_req_reg <= 1'b1;
                state_reg <= STATE_READ_DESC;
            end
        end
        STATE_READ_DESC: begin
            axis_desc.tready <= 1'b1;

            dma_wr_desc_req.req_src_addr <= '0;
            dma_wr_desc_req.req_dst_addr <= axis_desc.tdata[127:64];

            if (axis_desc.tvalid && axis_desc.tready) begin
                if (dma_wr_desc_req.req_len > 20'(axis_desc.tdata[47:32])) begin
                    dma_wr_desc_req.req_len <= 20'(axis_desc.tdata[47:32]);
                end

                if (axis_desc.tuser) begin
                    // failed to read desc
                    state_reg <= STATE_IDLE;
                end else begin
                    dma_wr_desc_req.req_valid <= 1'b1;
                    state_reg <= STATE_WRITE_DATA;
                end
            end
        end
        STATE_WRITE_DATA: begin
            if (dma_wr_desc_sts.sts_valid) begin
                axis_cpl.tvalid <= 1'b1;
                state_reg <= STATE_IDLE;
            end
        end
        default: begin
            state_reg <= STATE_IDLE;
        end
    endcase

    if (rst) begin
        state_reg <= STATE_IDLE;
    end
end

taxi_dma_ram_if #(
    .SEGS(dma_ram_rd.SEGS),
    .SEG_ADDR_W(dma_ram_rd.SEG_ADDR_W),
    .SEG_DATA_W(dma_ram_rd.SEG_DATA_W),
    .SEG_BE_W(dma_ram_rd.SEG_BE_W)
) dma_ram_wr();

taxi_dma_psdpram #(
    .SIZE(4096),
    .PIPELINE(2)
)
ram_inst (
    .clk(clk),
    .rst(rst),

    /*
     * Write port
     */
    .dma_ram_wr(dma_ram_wr),

    /*
     * Read port
     */
    .dma_ram_rd(dma_ram_rd)
);

taxi_dma_client_axis_sink
dma_inst (
    .clk(clk),
    .rst(rst),

    /*
     * DMA descriptor
     */
    .desc_req(dma_desc),
    .desc_sts(dma_desc),

    /*
     * AXI stream write data input
     */
    .s_axis_wr_data(rx_data),

    /*
     * RAM interface
     */
    .dma_ram_wr(dma_ram_wr),

    /*
     * Configuration
     */
    .enable(1),
    .abort(0)
);


endmodule

`resetall
