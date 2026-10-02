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
 * GMII PHY interface
 */
module taxi_gmii_phy_if #
(
    // simulation (set to avoid vendor primitives)
    parameter logic SIM = 1'b0,
    // vendor ("GENERIC", "XILINX", "ALTERA", "LATTICE")
    parameter VENDOR = "XILINX",
    // device family
    parameter FAMILY = "virtex7"
)
(
    input  wire logic        gtx_clk,
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
    input  wire logic [7:0]  mac_gmii_txd,
    input  wire logic        mac_gmii_tx_en,
    input  wire logic        mac_gmii_tx_er,

    /*
     * GMII interface to PHY
     */
    input  wire logic        phy_gmii_rx_clk,
    input  wire logic [7:0]  phy_gmii_rxd,
    input  wire logic        phy_gmii_rx_dv,
    input  wire logic        phy_gmii_rx_er,
    input  wire logic        phy_mii_tx_clk,
    output wire logic        phy_gmii_tx_clk,
    output wire logic [7:0]  phy_gmii_txd,
    output wire logic        phy_gmii_tx_en,
    output wire logic        phy_gmii_tx_er,

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

taxi_ssio_sdr_in #(
    .SIM(SIM),
    .VENDOR(VENDOR),
    .FAMILY(FAMILY),
    .WIDTH(10)
)
rx_ssio_sdr_inst (
    .input_clk(phy_gmii_rx_clk),
    .input_d({phy_gmii_rxd, phy_gmii_rx_dv, phy_gmii_rx_er}),
    .output_clk(mac_gmii_rx_clk),
    .output_q({mac_gmii_rxd, mac_gmii_rx_dv, mac_gmii_rx_er})
);

taxi_ssio_sdr_out #(
    .SIM(SIM),
    .VENDOR(VENDOR),
    .FAMILY(FAMILY),
    .WIDTH(10)
)
tx_ssio_sdr_inst (
    .clk(mac_gmii_tx_clk),
    .input_d({mac_gmii_txd, mac_gmii_tx_en, mac_gmii_tx_er}),
    .output_clk(phy_gmii_tx_clk),
    .output_q({phy_gmii_txd, phy_gmii_tx_en, phy_gmii_tx_er})
);

if (!SIM && VENDOR == "XILINX") begin
    // Xilinx/AMD device support

    BUFGMUX
    gmii_bufgmux_inst (
        .I0(phy_mii_tx_clk),
        .I1(gtx_clk),
        .S(link_speed_reg[1]),
        .O(mac_gmii_tx_clk)
    );

end else if (!SIM && VENDOR == "LATTICE") begin
    // Lattice device support
    // ecp5: DCSC in glitchless mode; SEL is one-hot (01 = CLK0, 10 = CLK1)

    DCSC #(
        .DCSMODE("POS")
    )
    gmii_dcsc_inst (
        .CLK0(phy_mii_tx_clk),
        .CLK1(gtx_clk),
        .SEL0(!link_speed_reg[1]),
        .SEL1(link_speed_reg[1]),
        .MODESEL(1'b0),
        .DCSOUT(mac_gmii_tx_clk)
    );

end else begin
    // generic/simulation implementation (no vendor primitives)

    assign mac_gmii_tx_clk = link_speed_reg[1] ? gtx_clk : phy_mii_tx_clk;

end

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
