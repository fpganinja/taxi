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
 * Pyrite flashing support for UltraScale+ PCIe VPD and QSPI flash
 */
module pyrite_pcie_us_vpd_qspi #
(
    parameter logic [7:0] VPD_CAP_ID = 8'h03,
    parameter logic [7:0] VPD_CAP_OFFSET = 8'hB0,
    parameter logic [7:0] VPD_CAP_NEXT = 8'h00,

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
    parameter FLASH_DATA_W = 4,
    parameter logic FLASH_DUAL_QSPI = 1'b1
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
     * QSPI flash
     */
    output wire logic                     fpga_boot,
    output wire logic                     qspi_clk,
    input  wire logic [FLASH_DATA_W-1:0]  qspi_0_dq_i,
    output wire logic [FLASH_DATA_W-1:0]  qspi_0_dq_o,
    output wire logic [FLASH_DATA_W-1:0]  qspi_0_dq_oe,
    output wire logic                     qspi_0_cs,
    input  wire logic [FLASH_DATA_W-1:0]  qspi_1_dq_i,
    output wire logic [FLASH_DATA_W-1:0]  qspi_1_dq_o,
    output wire logic [FLASH_DATA_W-1:0]  qspi_1_dq_oe,
    output wire logic                     qspi_1_cs
);

taxi_apb_if #(
    .DATA_W(32),
    .ADDR_W(15)
) vpd_apb();

taxi_pcie_us_vpd #(
    .CAP_ID(VPD_CAP_ID),
    .CAP_OFFSET(VPD_CAP_OFFSET),
    .CAP_NEXT(VPD_CAP_NEXT)
)
vpd_cap_inst (
    .clk(clk),
    .rst(rst),

    /*
     * APB interface for VPD address space
     */
    .m_apb(vpd_apb),

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

taxi_apb_if #(
    .DATA_W(32),
    .ADDR_W(14)
) vpd_apb_int[2]();

taxi_apb_interconnect #(
    .M_CNT(2),
    .ADDR_W(15),
    .M_REGIONS(1),
    .M_BASE_ADDR('0),
    .M_ADDR_W({2{{1{{32'd14}}}}}),
    .M_SECURE({2{1'b0}})
)
vpd_apb_intercon (
    .clk(clk),
    .rst(rst),

    /*
     * APB slave interface
     */
    .s_apb(vpd_apb),

    /*
     * APB master interface
     */
    .m_apb(vpd_apb_int)
);

taxi_apb_ram #(
    .ADDR_W(11),
    .PIPELINE_OUTPUT(1)
)
vpd_ram_inst (
    .clk(clk),
    .rst(rst),

    /*
     * AXI4-Lite slave interface
     */
    .s_apb(vpd_apb_int[0])
);

logic vpd_apb_pready_reg = 1'b0;
logic [31:0] vpd_apb_prdata_reg = '0;

logic fpga_boot_reg = 1'b0;

logic qspi_clk_reg = 1'b0;
logic qspi_0_cs_reg = 1'b1;
logic [FLASH_DATA_W-1:0] qspi_0_dq_o_reg = '0;
logic [FLASH_DATA_W-1:0] qspi_0_dq_oe_reg = '0;
logic qspi_1_cs_reg = 1'b1;
logic [FLASH_DATA_W-1:0] qspi_1_dq_o_reg = '0;
logic [FLASH_DATA_W-1:0] qspi_1_dq_oe_reg = '0;

assign vpd_apb_int[1].pready = vpd_apb_pready_reg;
assign vpd_apb_int[1].prdata = vpd_apb_prdata_reg;
assign vpd_apb_int[1].pslverr = 1'b0;
assign vpd_apb_int[1].pruser = '0;
assign vpd_apb_int[1].pbuser = '0;

assign fpga_boot = fpga_boot_reg;

assign qspi_clk = qspi_clk_reg;
assign qspi_0_cs = qspi_0_cs_reg;
assign qspi_0_dq_o = qspi_0_dq_o_reg;
assign qspi_0_dq_oe = qspi_0_dq_oe_reg;
assign qspi_1_cs = FLASH_DUAL_QSPI ? qspi_1_cs_reg : 1'b1;
assign qspi_1_dq_o = FLASH_DUAL_QSPI ? qspi_1_dq_o_reg : '0;
assign qspi_1_dq_oe = FLASH_DUAL_QSPI ? qspi_1_dq_oe_reg : '0;

always_ff @(posedge clk) begin
    vpd_apb_pready_reg <= 1'b0;

    if (vpd_apb_int[1].penable && vpd_apb_int[1].psel && !vpd_apb_pready_reg) begin
        vpd_apb_pready_reg <= 1'b1;
        vpd_apb_prdata_reg <= '0;

        if (vpd_apb_int[1].pwrite) begin
            case (8'({vpd_apb_int[1].paddr >> 2, 2'b00}))
                // FW ID
                8'h0C: begin
                    // FW ID: FPGA JTAG ID
                    fpga_boot_reg <= vpd_apb_int[1].pwdata == 32'hFEE1DEAD;
                end
                // QSPI flash
                8'h4C: begin
                    // SPI flash ctrl: format
                    fpga_boot_reg <= vpd_apb_int[1].pwdata == 32'hFEE1DEAD;
                end
                8'h50: begin
                    // SPI flash ctrl: control 0
                    if (vpd_apb_int[1].pstrb[0]) begin
                        qspi_0_dq_o_reg <= vpd_apb_int[1].pwdata[3:0];
                    end
                    if (vpd_apb_int[1].pstrb[1]) begin
                        qspi_0_dq_oe_reg <= vpd_apb_int[1].pwdata[11:8];
                    end
                    if (vpd_apb_int[1].pstrb[2]) begin
                        qspi_clk_reg <= vpd_apb_int[1].pwdata[16];
                        qspi_0_cs_reg <= vpd_apb_int[1].pwdata[17];
                    end
                end
                8'h54: begin
                    // SPI flash ctrl: control 1
                    if (FLASH_DUAL_QSPI) begin
                        if (vpd_apb_int[1].pstrb[0]) begin
                            qspi_1_dq_o_reg <= vpd_apb_int[1].pwdata[3:0];
                        end
                        if (vpd_apb_int[1].pstrb[1]) begin
                            qspi_1_dq_oe_reg <= vpd_apb_int[1].pwdata[11:8];
                        end
                        if (vpd_apb_int[1].pstrb[2]) begin
                            qspi_clk_reg <= vpd_apb_int[1].pwdata[16];
                            qspi_1_cs_reg <= vpd_apb_int[1].pwdata[17];
                        end
                    end
                end
                default: begin end
            endcase
        end

        case (8'({vpd_apb_int[1].paddr >> 2, 2'b00}))
            // FW ID
            8'h00: vpd_apb_prdata_reg <= 32'hffffffff;    // FW ID: Type
            8'h04: vpd_apb_prdata_reg <= 32'h000_01_000;  // FW ID: Version
            8'h08: vpd_apb_prdata_reg <= 32'h40;          // FW ID: Next header
            8'h0C: vpd_apb_prdata_reg <= FPGA_ID;         // FW ID: FPGA JTAG ID
            8'h10: vpd_apb_prdata_reg <= FW_ID;           // FW ID: Firmware ID
            8'h14: vpd_apb_prdata_reg <= FW_VER;          // FW ID: Firmware version
            8'h18: vpd_apb_prdata_reg <= BOARD_ID;        // FW ID: Board ID
            8'h1C: vpd_apb_prdata_reg <= BOARD_VER;       // FW ID: Board version
            8'h20: vpd_apb_prdata_reg <= BUILD_DATE;      // FW ID: Build date
            8'h24: vpd_apb_prdata_reg <= GIT_HASH;        // FW ID: Git commit hash
            8'h28: vpd_apb_prdata_reg <= RELEASE_INFO;    // FW ID: Release info
            // QSPI flash
            8'h40: vpd_apb_prdata_reg <= 32'h0000C120;    // SPI flash ctrl: Type
            8'h44: vpd_apb_prdata_reg <= 32'h000_01_000;  // SPI flash ctrl: Version
            8'h48: vpd_apb_prdata_reg <= 0;               // SPI flash ctrl: Next header
            8'h4C: begin
                // SPI flash ctrl: format
                vpd_apb_prdata_reg[3:0]   <= FLASH_SEG_COUNT;        // configuration (two segments)
                vpd_apb_prdata_reg[7:4]   <= FLASH_SEG_DEFAULT;      // default segment
                vpd_apb_prdata_reg[11:8]  <= FLASH_SEG_FALLBACK;     // fallback segment
                vpd_apb_prdata_reg[31:12] <= FLASH_SEG0_SIZE >> 12;  // first segment size (even split)
            end
            8'h50: begin
                // SPI flash ctrl: control 0
                vpd_apb_prdata_reg[3:0] <= qspi_0_dq_i;
                vpd_apb_prdata_reg[11:8] <= qspi_0_dq_oe;
                vpd_apb_prdata_reg[16] <= qspi_clk;
                vpd_apb_prdata_reg[17] <= qspi_0_cs;
            end
            8'h54: begin
                // SPI flash ctrl: control 1
                if (FLASH_DUAL_QSPI) begin
                    vpd_apb_prdata_reg[3:0] <= qspi_1_dq_i;
                    vpd_apb_prdata_reg[11:8] <= qspi_1_dq_oe;
                    vpd_apb_prdata_reg[16] <= qspi_clk;
                    vpd_apb_prdata_reg[17] <= qspi_1_cs;
                end
            end
            default: begin end
        endcase
    end

    if (rst) begin
        vpd_apb_pready_reg <= 1'b0;

        fpga_boot_reg <= 1'b0;

        qspi_clk_reg <= 1'b0;
        qspi_0_cs_reg <= 1'b1;
        qspi_0_dq_o_reg <= '0;
        qspi_0_dq_oe_reg <= '0;
        qspi_1_cs_reg <= 1'b1;
        qspi_1_dq_o_reg <= '0;
        qspi_1_dq_oe_reg <= '0;
    end
end

endmodule

`resetall
