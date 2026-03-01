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
 * Datapath manager
 */
module cndm_micro_dp_mgr #
(
    parameter PORTS = 2,
    parameter PORT_BASE_ADDR = 0
)
(
    input  wire logic    clk,
    input  wire logic    rst,

    /*
     * Command interface
     */
    taxi_axis_if.snk     s_axis_cmd,
    taxi_axis_if.src     m_axis_rsp,

    /*
     * APB master interface (datapath control)
     */
    taxi_apb_if.mst      m_apb_dp_ctrl
);

// extract parameters
localparam DP_APB_ADDR_W = m_apb_dp_ctrl.ADDR_W;
localparam DP_APB_DATA_W = m_apb_dp_ctrl.DATA_W;
localparam DP_APB_STRB_W = m_apb_dp_ctrl.STRB_W;

typedef enum logic [15:0] {
    CMD_OP_NOP = 16'h0000,

    CMD_OP_CREATE_EQ  = 16'h0200,
    CMD_OP_MODIFY_EQ  = 16'h0201,
    CMD_OP_QUERY_EQ   = 16'h0202,
    CMD_OP_DESTROY_EQ = 16'h0203,

    CMD_OP_CREATE_CQ  = 16'h0210,
    CMD_OP_MODIFY_CQ  = 16'h0211,
    CMD_OP_QUERY_CQ   = 16'h0212,
    CMD_OP_DESTROY_CQ = 16'h0213,

    CMD_OP_CREATE_SQ  = 16'h0220,
    CMD_OP_MODIFY_SQ  = 16'h0221,
    CMD_OP_QUERY_SQ   = 16'h0222,
    CMD_OP_DESTROY_SQ = 16'h0223,

    CMD_OP_CREATE_RQ  = 16'h0230,
    CMD_OP_MODIFY_RQ  = 16'h0231,
    CMD_OP_QUERY_RQ   = 16'h0232,
    CMD_OP_DESTROY_RQ = 16'h0233,

    CMD_OP_CREATE_QP  = 16'h0240,
    CMD_OP_MODIFY_QP  = 16'h0241,
    CMD_OP_QUERY_QP   = 16'h0242,
    CMD_OP_DESTROY_QP = 16'h0243
} cmd_opcode_t;

typedef enum logic [4:0] {
    STATE_IDLE,
    STATE_START,
    STATE_Q_RESET_1,
    STATE_Q_RESET_2,
    STATE_Q_SET_BASE_L,
    STATE_Q_SET_BASE_H,
    STATE_Q_ENABLE,
    STATE_Q_DISABLE,
    STATE_SEND_RSP,
    STATE_PAD_RSP
} state_t;

state_t state_reg = STATE_IDLE, state_next;

logic s_axis_cmd_tready_reg = 1'b0, s_axis_cmd_tready_next;

logic [31:0] m_axis_rsp_tdata_reg = '0, m_axis_rsp_tdata_next;
logic m_axis_rsp_tvalid_reg = 1'b0, m_axis_rsp_tvalid_next;
logic m_axis_rsp_tlast_reg = 1'b0, m_axis_rsp_tlast_next;

logic [DP_APB_ADDR_W-1:0] m_apb_dp_ctrl_paddr_reg = '0, m_apb_dp_ctrl_paddr_next;
logic m_apb_dp_ctrl_psel_reg = 1'b0, m_apb_dp_ctrl_psel_next;
logic m_apb_dp_ctrl_penable_reg = 1'b0, m_apb_dp_ctrl_penable_next;
logic m_apb_dp_ctrl_pwrite_reg = 1'b0, m_apb_dp_ctrl_pwrite_next;
logic [DP_APB_DATA_W-1:0] m_apb_dp_ctrl_pwdata_reg = '0, m_apb_dp_ctrl_pwdata_next;
logic [DP_APB_STRB_W-1:0] m_apb_dp_ctrl_pstrb_reg = '0, m_apb_dp_ctrl_pstrb_next;

// command RAM
localparam CMD_AW = 4;

logic [31:0] cmd_ram[2**CMD_AW];
logic [31:0] cmd_ram_wr_data;
logic [CMD_AW-1:0] cmd_ram_wr_addr;
logic cmd_ram_wr_en;
logic [CMD_AW-1:0] cmd_ram_rd_addr;
wire [31:0] cmd_ram_rd_data = cmd_ram[cmd_ram_rd_addr];

assign s_axis_cmd.tready = s_axis_cmd_tready_reg;

assign m_axis_rsp.tdata  = m_axis_rsp_tdata_reg;
assign m_axis_rsp.tkeep  = '1;
assign m_axis_rsp.tstrb  = m_axis_rsp.tkeep;
assign m_axis_rsp.tvalid = m_axis_rsp_tvalid_reg;
assign m_axis_rsp.tlast  = m_axis_rsp_tlast_reg;
assign m_axis_rsp.tid    = '0;
assign m_axis_rsp.tdest  = '0;
assign m_axis_rsp.tuser  = '0;

assign m_apb_dp_ctrl.paddr = m_apb_dp_ctrl_paddr_reg;
assign m_apb_dp_ctrl.pprot = 3'b010;
assign m_apb_dp_ctrl.psel = m_apb_dp_ctrl_psel_reg;
assign m_apb_dp_ctrl.penable = m_apb_dp_ctrl_penable_reg;
assign m_apb_dp_ctrl.pwrite = m_apb_dp_ctrl_pwrite_reg;
assign m_apb_dp_ctrl.pwdata = m_apb_dp_ctrl_pwdata_reg;
assign m_apb_dp_ctrl.pstrb = m_apb_dp_ctrl_pstrb_reg;
assign m_apb_dp_ctrl.pauser = '0;
assign m_apb_dp_ctrl.pwuser = '0;

logic cmd_frame_reg = 1'b0, cmd_frame_next;
logic [3:0] cmd_ptr_reg = '0, cmd_ptr_next;
logic rsp_frame_reg = 1'b0, rsp_frame_next;
logic [3:0] rsp_ptr_reg = '0, rsp_ptr_next;

logic drop_cmd_reg = 1'b0, drop_cmd_next;

logic [15:0] opcode_reg = '0, opcode_next;
logic [31:0] flags_reg = '0, flags_next;
logic [15:0] port_reg = '0, port_next;
logic [23:0] qn_reg = '0, qn_next;

logic [DP_APB_ADDR_W-1:0] block_base_addr_reg = '0, block_base_addr_next;

always_comb begin
    state_next = STATE_IDLE;

    s_axis_cmd_tready_next = 1'b0;

    m_axis_rsp_tdata_next = m_axis_rsp_tdata_reg;
    m_axis_rsp_tvalid_next = m_axis_rsp_tvalid_reg && !m_axis_rsp.tready;
    m_axis_rsp_tlast_next = m_axis_rsp_tlast_reg;

    m_apb_dp_ctrl_paddr_next = m_apb_dp_ctrl_paddr_reg;
    m_apb_dp_ctrl_psel_next = m_apb_dp_ctrl_psel_reg && !m_apb_dp_ctrl.pready;
    m_apb_dp_ctrl_penable_next = m_apb_dp_ctrl_psel_reg && !m_apb_dp_ctrl.pready;
    m_apb_dp_ctrl_pwrite_next = m_apb_dp_ctrl_pwrite_reg;
    m_apb_dp_ctrl_pwdata_next = m_apb_dp_ctrl_pwdata_reg;
    m_apb_dp_ctrl_pstrb_next = m_apb_dp_ctrl_pstrb_reg;

    cmd_ram_wr_data = s_axis_cmd.tdata;
    cmd_ram_wr_addr = cmd_ptr_reg;
    cmd_ram_wr_en = 1'b0;
    cmd_ram_rd_addr = '0;

    cmd_frame_next = cmd_frame_reg;
    cmd_ptr_next = cmd_ptr_reg;
    rsp_frame_next = rsp_frame_reg;
    rsp_ptr_next = rsp_ptr_reg;

    drop_cmd_next = drop_cmd_reg;

    opcode_next = opcode_reg;
    flags_next = flags_reg;
    port_next = port_reg;
    qn_next = qn_reg;

    block_base_addr_next = block_base_addr_reg;

    if (s_axis_cmd.tready && s_axis_cmd.tvalid) begin
        if (s_axis_cmd.tlast) begin
            cmd_frame_next = 1'b0;
            cmd_ptr_next = '0;
        end else begin
            cmd_ptr_next = cmd_ptr_reg + 1;
            cmd_frame_next = 1'b1;
        end
    end

    case (state_reg)
        STATE_IDLE: begin
            s_axis_cmd_tready_next = !m_axis_rsp_tvalid_reg && !rsp_frame_reg;

            cmd_ram_wr_data = s_axis_cmd.tdata;
            cmd_ram_wr_addr = cmd_ptr_reg;
            cmd_ram_wr_en = 1'b1;

            // save some important fields
            case (cmd_ptr_reg)
                4'd0: opcode_next = s_axis_cmd.tdata[31:16];
                4'd1: flags_next = s_axis_cmd.tdata;
                4'd2: port_next = s_axis_cmd.tdata[15:0];
                4'd3: qn_next = s_axis_cmd.tdata[23:0];
                default: begin end
            endcase

            if (s_axis_cmd.tready && s_axis_cmd.tvalid && !drop_cmd_reg) begin
                if (s_axis_cmd.tlast || &cmd_ptr_reg) begin
                    drop_cmd_next = !s_axis_cmd.tlast;
                    state_next = STATE_START;
                end else begin
                    state_next = STATE_IDLE;
                end
            end else begin
                state_next = STATE_IDLE;
            end
        end
        STATE_START: begin
            // determine block base address
            case (opcode_reg)
                CMD_OP_CREATE_EQ,
                CMD_OP_MODIFY_EQ,
                CMD_OP_QUERY_EQ,
                CMD_OP_DESTROY_EQ:
                begin
                    // EQ
                    block_base_addr_next = DP_APB_ADDR_W'({port_reg, 16'd0} | 16'h0000);
                end
                CMD_OP_CREATE_CQ,
                CMD_OP_MODIFY_CQ,
                CMD_OP_QUERY_CQ,
                CMD_OP_DESTROY_CQ:
                begin
                    // CQ
                    if (qn_reg[0]) begin
                        block_base_addr_next = DP_APB_ADDR_W'({port_reg, 16'd0} | 16'h0300);
                    end else begin
                        block_base_addr_next = DP_APB_ADDR_W'({port_reg, 16'd0} | 16'h0400);
                    end
                end
                CMD_OP_CREATE_SQ,
                CMD_OP_MODIFY_SQ,
                CMD_OP_QUERY_SQ,
                CMD_OP_DESTROY_SQ:
                begin
                    // SQ
                    block_base_addr_next = DP_APB_ADDR_W'({port_reg, 16'd0} | 16'h0100);
                end
                CMD_OP_CREATE_RQ,
                CMD_OP_MODIFY_RQ,
                CMD_OP_QUERY_RQ,
                CMD_OP_DESTROY_RQ:
                begin
                    // RQ
                    block_base_addr_next = DP_APB_ADDR_W'({port_reg, 16'd0} | 16'h0200);
                end
                default: begin end
            endcase

            case (opcode_reg)
                16'h0000: begin
                    // NOP
                    m_axis_rsp_tdata_next = '0; // TODO
                    m_axis_rsp_tvalid_next = 1'b1;
                    m_axis_rsp_tlast_next = 1'b0;

                    state_next = STATE_SEND_RSP;
                end
                CMD_OP_CREATE_EQ,
                CMD_OP_CREATE_CQ,
                CMD_OP_CREATE_SQ,
                CMD_OP_CREATE_RQ:
                begin
                    // create queue operation
                    state_next = STATE_Q_RESET_1;
                end
                CMD_OP_MODIFY_EQ,
                CMD_OP_MODIFY_CQ,
                CMD_OP_MODIFY_SQ,
                CMD_OP_MODIFY_RQ:
                begin
                    // modify queue operation
                    m_axis_rsp_tdata_next = '0; // TODO
                    m_axis_rsp_tvalid_next = 1'b1;
                    m_axis_rsp_tlast_next = 1'b0;

                    // determine base address

                    state_next = STATE_PAD_RSP;
                end
                CMD_OP_QUERY_EQ,
                CMD_OP_QUERY_CQ,
                CMD_OP_QUERY_SQ,
                CMD_OP_QUERY_RQ:
                begin
                    // query queue operation
                    m_axis_rsp_tdata_next = '0; // TODO
                    m_axis_rsp_tvalid_next = 1'b1;
                    m_axis_rsp_tlast_next = 1'b0;

                    // determine base address

                    state_next = STATE_PAD_RSP;
                end
                CMD_OP_DESTROY_EQ,
                CMD_OP_DESTROY_CQ,
                CMD_OP_DESTROY_SQ,
                CMD_OP_DESTROY_RQ:
                begin
                    // destroy queue operation
                    state_next = STATE_Q_DISABLE;
                end
                default: begin
                    // unknown opcode
                    m_axis_rsp_tdata_next = '0; // TODO error code
                    m_axis_rsp_tvalid_next = 1'b1;
                    m_axis_rsp_tlast_next = 1'b0;

                    state_next = STATE_PAD_RSP;
                end
            endcase
        end
        STATE_Q_RESET_1: begin
            // reset queue 1
            if (!m_apb_dp_ctrl_psel_reg) begin
                m_apb_dp_ctrl_paddr_next = block_base_addr_reg + 16'h0000;
                m_apb_dp_ctrl_psel_next = 1'b1;
                m_apb_dp_ctrl_pwrite_next = 1'b1;
                m_apb_dp_ctrl_pwdata_next = 32'h00000000;
                m_apb_dp_ctrl_pstrb_next = '1;

                state_next = STATE_Q_RESET_2;
            end else begin
                state_next = STATE_Q_RESET_1;
            end
        end
        STATE_Q_RESET_2: begin
            // reset queue 2

            cmd_ram_wr_data = 32'(block_base_addr_reg + 16'h0004) + PORT_BASE_ADDR;
            cmd_ram_wr_addr = 7;
            cmd_ram_wr_en = 1'b1;

            if (!m_apb_dp_ctrl_psel_reg) begin
                m_apb_dp_ctrl_paddr_next = block_base_addr_reg + 16'h0004;
                m_apb_dp_ctrl_psel_next = 1'b1;
                m_apb_dp_ctrl_pwrite_next = 1'b1;
                m_apb_dp_ctrl_pwdata_next = 32'h00000000;
                m_apb_dp_ctrl_pstrb_next = '1;

                state_next = STATE_Q_SET_BASE_L;
            end else begin
                state_next = STATE_Q_RESET_2;
            end
        end
        STATE_Q_SET_BASE_L: begin
            // set queue base addr (LSB)
            cmd_ram_rd_addr = 8;
            if (!m_apb_dp_ctrl_psel_reg) begin
                m_apb_dp_ctrl_paddr_next = block_base_addr_reg + 16'h0008;
                m_apb_dp_ctrl_psel_next = 1'b1;
                m_apb_dp_ctrl_pwrite_next = 1'b1;
                m_apb_dp_ctrl_pwdata_next = cmd_ram_rd_data;
                m_apb_dp_ctrl_pstrb_next = '1;

                state_next = STATE_Q_SET_BASE_H;
            end else begin
                state_next = STATE_Q_SET_BASE_L;
            end
        end
        STATE_Q_SET_BASE_H: begin
            // set queue base addr (MSB)
            cmd_ram_rd_addr = 9;
            if (!m_apb_dp_ctrl_psel_reg) begin
                m_apb_dp_ctrl_paddr_next = block_base_addr_reg + 16'h000C;
                m_apb_dp_ctrl_psel_next = 1'b1;
                m_apb_dp_ctrl_pwrite_next = 1'b1;
                m_apb_dp_ctrl_pwdata_next = cmd_ram_rd_data;
                m_apb_dp_ctrl_pstrb_next = '1;

                state_next = STATE_Q_ENABLE;
            end else begin
                state_next = STATE_Q_SET_BASE_H;
            end
        end
        STATE_Q_ENABLE: begin
            // enable queue
            cmd_ram_rd_addr = 6;
            if (!m_apb_dp_ctrl_psel_reg) begin
                m_apb_dp_ctrl_paddr_next = block_base_addr_reg + 16'h0000;
                m_apb_dp_ctrl_psel_next = 1'b1;
                m_apb_dp_ctrl_pwrite_next = 1'b1;
                m_apb_dp_ctrl_pwdata_next = '0;
                m_apb_dp_ctrl_pwdata_next[19:16] = cmd_ram_rd_data[3:0];
                m_apb_dp_ctrl_pwdata_next[0] = 1'b1;
                m_apb_dp_ctrl_pstrb_next = '1;

                m_axis_rsp_tdata_next = '0; // TODO
                m_axis_rsp_tvalid_next = 1'b1;
                m_axis_rsp_tlast_next = 1'b0;

                state_next = STATE_SEND_RSP;
            end else begin
                state_next = STATE_Q_ENABLE;
            end
        end
        STATE_Q_DISABLE: begin
            // disable queue
            if (!m_apb_dp_ctrl_psel_reg) begin
                m_apb_dp_ctrl_paddr_next = block_base_addr_reg + 16'h0000;
                m_apb_dp_ctrl_psel_next = 1'b1;
                m_apb_dp_ctrl_pwrite_next = 1'b1;
                m_apb_dp_ctrl_pwdata_next = 32'h00000000;
                m_apb_dp_ctrl_pstrb_next = '1;

                m_axis_rsp_tdata_next = '0; // TODO
                m_axis_rsp_tvalid_next = 1'b1;
                m_axis_rsp_tlast_next = 1'b0;

                state_next = STATE_SEND_RSP;
            end else begin
                state_next = STATE_Q_DISABLE;
            end
        end
        STATE_SEND_RSP: begin
            // send response in the form of an edited command
            cmd_ram_rd_addr = rsp_ptr_reg;
            if (m_axis_rsp.tready || !m_axis_rsp.tvalid) begin
                m_axis_rsp_tdata_next = cmd_ram_rd_data;
                m_axis_rsp_tvalid_next = 1'b1;
                m_axis_rsp_tlast_next = &rsp_ptr_reg;

                if (&rsp_ptr_reg) begin
                    state_next = STATE_IDLE;
                end else begin
                    state_next = STATE_SEND_RSP;
                end
            end else begin
                state_next = STATE_SEND_RSP;
            end
        end
        STATE_PAD_RSP: begin
            // zero pad response
            if (m_axis_rsp.tready || !m_axis_rsp.tvalid) begin
                m_axis_rsp_tdata_next = '0;
                m_axis_rsp_tvalid_next = 1'b1;
                m_axis_rsp_tlast_next = &rsp_ptr_reg;

                if (&rsp_ptr_reg) begin
                    state_next = STATE_IDLE;
                end else begin
                    state_next = STATE_PAD_RSP;
                end
            end else begin
                state_next = STATE_PAD_RSP;
            end
        end
        default: begin
            // unknown state; return to idle
            state_next = STATE_IDLE;
        end
    endcase

    if (drop_cmd_reg) begin
        s_axis_cmd_tready_next = 1'b1;

        if (s_axis_cmd.tready && s_axis_cmd.tvalid) begin
            drop_cmd_next = !s_axis_cmd.tlast;
        end
    end

    if (m_axis_rsp_tvalid_next && (!m_axis_rsp_tvalid_reg || m_axis_rsp.tready)) begin
        if (m_axis_rsp_tlast_next) begin
            rsp_ptr_next = '0;
        end else begin
            rsp_ptr_next = rsp_ptr_reg + 1;
            rsp_frame_next = 1'b1;
        end
    end

    if (m_axis_rsp.tready && m_axis_rsp.tvalid) begin
        if (m_axis_rsp.tlast) begin
            rsp_frame_next = 1'b0;
            rsp_ptr_next = '0;
        end
    end
end

always_ff @(posedge clk) begin
    if (cmd_ram_wr_en) begin
        cmd_ram[cmd_ram_wr_addr] = cmd_ram_wr_data;
    end
end

always_ff @(posedge clk) begin
    state_reg <= state_next;

    s_axis_cmd_tready_reg <= s_axis_cmd_tready_next;

    m_axis_rsp_tdata_reg <= m_axis_rsp_tdata_next;
    m_axis_rsp_tvalid_reg <= m_axis_rsp_tvalid_next;
    m_axis_rsp_tlast_reg <= m_axis_rsp_tlast_next;

    m_apb_dp_ctrl_paddr_reg <= m_apb_dp_ctrl_paddr_next;
    m_apb_dp_ctrl_psel_reg <= m_apb_dp_ctrl_psel_next;
    m_apb_dp_ctrl_penable_reg <= m_apb_dp_ctrl_penable_next;
    m_apb_dp_ctrl_pwrite_reg <= m_apb_dp_ctrl_pwrite_next;
    m_apb_dp_ctrl_pwdata_reg <= m_apb_dp_ctrl_pwdata_next;
    m_apb_dp_ctrl_pstrb_reg <= m_apb_dp_ctrl_pstrb_next;

    cmd_frame_reg <= cmd_frame_next;
    cmd_ptr_reg <= cmd_ptr_next;
    rsp_frame_reg <= rsp_frame_next;
    rsp_ptr_reg <= rsp_ptr_next;

    drop_cmd_reg <= drop_cmd_next;

    opcode_reg <= opcode_next;
    flags_reg <= flags_next;
    port_reg <= port_next;
    qn_reg <= qn_next;

    block_base_addr_reg <= block_base_addr_next;

    if (rst) begin
        state_reg <= STATE_IDLE;

        s_axis_cmd_tready_reg <= 1'b0;
        m_axis_rsp_tvalid_reg <= 1'b0;

        m_apb_dp_ctrl_psel_reg <= 1'b0;
        m_apb_dp_ctrl_penable_reg <= 1'b0;

        cmd_frame_reg <= 1'b0;
        cmd_ptr_reg <= '0;
        rsp_frame_reg <= 1'b0;
        rsp_ptr_reg <= '0;

        drop_cmd_reg <= 1'b0;
    end
end

endmodule

`resetall
