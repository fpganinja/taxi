// SPDX-License-Identifier: CERN-OHL-S-2.0
/*

Copyright (c) 2018-2025 FPGA Ninja, LLC

Authors:
- Alex Forencich

*/

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * UltraScale PCIe configuration shim
 */
module taxi_pcie_us_cfg #
(
    parameter PF_COUNT = 1,
    parameter VF_COUNT = 0,
    parameter VF_OFFSET = 64,
    parameter F_COUNT = PF_COUNT+VF_COUNT,
    parameter logic READ_EXT_TAG_ENABLE = 1'b1,
    parameter logic READ_MAX_READ_REQ_SIZE = 1'b1,
    parameter logic READ_MAX_PAYLOAD_SIZE = 1'b1,
    parameter PCIE_CAP_OFFSET = 12'h0C0
)
(
    input  wire logic                  clk,
    input  wire logic                  rst,

    /*
     * Configuration outputs
     */
    output wire logic [F_COUNT-1:0]    ext_tag_en,
    output wire logic [F_COUNT*3-1:0]  max_read_req_size,
    output wire logic [F_COUNT*3-1:0]  max_payload_size,

    /*
     * Interface to Ultrascale PCIe IP core
     */
    output wire logic [9:0]            cfg_mgmt_addr,
    output wire logic [7:0]            cfg_mgmt_function_number,
    output wire logic                  cfg_mgmt_write,
    output wire logic [31:0]           cfg_mgmt_write_data,
    output wire logic [3:0]            cfg_mgmt_byte_enable,
    output wire logic                  cfg_mgmt_read,
    input  wire logic [31:0]           cfg_mgmt_read_data,
    input  wire logic                  cfg_mgmt_read_write_done
);

localparam CL_F_COUNT = F_COUNT > 1 ? $clog2(F_COUNT) : 1;

localparam READ_REV_CTRL = READ_EXT_TAG_ENABLE || READ_MAX_READ_REQ_SIZE || READ_MAX_PAYLOAD_SIZE;

localparam DEV_CTRL_OFFSET = PCIE_CAP_OFFSET + 12'h008;

logic [F_COUNT-1:0] ext_tag_en_reg = '0, ext_tag_en_next;
logic [F_COUNT*3-1:0] max_read_req_size_reg = '0, max_read_req_size_next;
logic [F_COUNT*3-1:0] max_payload_size_reg = '0, max_payload_size_next;

logic [9:0] cfg_mgmt_addr_reg = '0, cfg_mgmt_addr_next;
logic [7:0] cfg_mgmt_function_number_reg = '0, cfg_mgmt_function_number_next;
logic cfg_mgmt_write_reg = 1'b0, cfg_mgmt_write_next;
logic [31:0] cfg_mgmt_write_data_reg = '0, cfg_mgmt_write_data_next;
logic [3:0] cfg_mgmt_byte_enable_reg = '0, cfg_mgmt_byte_enable_next;
logic cfg_mgmt_read_reg = 1'b0, cfg_mgmt_read_next;
logic [31:0] cfg_mgmt_read_data_reg = '0;
logic cfg_mgmt_read_write_done_reg = 1'b0;

logic [7:0] delay_reg = 8'hff, delay_next;
logic [CL_F_COUNT-1:0] func_cnt_reg = '0, func_cnt_next;

assign ext_tag_en = ext_tag_en_reg;
assign max_read_req_size = max_read_req_size_reg;
assign max_payload_size = max_payload_size_reg;

assign cfg_mgmt_addr = cfg_mgmt_addr_reg;
assign cfg_mgmt_function_number = cfg_mgmt_function_number_reg;
assign cfg_mgmt_write = cfg_mgmt_write_reg;
assign cfg_mgmt_write_data = cfg_mgmt_write_data_reg;
assign cfg_mgmt_byte_enable = cfg_mgmt_byte_enable_reg;
assign cfg_mgmt_read = cfg_mgmt_read_reg;

always_comb begin
    ext_tag_en_next = ext_tag_en_reg;
    max_read_req_size_next = max_read_req_size_reg;
    max_payload_size_next = max_payload_size_reg;

    cfg_mgmt_addr_next = cfg_mgmt_addr_reg;
    cfg_mgmt_function_number_next = cfg_mgmt_function_number_reg;
    cfg_mgmt_write_next = cfg_mgmt_write_reg && !cfg_mgmt_read_write_done;
    cfg_mgmt_write_data_next = cfg_mgmt_write_data_reg;
    cfg_mgmt_byte_enable_next = cfg_mgmt_byte_enable_reg;
    cfg_mgmt_read_next = cfg_mgmt_read_reg && !cfg_mgmt_read_write_done;

    delay_next = delay_reg;
    func_cnt_next = func_cnt_reg;

    if (delay_reg > 0) begin
        delay_next = delay_reg - 1;
    end else begin
        cfg_mgmt_addr_next = 10'(DEV_CTRL_OFFSET >> 2);
        cfg_mgmt_read_next = 1'b1;
        if (cfg_mgmt_read_write_done_reg) begin
            cfg_mgmt_read_next = 1'b0;

            ext_tag_en_next[func_cnt_reg] = cfg_mgmt_read_data_reg[8];
            max_read_req_size_next[func_cnt_reg*3 +: 3] = cfg_mgmt_read_data_reg[14:12];
            max_payload_size_next[func_cnt_reg*3 +: 3] = cfg_mgmt_read_data_reg[7:5];

            if (func_cnt_reg == F_COUNT-1) begin
                func_cnt_next = 0;
                cfg_mgmt_function_number_next = 0;
            end else if (func_cnt_reg == PF_COUNT-1) begin
                func_cnt_next = func_cnt_reg + 1;
                cfg_mgmt_function_number_next = VF_OFFSET;
            end else begin
                func_cnt_next = func_cnt_reg + 1;
                cfg_mgmt_function_number_next = cfg_mgmt_function_number_reg + 1;
            end

            delay_next = 8'hff;
        end
    end
end

always_ff @(posedge clk) begin
    ext_tag_en_reg <= ext_tag_en_next;
    max_read_req_size_reg <= max_read_req_size_next;
    max_payload_size_reg <= max_payload_size_next;

    cfg_mgmt_addr_reg <= cfg_mgmt_addr_next;
    cfg_mgmt_function_number_reg <= cfg_mgmt_function_number_next;
    cfg_mgmt_write_reg <= cfg_mgmt_write_next;
    cfg_mgmt_write_data_reg <= cfg_mgmt_write_data_next;
    cfg_mgmt_byte_enable_reg <= cfg_mgmt_byte_enable_next;
    cfg_mgmt_read_reg <= cfg_mgmt_read_next;
    cfg_mgmt_read_data_reg <= cfg_mgmt_read_data;
    cfg_mgmt_read_write_done_reg <= cfg_mgmt_read_write_done;

    delay_reg <= delay_next;
    func_cnt_reg <= func_cnt_next;

    if (rst) begin
        ext_tag_en_reg <= '0;
        max_read_req_size_reg <= '0;
        max_payload_size_reg <= '0;

        cfg_mgmt_addr_reg <= '0;
        cfg_mgmt_function_number_reg <= '0;
        cfg_mgmt_write_reg <= 1'b0;
        cfg_mgmt_read_reg <= 1'b0;
        cfg_mgmt_read_write_done_reg <= 1'b0;

        delay_reg <= 8'hff;
        func_cnt_reg <= '0;
    end
end

endmodule

`resetall
