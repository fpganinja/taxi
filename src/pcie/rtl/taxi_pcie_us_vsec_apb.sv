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
 * UltraScale PCIe vendor-specific capability for register access via APB
 */
module taxi_pcie_us_vsec_apb #
(
    parameter logic [15:0] EXT_CAP_ID = 16'h000B,
    parameter logic [3:0]  EXT_CAP_VERSION = 4'h1,
    parameter logic [11:0] EXT_CAP_OFFSET = 12'h480,
    parameter logic [11:0] EXT_CAP_NEXT = 12'h000,
    parameter logic [15:0] EXT_CAP_VSEC_ID = 16'h00FF,
    parameter logic [3:0]  EXT_CAP_VSEC_REV = 4'h1
)
(
    input  wire logic         clk,
    input  wire logic         rst,

    /*
     * APB interface for register space
     */
    taxi_apb_if.mst           m_apb,

    /*
     * Interface to Ultrascale PCIe IP core
     */
    input  wire logic         cfg_ext_read_received,
    input  wire logic         cfg_ext_write_received,
    input  wire logic [9:0]   cfg_ext_register_number,
    input  wire logic [7:0]   cfg_ext_function_number,
    input  wire logic [31:0]  cfg_ext_write_data,
    input  wire logic [3:0]   cfg_ext_write_byte_enable,
    output wire logic [31:0]  cfg_ext_read_data,
    output wire logic         cfg_ext_read_data_valid
);

localparam ADDR_W = m_apb.ADDR_W;
localparam DATA_W = m_apb.DATA_W;
localparam STRB_W = m_apb.STRB_W;

// check configuration
if (DATA_W > 32)
    $fatal(0, "Error: Data width must be 32 or less (instance %m)");

if (STRB_W * 8 != DATA_W)
    $fatal(0, "Error: Interface requires byte (8-bit) granularity (instance %m)");

logic [31:0] cfg_ext_read_data_reg = '0, cfg_ext_read_data_next;
logic cfg_ext_read_data_valid_reg = 1'b0, cfg_ext_read_data_valid_next;

logic flag_reg = 1'b0, flag_next;
logic [ADDR_W-1:0] addr_reg = '0, addr_next;
logic [DATA_W-1:0] data_reg = '0, data_next;
logic [STRB_W-1:0] strb_reg = '0, strb_next;

logic m_apb_psel_reg = 1'b0, m_apb_psel_next;
logic m_apb_penable_reg = 1'b0, m_apb_penable_next;
logic m_apb_pwrite_reg = 1'b0, m_apb_pwrite_next;

assign m_apb.paddr = addr_reg;
assign m_apb.pprot = 3'b010;
assign m_apb.psel = m_apb_psel_reg;
assign m_apb.penable = m_apb_penable_reg;
assign m_apb.pwrite = m_apb_pwrite_reg;
assign m_apb.pwdata = data_reg;
assign m_apb.pstrb = strb_reg;
assign m_apb.pauser = '0;
assign m_apb.pwuser = '0;

assign cfg_ext_read_data = cfg_ext_read_data_reg;
assign cfg_ext_read_data_valid = cfg_ext_read_data_valid_reg;

always_comb begin
    cfg_ext_read_data_next = '0;
    cfg_ext_read_data_valid_next = 1'b0;

    flag_next = flag_reg;
    addr_next = addr_reg;
    data_next = data_reg;
    strb_next = strb_reg;

    m_apb_psel_next = m_apb_psel_reg;
    m_apb_penable_next = m_apb_psel_reg;
    m_apb_pwrite_next = m_apb_pwrite_reg;

    if (m_apb.psel && m_apb.penable && m_apb.pready) begin
        m_apb_psel_next = 1'b0;
        m_apb_penable_next = 1'b0;

        if (m_apb_pwrite_reg) begin
            // write complete
            flag_next = 1'b0;
        end else begin
            // read complete
            flag_next = 1'b1;
            data_next = m_apb.prdata;
        end
    end

    if (cfg_ext_read_received) begin
        if (cfg_ext_register_number == 10'(EXT_CAP_OFFSET >> 2)+0) begin
            cfg_ext_read_data_next[15:0] = EXT_CAP_ID;
            cfg_ext_read_data_next[19:16] = EXT_CAP_VERSION;
            cfg_ext_read_data_next[31:20] = EXT_CAP_NEXT;
            cfg_ext_read_data_valid_next = 1'b1;
        end else if (cfg_ext_register_number == 10'(EXT_CAP_OFFSET >> 2)+1) begin
            cfg_ext_read_data_next[15:0] = EXT_CAP_VSEC_ID;
            cfg_ext_read_data_next[19:16] = EXT_CAP_VSEC_REV;
            cfg_ext_read_data_next[31:20] = 12'h0010; // length
            cfg_ext_read_data_valid_next = 1'b1;
        end else if (cfg_ext_register_number == 10'(EXT_CAP_OFFSET >> 2)+2) begin
            cfg_ext_read_data_next[30:0] = 31'(addr_reg);
            cfg_ext_read_data_next[31] = flag_reg;
            cfg_ext_read_data_valid_next = 1'b1;
        end else if (cfg_ext_register_number == 10'(EXT_CAP_OFFSET >> 2)+3) begin
            cfg_ext_read_data_next = 32'(data_reg);
            cfg_ext_read_data_valid_next = 1'b1;
        end
    end

    if (cfg_ext_write_received && !m_apb_psel_reg) begin
        if (cfg_ext_register_number == 10'(EXT_CAP_OFFSET >> 2)+2) begin
            addr_next = ADDR_W'(cfg_ext_write_data[30:0]);
            flag_next = cfg_ext_write_data[31];

            if (cfg_ext_write_data[31]) begin
                // write
                m_apb_psel_next = 1'b1;
                m_apb_pwrite_next = 1'b1;
            end else begin
                // read
                m_apb_psel_next = 1'b1;
                m_apb_pwrite_next = 1'b0;
            end
        end else if (cfg_ext_register_number == 10'(EXT_CAP_OFFSET >> 2)+3) begin
            data_next = DATA_W'(cfg_ext_write_data);
            strb_next = DATA_W'(cfg_ext_write_byte_enable);
        end
    end
end

always_ff @(posedge clk) begin
    cfg_ext_read_data_reg <= cfg_ext_read_data_next;
    cfg_ext_read_data_valid_reg <= cfg_ext_read_data_valid_next;

    flag_reg <= flag_next;
    addr_reg <= addr_next;
    data_reg <= data_next;
    strb_reg <= strb_next;

    m_apb_psel_reg <= m_apb_psel_next;
    m_apb_penable_reg <= m_apb_penable_next;
    m_apb_pwrite_reg <= m_apb_pwrite_next;

    if (rst) begin
        cfg_ext_read_data_valid_reg <= 1'b0;
        flag_reg <= 1'b0;
        addr_reg <= '0;
        data_reg <= '0;
        m_apb_psel_reg <= 1'b0;
        m_apb_penable_reg <= 1'b0;
    end
end

endmodule

`resetall
