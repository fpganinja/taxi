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
 * Pyrite flashing support for UltraScale+ PCIe VSEC and BPI flash
 */
module pyrite_pcie_us_vsec_bpi #
(
    parameter logic [15:0] EXT_CAP_ID = 16'h000B,
    parameter logic [3:0]  EXT_CAP_VERSION = 4'h1,
    parameter logic [11:0] EXT_CAP_OFFSET = 12'h480,
    parameter logic [11:0] EXT_CAP_NEXT = 12'h000,
    parameter logic [15:0] EXT_CAP_VSEC_ID = 16'h00DB,
    parameter logic [3:0]  EXT_CAP_VSEC_REV = 4'h1,

    // FW ID
    parameter FPGA_ID = 32'hDEADBEEF,
    parameter FW_ID = 32'h00000000,
    parameter FW_VER = 32'h000_01_000,
    parameter BOARD_ID = 32'h1234_0000,
    parameter BOARD_VER = 32'h001_00_000,
    parameter BUILD_DATE = 32'd602976000,
    parameter GIT_HASH = 32'h5f87c2e8,
    parameter RELEASE_INFO = 32'h00000000,

    // Flash
    parameter logic [3:0] FLASH_SEG_COUNT = 2,
    parameter logic [3:0] FLASH_SEG_DEFAULT = 1,
    parameter logic [3:0] FLASH_SEG_FALLBACK = 0,
    parameter logic [31:0] FLASH_SEG0_SIZE = 32'h00000000,
    parameter FLASH_DATA_W = 16,
    parameter FLASH_ADDR_W = 23,
    parameter FLASH_RGN_W = 1
)
(
    input  wire logic                     clk,
    input  wire logic                     rst,

    /*
     * PCIe
     */
    input  wire logic                     cfg_ext_read_received,
    input  wire logic                     cfg_ext_write_received,
    input  wire logic [9:0]               cfg_ext_register_number,
    input  wire logic [7:0]               cfg_ext_function_number,
    input  wire logic [31:0]              cfg_ext_write_data,
    input  wire logic [3:0]               cfg_ext_write_byte_enable,
    output wire logic [31:0]              cfg_ext_read_data,
    output wire logic                     cfg_ext_read_data_valid,

    /*
     * BPI flash
     */
    output wire logic                     fpga_boot,
    input  wire logic [FLASH_DATA_W-1:0]  flash_dq_i,
    output wire logic [FLASH_DATA_W-1:0]  flash_dq_o,
    output wire logic                     flash_dq_oe,
    output wire logic [FLASH_ADDR_W-1:0]  flash_addr,
    output wire logic [FLASH_RGN_W-1:0]   flash_region,
    output wire logic                     flash_region_oe,
    output wire logic                     flash_ce_n,
    output wire logic                     flash_oe_n,
    output wire logic                     flash_we_n,
    output wire logic                     flash_adv_n
);

taxi_apb_if #(
    .DATA_W(32),
    .ADDR_W(16)
) vsec_apb();

taxi_pcie_us_vsec_apb #(
    .EXT_CAP_ID(EXT_CAP_ID),
    .EXT_CAP_VERSION(EXT_CAP_VERSION),
    .EXT_CAP_OFFSET(EXT_CAP_OFFSET),
    .EXT_CAP_NEXT(EXT_CAP_NEXT),
    .EXT_CAP_VSEC_ID(EXT_CAP_VSEC_ID),
    .EXT_CAP_VSEC_REV(EXT_CAP_VSEC_REV)
)
vsec_cap_inst (
    .clk(clk),
    .rst(rst),

    /*
     * APB interface for register space
     */
    .m_apb(vsec_apb),

    /*
     * Interface to Ultrascale PCIe IP core
     */
    .cfg_ext_read_received(cfg_ext_read_received),
    .cfg_ext_write_received(cfg_ext_write_received),
    .cfg_ext_register_number(cfg_ext_register_number),
    .cfg_ext_function_number(cfg_ext_function_number),
    .cfg_ext_write_data(cfg_ext_write_data),
    .cfg_ext_write_byte_enable(cfg_ext_write_byte_enable),
    .cfg_ext_read_data(cfg_ext_read_data),
    .cfg_ext_read_data_valid(cfg_ext_read_data_valid)
);

logic vsec_apb_pready_reg = 1'b0;
logic [31:0] vsec_apb_prdata_reg = '0;

logic fpga_boot_reg = 1'b0;

logic [FLASH_DATA_W-1:0] flash_dq_o_reg = '0;
logic flash_dq_oe_reg = 1'b0;
logic [FLASH_ADDR_W-1:0] flash_addr_reg = '0;
logic [FLASH_RGN_W-1:0] flash_region_reg = '0;
logic flash_region_oe_reg = 1'b0;
logic flash_ce_n_reg = 1'b1;
logic flash_oe_n_reg = 1'b1;
logic flash_we_n_reg = 1'b1;
logic flash_adv_n_reg = 1'b1;

assign vsec_apb.pready = vsec_apb_pready_reg;
assign vsec_apb.prdata = vsec_apb_prdata_reg;
assign vsec_apb.pslverr = 1'b0;
assign vsec_apb.pruser = '0;
assign vsec_apb.pbuser = '0;

assign fpga_boot = fpga_boot_reg;

assign flash_dq_o = flash_dq_o_reg;
assign flash_dq_oe = flash_dq_oe_reg;
assign flash_addr = flash_addr_reg;
assign flash_region = flash_region_reg;
assign flash_region_oe = flash_region_oe_reg;
assign flash_ce_n = flash_ce_n_reg;
assign flash_oe_n = flash_oe_n_reg;
assign flash_we_n = flash_we_n_reg;
assign flash_adv_n = flash_adv_n_reg;

always_ff @(posedge clk) begin
    vsec_apb_pready_reg <= 1'b0;

    if (vsec_apb.penable && vsec_apb.psel && !vsec_apb_pready_reg) begin
        vsec_apb_pready_reg <= 1'b1;
        vsec_apb_prdata_reg <= '0;

        if (vsec_apb.pwrite) begin
            case (8'({vsec_apb.paddr >> 2, 2'b00}))
                // FW ID
                8'h0C: begin
                    // FW ID: FPGA JTAG ID
                    fpga_boot_reg <= vsec_apb.pwdata == 32'hFEE1DEAD;
                end
                // BPI flash
                8'h4C: begin
                    // BPI flash ctrl: format
                    fpga_boot_reg <= vsec_apb.pwdata == 32'hFEE1DEAD;
                end
                8'h50: begin
                    // BPI flash ctrl: control
                    if (vsec_apb.pstrb[0]) begin
                        flash_ce_n_reg <= vsec_apb.pwdata[0];
                        flash_oe_n_reg <= vsec_apb.pwdata[1];
                        flash_we_n_reg <= vsec_apb.pwdata[2];
                        flash_adv_n_reg <= vsec_apb.pwdata[3];
                    end
                    if (vsec_apb.pstrb[1]) begin
                        flash_dq_oe_reg <= vsec_apb.pwdata[8];
                    end
                    if (vsec_apb.pstrb[2]) begin
                        flash_region_oe_reg <= vsec_apb.pwdata[16];
                    end
                end
                8'h54: begin
                    // BPI flash ctrl: address
                    {flash_region_reg, flash_addr_reg} <= (FLASH_ADDR_W+FLASH_RGN_W)'(vsec_apb.pwdata);
                end
                8'h58: flash_dq_o_reg <= FLASH_DATA_W'(vsec_apb.pwdata); // BPI flash ctrl: data
                default: begin end
            endcase
        end

        case (8'({vsec_apb.paddr >> 2, 2'b00}))
            // FW ID
            8'h00: vsec_apb_prdata_reg <= 32'hffffffff;    // FW ID: Type
            8'h04: vsec_apb_prdata_reg <= 32'h000_01_000;  // FW ID: Version
            8'h08: vsec_apb_prdata_reg <= 32'h40;          // FW ID: Next header
            8'h0C: vsec_apb_prdata_reg <= FPGA_ID;         // FW ID: FPGA JTAG ID
            8'h10: vsec_apb_prdata_reg <= FW_ID;           // FW ID: Firmware ID
            8'h14: vsec_apb_prdata_reg <= FW_VER;          // FW ID: Firmware version
            8'h18: vsec_apb_prdata_reg <= BOARD_ID;        // FW ID: Board ID
            8'h1C: vsec_apb_prdata_reg <= BOARD_VER;       // FW ID: Board version
            8'h20: vsec_apb_prdata_reg <= BUILD_DATE;      // FW ID: Build date
            8'h24: vsec_apb_prdata_reg <= GIT_HASH;        // FW ID: Git commit hash
            8'h28: vsec_apb_prdata_reg <= RELEASE_INFO;    // FW ID: Release info
            // BPI flash
            8'h40: vsec_apb_prdata_reg <= 32'h0000C121;    // BPI flash ctrl: Type
            8'h44: vsec_apb_prdata_reg <= 32'h000_01_000;  // BPI flash ctrl: Version
            8'h48: vsec_apb_prdata_reg <= 0;               // BPI flash ctrl: Next header
            8'h4C: begin
                // BPI flash ctrl: format
                vsec_apb_prdata_reg[3:0]   <= FLASH_SEG_COUNT;     // configuration
                vsec_apb_prdata_reg[7:4]   <= FLASH_SEG_DEFAULT;   // default segment
                vsec_apb_prdata_reg[11:8]  <= FLASH_SEG_FALLBACK;  // fallback segment
                vsec_apb_prdata_reg[31:12] <= 20'(FLASH_SEG0_SIZE >> 12);  // first segment size
            end
            8'h50: begin
                // BPI flash ctrl: control
                vsec_apb_prdata_reg[0] <= flash_ce_n_reg; // chip enable (inverted)
                vsec_apb_prdata_reg[1] <= flash_oe_n_reg; // output enable (inverted)
                vsec_apb_prdata_reg[2] <= flash_we_n_reg; // write enable (inverted)
                vsec_apb_prdata_reg[3] <= flash_adv_n_reg; // address valid (inverted)
                vsec_apb_prdata_reg[8] <= flash_dq_oe_reg; // data output enable
                vsec_apb_prdata_reg[16] <= flash_region_oe_reg; // region output enable (addr bit 25)
            end
            8'h54: begin
                // BPI flash ctrl: address
                vsec_apb_prdata_reg <= 32'({flash_region_reg, flash_addr_reg});
            end
            8'h58: vsec_apb_prdata_reg <= 32'(flash_dq_i); // BPI flash ctrl: data
            default: begin end
        endcase
    end

    if (rst) begin
        vsec_apb_pready_reg <= 1'b0;

        fpga_boot_reg <= 1'b0;

        flash_dq_o_reg <= '0;
        flash_dq_oe_reg <= 1'b0;
        flash_addr_reg <= '0;
        flash_region_reg <= '0;
        flash_region_oe_reg <= 1'b0;
        flash_ce_n_reg <= 1'b1;
        flash_oe_n_reg <= 1'b1;
        flash_we_n_reg <= 1'b1;
        flash_adv_n_reg <= 1'b1;
    end
end

endmodule

`resetall
