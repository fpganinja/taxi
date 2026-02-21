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
 * UltraScale PCIe VPD capability
 */
module taxi_pcie_us_vpd #
(
    parameter logic [7:0] CAP_ID = 8'h03,
    parameter logic [7:0] CAP_OFFSET = 8'hB0,
    parameter logic [7:0] CAP_NEXT = 8'h00
)
(
    input  wire logic         clk,
    input  wire logic         rst,

    /*
     * APB interface for VPD address space
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

localparam ADDR_W = 15;
localparam DATA_W = 32;

// check configuration
if (m_apb.DATA_W != 32)
    $fatal(0, "Error: APB data width must be 32 (instance %m)");

logic [31:0] cfg_ext_read_data_reg = '0, cfg_ext_read_data_next;
logic cfg_ext_read_data_valid_reg = 1'b0, cfg_ext_read_data_valid_next;

logic flag_reg = 1'b0, flag_next;
logic [ADDR_W-1:0] addr_reg = '0, addr_next;
logic [DATA_W-1:0] data_reg = '0, data_next;

logic m_apb_psel_reg = 1'b0, m_apb_psel_next;
logic m_apb_penable_reg = 1'b0, m_apb_penable_next;
logic m_apb_pwrite_reg = 1'b0, m_apb_pwrite_next;

assign m_apb.paddr = addr_reg;
assign m_apb.pprot = 3'b010;
assign m_apb.psel = m_apb_psel_reg;
assign m_apb.penable = m_apb_penable_reg;
assign m_apb.pwrite = m_apb_pwrite_reg;
assign m_apb.pwdata = data_reg;
assign m_apb.pstrb = '1;
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
        if (cfg_ext_register_number == 10'(CAP_OFFSET >> 2)) begin
            cfg_ext_read_data_next[7:0] = CAP_ID;
            cfg_ext_read_data_next[15:8] = CAP_NEXT;
            cfg_ext_read_data_next[30:16] = addr_reg;
            cfg_ext_read_data_next[31] = flag_reg;
            cfg_ext_read_data_valid_next = 1'b1;
        end else if (cfg_ext_register_number == 10'(CAP_OFFSET >> 2)+1) begin
            cfg_ext_read_data_next = data_reg;
            cfg_ext_read_data_valid_next = 1'b1;
        end
    end

    if (cfg_ext_write_received && !m_apb_psel_reg) begin
        if (cfg_ext_register_number == 10'(CAP_OFFSET >> 2)) begin
            addr_next = cfg_ext_write_data[30:16];
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
        end else if (cfg_ext_register_number == 10'(CAP_OFFSET >> 2)+1) begin
            data_next = cfg_ext_write_data;
        end
    end
end

always_ff @(posedge clk) begin
    cfg_ext_read_data_reg <= cfg_ext_read_data_next;
    cfg_ext_read_data_valid_reg <= cfg_ext_read_data_valid_next;

    flag_reg <= flag_next;
    addr_reg <= addr_next;
    data_reg <= data_next;

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
