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
 * Command mailbox
 */
module cndm_micro_cmd_mbox
(
    input  wire logic    clk,
    input  wire logic    rst,

    /*
     * AXI lite interface
     */
    taxi_axil_if.wr_slv  s_axil_wr,
    taxi_axil_if.rd_slv  s_axil_rd,

    /*
     * Control
     */
    input  wire logic    start,
    output wire logic    busy,

    /*
     * Command interface
     */
    taxi_axis_if.src     m_axis_cmd,
    taxi_axis_if.snk     s_axis_rsp
);

localparam ADDR_W = 7;

// extract parameters
localparam DATA_W = s_axil_wr.DATA_W;
localparam STRB_W = s_axil_wr.STRB_W;

localparam VALID_ADDR_W = ADDR_W - $clog2(STRB_W);
localparam BYTE_LANES = STRB_W;
localparam BYTE_W = DATA_W/BYTE_LANES;

// check configuration
if (BYTE_W * STRB_W != DATA_W)
    $fatal(0, "Error: AXI data width not evenly divisible (instance %m)");

if (2**$clog2(BYTE_LANES) != BYTE_LANES)
    $fatal(0, "Error: AXI word width must be even power of two (instance %m)");

if (s_axil_rd.DATA_W != DATA_W)
    $fatal(0, "Error: AXI interface configuration mismatch (instance %m)");

if (s_axil_wr.ADDR_W < ADDR_W || s_axil_wr.ADDR_W < ADDR_W)
    $fatal(0, "Error: AXI address width is insufficient (instance %m)");

logic read_eligible;
logic write_eligible;

logic axil_mem_wr_en;
logic axil_mem_rd_en;
logic [4:0] axil_mem_addr;

logic cmd_mem_wr_en;
logic cmd_mem_rd_en;
logic [4:0] cmd_mem_addr;

logic last_read_reg = 1'b0, last_read_next;

logic [3:0] rd_ptr_reg = '0, rd_ptr_next;
logic [3:0] wr_ptr_reg = '0, wr_ptr_next;
logic busy_reg = 1'b0, busy_next;

logic s_axil_awready_reg = 1'b0, s_axil_awready_next;
logic s_axil_wready_reg = 1'b0, s_axil_wready_next;
logic s_axil_bvalid_reg = 1'b0, s_axil_bvalid_next;
logic s_axil_arready_reg = 1'b0, s_axil_arready_next;
// logic [DATA_W-1:0] s_axil_rdata_reg = '0, s_axil_rdata_next;
logic s_axil_rvalid_reg = 1'b0, s_axil_rvalid_next;

// logic [31:0] m_axis_cmd_tdata_reg = '0;
logic m_axis_cmd_tvalid_reg = 1'b0, m_axis_cmd_tvalid_next;
logic m_axis_cmd_tlast_reg = 1'b0, m_axis_cmd_tlast_next;

logic s_axis_rsp_tready_reg = 1'b0, s_axis_rsp_tready_next;

wire [VALID_ADDR_W-1:0] s_axil_awaddr_valid = VALID_ADDR_W'(s_axil_wr.awaddr >> (ADDR_W - VALID_ADDR_W));
wire [VALID_ADDR_W-1:0] s_axil_araddr_valid = VALID_ADDR_W'(s_axil_rd.araddr >> (ADDR_W - VALID_ADDR_W));

assign s_axil_wr.awready = s_axil_awready_reg;
assign s_axil_wr.wready = s_axil_wready_reg;
assign s_axil_wr.bresp = 2'b00;
assign s_axil_wr.buser = '0;
assign s_axil_wr.bvalid = s_axil_bvalid_reg;

assign s_axil_rd.arready = s_axil_arready_reg;
// assign s_axil_rd.rdata = s_axil_rdata_reg;
assign s_axil_rd.rresp = 2'b00;
assign s_axil_rd.ruser = '0;
assign s_axil_rd.rvalid = s_axil_rvalid_reg;

// assign m_axis_cmd.tdata  = m_axis_cmd_tdata_reg;
assign m_axis_cmd.tkeep  = '1;
assign m_axis_cmd.tstrb  = m_axis_cmd.tkeep;
assign m_axis_cmd.tvalid = m_axis_cmd_tvalid_reg;
assign m_axis_cmd.tlast  = m_axis_cmd_tlast_reg;
assign m_axis_cmd.tid    = '0;
assign m_axis_cmd.tdest  = '0;
assign m_axis_cmd.tuser  = '0;

assign s_axis_rsp.tready = s_axis_rsp_tready_reg;

assign busy = busy_reg;

taxi_ram_2rw_1c #(
    .ADDR_W(5),
    .DATA_W(32),
    .STRB_EN(1'b1),
    .STRB_W(4)
)
ram_inst (
    .clk(clk),

    .a_en(axil_mem_wr_en || axil_mem_rd_en),
    .a_addr(axil_mem_addr),
    .a_wr_en(axil_mem_wr_en),
    .a_wr_data(s_axil_wr.wdata),
    .a_wr_strb(s_axil_wr.wstrb),
    .a_rd_data(s_axil_rd.rdata),

    .b_en(cmd_mem_wr_en || cmd_mem_rd_en),
    .b_addr(cmd_mem_addr),
    .b_wr_en(cmd_mem_wr_en),
    .b_wr_data(s_axis_rsp.tdata),
    .b_wr_strb('1),
    .b_rd_data(m_axis_cmd.tdata)
);

// Register interface
always_comb begin
    axil_mem_wr_en = 1'b0;
    axil_mem_rd_en = 1'b0;
    axil_mem_addr = s_axil_araddr_valid;

    last_read_next = last_read_reg;

    s_axil_awready_next = 1'b0;
    s_axil_wready_next = 1'b0;
    s_axil_bvalid_next = s_axil_bvalid_reg && !s_axil_wr.bready;

    s_axil_arready_next = 1'b0;
    s_axil_rvalid_next = s_axil_rvalid_reg && !s_axil_rd.rready;

    write_eligible = s_axil_wr.awvalid && s_axil_wr.wvalid && (!s_axil_wr.bvalid || s_axil_wr.bready) && (!s_axil_wr.awready && !s_axil_wr.wready);
    read_eligible = s_axil_rd.arvalid && (!s_axil_rd.rvalid || s_axil_rd.rready) && (!s_axil_rd.arready);

    if (write_eligible && (!read_eligible || last_read_reg)) begin
        last_read_next = 1'b0;

        s_axil_awready_next = 1'b1;
        s_axil_wready_next = 1'b1;
        s_axil_bvalid_next = 1'b1;

        axil_mem_wr_en = 1'b1;
        axil_mem_addr = s_axil_awaddr_valid;
    end else if (read_eligible) begin
        last_read_next = 1'b1;

        s_axil_arready_next = 1'b1;
        s_axil_rvalid_next = 1'b1;

        axil_mem_rd_en = 1'b1;
        axil_mem_addr = s_axil_araddr_valid;
    end
end

always_ff @(posedge clk) begin
    last_read_reg <= last_read_next;

    s_axil_awready_reg <= s_axil_awready_next;
    s_axil_wready_reg <= s_axil_wready_next;
    s_axil_bvalid_reg <= s_axil_bvalid_next;

    s_axil_arready_reg <= s_axil_arready_next;
    s_axil_rvalid_reg <= s_axil_rvalid_next;

    if (rst) begin
        last_read_reg <= 1'b0;

        s_axil_awready_reg <= 1'b0;
        s_axil_wready_reg <= 1'b0;
        s_axil_bvalid_reg <= 1'b0;

        s_axil_arready_reg <= 1'b0;
        s_axil_rvalid_reg <= 1'b0;
    end
end

// Command interface
always_comb begin
    cmd_mem_rd_en = 1'b0;
    cmd_mem_wr_en = 1'b0;
    cmd_mem_addr = {1'b0, rd_ptr_reg};

    rd_ptr_next = rd_ptr_reg;
    wr_ptr_next = wr_ptr_reg;
    busy_next = busy_reg;

    m_axis_cmd_tvalid_next = m_axis_cmd_tvalid_reg && !m_axis_cmd.tready;
    m_axis_cmd_tlast_next = m_axis_cmd_tlast_reg;

    s_axis_rsp_tready_next = 1'b0;

    if ((!m_axis_cmd_tvalid_reg || m_axis_cmd.tready) && (rd_ptr_reg != 0 || start)) begin
        cmd_mem_rd_en = 1'b1;
        cmd_mem_addr = {1'b0, rd_ptr_reg};
        m_axis_cmd_tvalid_next = 1'b1;
        m_axis_cmd_tlast_next = &rd_ptr_reg;
        rd_ptr_next = rd_ptr_reg + 1;
        busy_next = 1'b1;
    end else if (s_axis_rsp.tvalid && !s_axis_rsp_tready_reg) begin
        cmd_mem_wr_en = 1'b1;
        cmd_mem_addr = {1'b1, wr_ptr_reg};
        s_axis_rsp_tready_next = 1'b1;
        if (s_axis_rsp.tlast) begin
            wr_ptr_next = '0;
            busy_next = 1'b0;
        end else begin
            wr_ptr_next = wr_ptr_reg + 1;
        end
    end
end

always_ff @(posedge clk) begin
    rd_ptr_reg <= rd_ptr_next;
    wr_ptr_reg <= wr_ptr_next;
    busy_reg <= busy_next;

    m_axis_cmd_tvalid_reg <= m_axis_cmd_tvalid_next;
    m_axis_cmd_tlast_reg <= m_axis_cmd_tlast_next;

    s_axis_rsp_tready_reg <= s_axis_rsp_tready_next;

    if (rst) begin
        rd_ptr_reg <= '0;
        wr_ptr_reg <= '0;
        busy_reg <= 1'b0;

        m_axis_cmd_tvalid_reg <= 1'b0;

        s_axis_rsp_tready_reg <= 1'b0;
    end
end

endmodule

`resetall
