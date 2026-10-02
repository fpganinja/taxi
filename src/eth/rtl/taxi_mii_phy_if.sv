// SPDX-License-Identifier: CERN-OHL-S-2.0
/*

Copyright (c) 2019-2025 FPGA Ninja, LLC

Authors:
- Alex Forencich

*/

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * MII PHY interface
 */
module taxi_mii_phy_if #
(
    // simulation (set to avoid vendor primitives)
    parameter logic SIM = 1'b0,
    // vendor ("GENERIC", "XILINX", "ALTERA", "LATTICE")
    parameter VENDOR = "XILINX",
    // device family
    parameter FAMILY = "virtex7"
)
(
    input  wire logic        rst,

    /*
     * MII interface to MAC
     */
    output wire logic        mac_mii_rx_clk,
    output wire logic        mac_mii_rx_rst,
    output wire logic [3:0]  mac_mii_rxd,
    output wire logic        mac_mii_rx_dv,
    output wire logic        mac_mii_rx_er,
    output wire logic        mac_mii_tx_clk,
    output wire logic        mac_mii_tx_rst,
    input  wire logic [3:0]  mac_mii_txd,
    input  wire logic        mac_mii_tx_en,
    input  wire logic        mac_mii_tx_er,

    /*
     * MII interface to PHY
     */
    input  wire logic        phy_mii_rx_clk,
    input  wire logic [3:0]  phy_mii_rxd,
    input  wire logic        phy_mii_rx_dv,
    input  wire logic        phy_mii_rx_er,
    input  wire logic        phy_mii_tx_clk,
    output wire logic [3:0]  phy_mii_txd,
    output wire logic        phy_mii_tx_en,
    output wire logic        phy_mii_tx_er
);

taxi_ssio_sdr_in #(
    .SIM(SIM),
    .VENDOR(VENDOR),
    .FAMILY(FAMILY),
    .WIDTH(6)
)
rx_ssio_sdr_inst (
    .input_clk(phy_mii_rx_clk),
    .input_d({phy_mii_rxd, phy_mii_rx_dv, phy_mii_rx_er}),
    .output_clk(mac_mii_rx_clk),
    .output_q({mac_mii_rxd, mac_mii_rx_dv, mac_mii_rx_er})
);

(* IOB = "TRUE" *)
logic [3:0] phy_mii_txd_reg = 4'd0;
(* IOB = "TRUE" *)
logic phy_mii_tx_en_reg = 1'b0, phy_mii_tx_er_reg = 1'b0;

assign phy_mii_txd = phy_mii_txd_reg;
assign phy_mii_tx_en = phy_mii_tx_en_reg;
assign phy_mii_tx_er = phy_mii_tx_er_reg;

always_ff @(posedge mac_mii_tx_clk) begin
    phy_mii_txd_reg <= mac_mii_txd;
    phy_mii_tx_en_reg <= mac_mii_tx_en;
    phy_mii_tx_er_reg <= mac_mii_tx_er;
end

generate

if (!SIM && VENDOR == "XILINX") begin
    // Xilinx/AMD device support

    BUFG
    mii_bufg_inst (
        .I(phy_mii_tx_clk),
        .O(mac_mii_tx_clk)
    );

end else begin
    // generic/simulation implementation (no vendor primitives)
    // also used for LATTICE (ecp5): no clock buffer primitive is needed

    assign mac_mii_tx_clk = phy_mii_tx_clk;

end

endgenerate

// reset sync
taxi_sync_reset #(
    .N(4)
)
tx_reset_sync_inst (
    .clk(mac_mii_tx_clk),
    .rst(rst),
    .out(mac_mii_tx_rst)
);

taxi_sync_reset #(
    .N(4)
)
rx_reset_sync_inst (
    .clk(mac_mii_rx_clk),
    .rst(rst),
    .out(mac_mii_rx_rst)
);

endmodule

`resetall
