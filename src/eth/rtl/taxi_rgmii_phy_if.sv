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
 * RGMII PHY interface
 */
module taxi_rgmii_phy_if #
(
    // simulation (set to avoid vendor primitives)
    parameter logic SIM = 1'b0,
    // vendor ("GENERIC", "XILINX", "ALTERA", "LATTICE")
    parameter VENDOR = "XILINX",
    // device family
    parameter FAMILY = "virtex7",
    // Use 90 degree clock for RGMII transmit
    parameter logic USE_CLK90 = 1'b1
)
(
    input  wire logic        gtx_clk,
    input  wire logic        gtx_clk90,
    input  wire logic        gtx_rst,

    /*
     * GMII interface to MAC
     */
    output wire logic        mac_gmii_rx_clk,
    output wire logic        mac_gmii_rx_rst,
    output wire logic [7:0]  mac_gmii_rxd,
    output wire logic        mac_gmii_rx_dv,
    output wire logic        mac_gmii_rx_er,
    output wire logic        mac_gmii_tx_clk,
    output wire logic        mac_gmii_tx_rst,
    output wire logic        mac_gmii_tx_clk_en,
    input  wire logic [7:0]  mac_gmii_txd,
    input  wire logic        mac_gmii_tx_en,
    input  wire logic        mac_gmii_tx_er,

    /*
     * RGMII interface to PHY
     */
    input  wire logic        phy_rgmii_rx_clk,
    input  wire logic [3:0]  phy_rgmii_rxd,
    input  wire logic        phy_rgmii_rx_ctl,
    output wire logic        phy_rgmii_tx_clk,
    output wire logic [3:0]  phy_rgmii_txd,
    output wire logic        phy_rgmii_tx_ctl,

    /*
     * Status
     */
    output wire logic [1:0]  link_speed
);

// PHY speed detection
logic [2:0] rx_prescale = 3'd0;

always_ff @(posedge mac_gmii_rx_clk) begin
    rx_prescale <= rx_prescale + 3'd1;
end

wire rx_prescale_sync;

taxi_sync_signal #(
    .WIDTH(1),
    .N(2)
)
rx_prescale_sync_inst (
    .clk(gtx_clk),
    .in(rx_prescale[2]),
    .out(rx_prescale_sync)
);

logic [6:0] rx_speed_count_1 = '0;
logic [1:0] rx_speed_count_2 = '0;
logic rx_prescale_sync_last_reg = 1'b0;

logic [1:0] link_speed_reg = '0;

assign link_speed = link_speed_reg;

always_ff @(posedge gtx_clk) begin
    rx_prescale_sync_last_reg <= rx_prescale_sync;
    rx_speed_count_1 <= rx_speed_count_1 + 1;

    if (rx_prescale_sync ^ rx_prescale_sync_last_reg) begin
        rx_speed_count_2 <= rx_speed_count_2 + 1;
    end

    if (&rx_speed_count_1) begin
        // reference count overflow - 10M
        rx_speed_count_1 <= '0;
        rx_speed_count_2 <= '0;
        link_speed_reg <= 2'b00;
    end

    if (&rx_speed_count_2) begin
        // prescaled count overflow - 100M or 1000M
        rx_speed_count_1 <= '0;
        rx_speed_count_2 <= '0;
        if (rx_speed_count_1[6:5] != 0) begin
            // large reference count - 100M
            link_speed_reg <= 2'b01;
        end else begin
            // small reference count - 1000M
            link_speed_reg <= 2'b10;
        end
    end

    if (gtx_rst) begin
        rx_speed_count_1 <= '0;
        rx_speed_count_2 <= '0;
        link_speed_reg <= 2'b10;
    end
end

// receive

wire rgmii_rx_ctl_1;
wire rgmii_rx_ctl_2;

taxi_ssio_ddr_in #(
    .SIM(SIM),
    .VENDOR(VENDOR),
    .FAMILY(FAMILY),
    .WIDTH(5)
)
rx_ssio_ddr_inst (
    .input_clk(phy_rgmii_rx_clk),
    .input_d({phy_rgmii_rxd, phy_rgmii_rx_ctl}),
    .output_clk(mac_gmii_rx_clk),
    .output_q1({mac_gmii_rxd[3:0], rgmii_rx_ctl_1}),
    .output_q2({mac_gmii_rxd[7:4], rgmii_rx_ctl_2})
);

assign mac_gmii_rx_dv = rgmii_rx_ctl_1;
assign mac_gmii_rx_er = rgmii_rx_ctl_1 ^ rgmii_rx_ctl_2;

// transmit

logic rgmii_tx_clk_1_reg = 1'b1;
logic rgmii_tx_clk_2_reg = 1'b0;
logic rgmii_tx_clk_en_reg = 1'b1;

logic [5:0] count_reg = 6'd0, count_next;

always_ff @(posedge gtx_clk) begin
    rgmii_tx_clk_1_reg <= rgmii_tx_clk_2_reg;

    if (link_speed_reg == 2'b00) begin
        // 10M
        count_reg <= count_reg + 1;
        rgmii_tx_clk_en_reg <= 1'b0;
        if (count_reg == 24) begin
            rgmii_tx_clk_1_reg <= 1'b1;
            rgmii_tx_clk_2_reg <= 1'b1;
        end else if (count_reg >= 49) begin
            rgmii_tx_clk_2_reg <= 1'b0;
            rgmii_tx_clk_en_reg <= 1'b1;
            count_reg <= 0;
        end
    end else if (link_speed_reg == 2'b01) begin
        // 100M
        count_reg <= count_reg + 1;
        rgmii_tx_clk_en_reg <= 1'b0;
        if (count_reg == 2) begin
            rgmii_tx_clk_1_reg <= 1'b1;
            rgmii_tx_clk_2_reg <= 1'b1;
        end else if (count_reg >= 4) begin
            rgmii_tx_clk_2_reg <= 1'b0;
            rgmii_tx_clk_en_reg <= 1'b1;
            count_reg <= 0;
        end
    end else begin
        // 1000M
        rgmii_tx_clk_1_reg <= 1'b1;
        rgmii_tx_clk_2_reg <= 1'b0;
        rgmii_tx_clk_en_reg <= 1'b1;
    end

    if (gtx_rst) begin
        rgmii_tx_clk_1_reg <= 1'b1;
        rgmii_tx_clk_2_reg <= 1'b0;
        rgmii_tx_clk_en_reg <= 1'b1;
        count_reg <= 0;
    end
end

logic [3:0] rgmii_txd_1;
logic [3:0] rgmii_txd_2;
logic rgmii_tx_ctl_1;
logic rgmii_tx_ctl_2;

logic gmii_clk_en;

always_comb begin
    if (link_speed_reg == 2'b00) begin
        // 10M
        rgmii_txd_1 = mac_gmii_txd[3:0];
        rgmii_txd_2 = mac_gmii_txd[3:0];
        if (rgmii_tx_clk_1_reg) begin
            rgmii_tx_ctl_1 = mac_gmii_tx_en ^ mac_gmii_tx_er;
            rgmii_tx_ctl_2 = mac_gmii_tx_en ^ mac_gmii_tx_er;
        end else begin
            rgmii_tx_ctl_1 = mac_gmii_tx_en;
            rgmii_tx_ctl_2 = mac_gmii_tx_en;
        end
        gmii_clk_en = rgmii_tx_clk_en_reg;
    end else if (link_speed_reg == 2'b01) begin
        // 100M
        rgmii_txd_1 = mac_gmii_txd[3:0];
        rgmii_txd_2 = mac_gmii_txd[3:0];
        if (rgmii_tx_clk_1_reg) begin
            rgmii_tx_ctl_1 = mac_gmii_tx_en ^ mac_gmii_tx_er;
            rgmii_tx_ctl_2 = mac_gmii_tx_en ^ mac_gmii_tx_er;
        end else begin
            rgmii_tx_ctl_1 = mac_gmii_tx_en;
            rgmii_tx_ctl_2 = mac_gmii_tx_en;
        end
        gmii_clk_en = rgmii_tx_clk_en_reg;
    end else begin
        // 1000M
        rgmii_txd_1 = mac_gmii_txd[3:0];
        rgmii_txd_2 = mac_gmii_txd[7:4];
        rgmii_tx_ctl_1 = mac_gmii_tx_en;
        rgmii_tx_ctl_2 = mac_gmii_tx_en ^ mac_gmii_tx_er;
        gmii_clk_en = 1'b1;
    end
end

taxi_oddr #(
    .SIM(SIM),
    .VENDOR(VENDOR),
    .FAMILY(FAMILY),
    .WIDTH(1)
)
clk_oddr_inst (
    .clk(USE_CLK90 ? gtx_clk90 : gtx_clk),
    .d1(rgmii_tx_clk_1_reg),
    .d2(rgmii_tx_clk_2_reg),
    .q(phy_rgmii_tx_clk)
);

taxi_oddr #(
    .SIM(SIM),
    .VENDOR(VENDOR),
    .FAMILY(FAMILY),
    .WIDTH(5)
)
data_oddr_inst (
    .clk(gtx_clk),
    .d1({rgmii_txd_1, rgmii_tx_ctl_1}),
    .d2({rgmii_txd_2, rgmii_tx_ctl_2}),
    .q({phy_rgmii_txd, phy_rgmii_tx_ctl})
);

assign mac_gmii_tx_clk = gtx_clk;

assign mac_gmii_tx_clk_en = gmii_clk_en;

// reset sync
taxi_sync_reset #(
    .N(4)
)
tx_reset_sync_inst (
    .clk(mac_gmii_tx_clk),
    .rst(gtx_rst),
    .out(mac_gmii_tx_rst)
);

taxi_sync_reset #(
    .N(4)
)
rx_reset_sync_inst (
    .clk(mac_gmii_rx_clk),
    .rst(gtx_rst),
    .out(mac_gmii_rx_rst)
);

endmodule

`resetall
