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
    // FW ID
    parameter FPGA_ID = 32'hDEADBEEF,
    parameter FW_ID = 32'h0000C002,
    parameter FW_VER = 32'h000_01_000,
    parameter BOARD_ID = 32'h1234_0000,
    parameter BOARD_VER = 32'h001_00_000,
    parameter BUILD_DATE = 32'd602976000,
    parameter GIT_HASH = 32'h5f87c2e8,
    parameter RELEASE_INFO = 32'h00000000,

    // Structural configuration
    parameter PORTS = 2,
    parameter SYS_CLK_PER_NS_NUM = 4,
    parameter SYS_CLK_PER_NS_DEN = 1,

    // Queue configuration
    parameter EQN_W = 5,
    parameter CQN_W = 5,
    parameter SQN_W = 5,
    parameter RQN_W = 5,
    parameter EQE_VER = 1,
    parameter CQE_VER = 1,
    parameter SQE_VER = 1,
    parameter RQE_VER = 1,
    parameter LOG_MAX_WQ_SZ = 15,

    // PTP configuration
    parameter logic PTP_EN = 1'b1,
    parameter PTP_CLK_PER_NS_NUM = 512,
    parameter PTP_CLK_PER_NS_DEN = 165,

    // Addressing
    parameter PTP_BASE_ADDR_DP = 0,
    parameter PORT_BASE_ADDR_DP = 0,
    parameter PORT_BASE_ADDR_HOST = 0,
    parameter PORT_STRIDE = 'h10000,
    parameter WQ_REG_STRIDE = 32,
    parameter EQM_OFFSET = 'h4000,
    parameter CQM_OFFSET = 'h4000,
    parameter SQM_OFFSET = 'h0000,
    parameter RQM_OFFSET = 'h0000,
    parameter PORT_CTRL_OFFSET = 'h8000
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

    CMD_OP_CFG        = 16'h0100,

    CMD_OP_ACCESS_REG = 16'h0180,
    CMD_OP_PTP        = 16'h0190,

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

typedef enum logic [2:0] {
    QTYPE_EQ,
    QTYPE_CQ,
    QTYPE_SQ,
    QTYPE_RQ
} qtype_t;

typedef enum logic [4:0] {
    STATE_IDLE,
    STATE_START,
    STATE_CFG_READ,
    STATE_REG_1,
    STATE_REG_2,
    STATE_REG_3,
    STATE_CREATE_Q_FIND_1,
    STATE_CREATE_Q_FIND_2,
    STATE_CREATE_Q_RESET_1,
    STATE_CREATE_Q_RESET_2,
    STATE_CREATE_Q_RESET_3,
    STATE_CREATE_Q_SET_BASE_L,
    STATE_CREATE_Q_SET_BASE_H,
    STATE_CREATE_Q_SET_DQN,
    STATE_CREATE_Q_ENABLE,
    STATE_CREATE_Q_PORT_CONFIG,
    STATE_DESTROY_Q_DISABLE,
    STATE_PTP_READ_1,
    STATE_PTP_READ_2,
    STATE_PTP_SET,
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

logic [31:0] cmd_ram[2**CMD_AW] = '{default: '0};
logic [31:0] cmd_ram_wr_data;
logic [CMD_AW-1:0] cmd_ram_wr_addr;
logic cmd_ram_wr_en;
logic [CMD_AW-1:0] cmd_ram_rd_addr;
wire [31:0] cmd_ram_rd_data = cmd_ram[cmd_ram_rd_addr];

// ID ROM
localparam ID_PAGES = 3;
localparam ID_AW = $clog2((ID_PAGES+1)*8);

// detect sharing between EQ/CQ and SQ/RQ (same queue manager)
localparam EQ_POOL = 1;
localparam CQ_POOL = EQ_POOL + (EQM_OFFSET == CQM_OFFSET ? 0 : 1);
localparam SQ_POOL = CQ_POOL + 1;
localparam RQ_POOL = SQ_POOL + (SQM_OFFSET == RQM_OFFSET ? 0 : 1);

logic [31:0] id_rom[(ID_PAGES+1)*8] = '{
    // Common
    0, // 0: status
    0, // 1: flags
    { // 2
        16'(ID_PAGES-1), // [31:16] cfg_page_max
        16'd0 // [15:0] cfg_page (replaced)
    },
    32'h000_01_000, // 3: CMD_VER
    FW_VER, // 4
    { // 5
        8'd0, // [31:24]
        8'd0, // [23:16]
        8'd0, // [15:8]
        8'(PORTS) // [7:0]
    },
    0, // 6
    0, // 7
    // Page 0: FW ID
    FPGA_ID, // 8
    FW_ID, // 9
    FW_VER, // 10
    BOARD_ID, // 11
    BOARD_VER, // 12
    BUILD_DATE, // 13
    GIT_HASH, // 14
    RELEASE_INFO, // 15
    // Page 1: HW config
    { // 16
        16'd0, // [31:16]
        16'(PORTS) // [15:0]
    },
    0, // 17
    0, // 18
    0, // 19
    { // 20
        16'(SYS_CLK_PER_NS_NUM), // [31:16]
        16'(SYS_CLK_PER_NS_DEN) // [15:0]
    },
    { // 21
        16'(PTP_CLK_PER_NS_NUM), // [31:16]
        16'(PTP_CLK_PER_NS_DEN) // [15:0]
    },
    0, // 22
    0, // 23
    // Page 2: Resources
    { // 24
        8'(EQE_VER), // [31:24] EQE_VER
        8'(EQ_POOL), // [23:16] EQ_POOL
        8'(LOG_MAX_WQ_SZ), // [15:8] LOG_MAX_EQ_SZ
        8'(EQN_W) // [7:0] LOG_MAX_EQ
    },
    { // 25
        8'(CQE_VER), // [31:24] CQE_VER
        8'(CQ_POOL), // [23:16] CQ_POOL
        8'(LOG_MAX_WQ_SZ), // [15:8] LOG_MAX_CQ_SZ
        8'(CQN_W) // [7:0] LOG_MAX_CQ
    },
    { // 26
        8'(SQE_VER), // [31:24] SQE_VER
        8'(SQ_POOL), // [23:16] SQ_POOL
        8'(LOG_MAX_WQ_SZ), // [15:8] LOG_MAX_SQ_SZ
        8'(SQN_W) // [7:0] LOG_MAX_SQ
    },
    { // 27
        8'(RQE_VER), // [31:24] RQE_VER
        8'(RQ_POOL), // [23:16] RQ_POOL
        8'(LOG_MAX_WQ_SZ), // [15:8] LOG_MAX_RQ_SZ
        8'(RQN_W) // [7:0] LOG_MAX_RQ
    },
    0, // 28
    0, // 29
    0, // 30
    0 // 31
};
logic [ID_AW-1:0] id_rom_rd_addr;
wire [31:0] id_rom_rd_data = id_rom[id_rom_rd_addr];

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
logic [3:0] cmd_wr_ptr_reg = '0, cmd_wr_ptr_next;
logic rsp_frame_reg = 1'b0, rsp_frame_next;
logic [3:0] rsp_rd_ptr_reg = '0, rsp_rd_ptr_next;

logic drop_cmd_reg = 1'b0, drop_cmd_next;

logic [15:0] opcode_reg = '0, opcode_next;
logic [31:0] flags_reg = '0, flags_next;
logic [31:0] dw2_reg = '0, dw2_next;
logic [31:0] dw3_reg = '0, dw3_next;
logic [31:0] dw4_reg = '0, dw4_next;
logic [2:0] qtype_reg = '0, qtype_next;

logic [3:0] cmd_ptr_reg = '0, cmd_ptr_next;
logic [DP_APB_ADDR_W-1:0] dp_ptr_reg = '0, dp_ptr_next;
logic [31:0] host_ptr_reg = '0, host_ptr_next;
logic [15:0] cnt_reg = '0, cnt_next;

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
    cmd_ram_wr_addr = cmd_wr_ptr_reg;
    cmd_ram_wr_en = 1'b0;
    cmd_ram_rd_addr = '0;

    id_rom_rd_addr = ID_AW'(cnt_reg);

    cmd_frame_next = cmd_frame_reg;
    cmd_wr_ptr_next = cmd_wr_ptr_reg;
    rsp_frame_next = rsp_frame_reg;
    rsp_rd_ptr_next = rsp_rd_ptr_reg;

    drop_cmd_next = drop_cmd_reg;

    opcode_next = opcode_reg;
    flags_next = flags_reg;
    dw2_next = dw2_reg;
    dw3_next = dw3_reg;
    dw4_next = dw4_reg;
    qtype_next = qtype_reg;

    cmd_ptr_next = cmd_ptr_reg;
    dp_ptr_next = dp_ptr_reg;
    host_ptr_next = host_ptr_reg;
    cnt_next = cnt_reg;

    if (s_axis_cmd.tready && s_axis_cmd.tvalid) begin
        if (s_axis_cmd.tlast) begin
            cmd_frame_next = 1'b0;
            cmd_wr_ptr_next = '0;
        end else begin
            cmd_wr_ptr_next = cmd_wr_ptr_reg + 1;
            cmd_frame_next = 1'b1;
        end
    end

    case (state_reg)
        STATE_IDLE: begin
            s_axis_cmd_tready_next = !m_axis_rsp_tvalid_reg && !rsp_frame_reg;

            cmd_ram_wr_data = s_axis_cmd.tdata;
            cmd_ram_wr_addr = cmd_wr_ptr_reg;
            cmd_ram_wr_en = 1'b1;

            // save some important fields
            case (cmd_wr_ptr_reg)
                4'd0: opcode_next = s_axis_cmd.tdata[31:16];
                4'd1: flags_next = s_axis_cmd.tdata;
                4'd2: dw2_next = s_axis_cmd.tdata;
                4'd3: dw3_next = s_axis_cmd.tdata;
                4'd4: dw4_next = s_axis_cmd.tdata;
                default: begin end
            endcase

            if (s_axis_cmd.tready && s_axis_cmd.tvalid && !drop_cmd_reg) begin
                if (s_axis_cmd.tlast || &cmd_wr_ptr_reg) begin
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
            cmd_ptr_next = '0;
            dp_ptr_next = '0;
            host_ptr_next = '0;
            cnt_next = '0;

            // determine block base address
            case (opcode_reg)
                // EQ
                CMD_OP_CREATE_EQ:
                begin
                    cnt_next = 2**EQN_W-1;
                    qtype_next = QTYPE_EQ;
                    dp_ptr_next = DP_APB_ADDR_W'((dw2_reg[15:0] * PORT_STRIDE) + EQM_OFFSET + PORT_BASE_ADDR_DP);
                    host_ptr_next = (dw2_reg[15:0] * PORT_STRIDE) + EQM_OFFSET + PORT_BASE_ADDR_HOST;
                end
                CMD_OP_MODIFY_EQ,
                CMD_OP_QUERY_EQ,
                CMD_OP_DESTROY_EQ:
                begin
                    qtype_next = QTYPE_EQ;
                    dp_ptr_next = DP_APB_ADDR_W'((dw2_reg[15:0] * PORT_STRIDE) + EQM_OFFSET + (dw3_reg[15:0] * WQ_REG_STRIDE) + PORT_BASE_ADDR_DP);
                    host_ptr_next = (dw2_reg[15:0] * PORT_STRIDE) + EQM_OFFSET + (dw3_reg[15:0] * WQ_REG_STRIDE) + PORT_BASE_ADDR_HOST;
                end
                // CQ
                CMD_OP_CREATE_CQ:
                begin
                    cnt_next = 2**CQN_W-1;
                    qtype_next = QTYPE_CQ;
                    dp_ptr_next = DP_APB_ADDR_W'((dw2_reg[15:0] * PORT_STRIDE) + CQM_OFFSET + PORT_BASE_ADDR_DP);
                    host_ptr_next = (dw2_reg[15:0] * PORT_STRIDE) + CQM_OFFSET + PORT_BASE_ADDR_HOST;
                end
                CMD_OP_MODIFY_CQ,
                CMD_OP_QUERY_CQ,
                CMD_OP_DESTROY_CQ:
                begin
                    qtype_next = QTYPE_CQ;
                    dp_ptr_next = DP_APB_ADDR_W'((dw2_reg[15:0] * PORT_STRIDE) + CQM_OFFSET + (dw3_reg[15:0] * WQ_REG_STRIDE) + PORT_BASE_ADDR_DP);
                    host_ptr_next = (dw2_reg[15:0] * PORT_STRIDE) + CQM_OFFSET + (dw3_reg[15:0] * WQ_REG_STRIDE) + PORT_BASE_ADDR_HOST;
                end
                // SQ
                CMD_OP_CREATE_SQ:
                begin
                    cnt_next = 2**SQN_W-1;
                    qtype_next = QTYPE_SQ;
                    dp_ptr_next = DP_APB_ADDR_W'((dw2_reg[15:0] * PORT_STRIDE) + SQM_OFFSET + PORT_BASE_ADDR_DP);
                    host_ptr_next = (dw2_reg[15:0] * PORT_STRIDE) + SQM_OFFSET + PORT_BASE_ADDR_HOST;
                end
                CMD_OP_MODIFY_SQ,
                CMD_OP_QUERY_SQ,
                CMD_OP_DESTROY_SQ:
                begin
                    qtype_next = QTYPE_SQ;
                    dp_ptr_next = DP_APB_ADDR_W'((dw2_reg[15:0] * PORT_STRIDE) + SQM_OFFSET + (dw3_reg[15:0] * WQ_REG_STRIDE) + PORT_BASE_ADDR_DP);
                    host_ptr_next = (dw2_reg[15:0] * PORT_STRIDE) + SQM_OFFSET + (dw3_reg[15:0] * WQ_REG_STRIDE) + PORT_BASE_ADDR_HOST;
                end
                // RQ
                CMD_OP_CREATE_RQ:
                begin
                    cnt_next = 2**RQN_W-1;
                    qtype_next = QTYPE_RQ;
                    dp_ptr_next = DP_APB_ADDR_W'((dw2_reg[15:0] * PORT_STRIDE) + RQM_OFFSET + PORT_BASE_ADDR_DP);
                    host_ptr_next = (dw2_reg[15:0] * PORT_STRIDE) + RQM_OFFSET + PORT_BASE_ADDR_HOST;
                end
                CMD_OP_MODIFY_RQ,
                CMD_OP_QUERY_RQ,
                CMD_OP_DESTROY_RQ:
                begin
                    qtype_next = QTYPE_RQ;
                    dp_ptr_next = DP_APB_ADDR_W'((dw2_reg[15:0] * PORT_STRIDE) + RQM_OFFSET + (dw3_reg[15:0] * WQ_REG_STRIDE) + PORT_BASE_ADDR_DP);
                    host_ptr_next = (dw2_reg[15:0] * PORT_STRIDE) + RQM_OFFSET + (dw3_reg[15:0] * WQ_REG_STRIDE) + PORT_BASE_ADDR_HOST;
                end
                default: begin end
            endcase

            case (opcode_reg)
                CMD_OP_NOP: begin
                    // NOP
                    m_axis_rsp_tdata_next = '0; // TODO
                    m_axis_rsp_tvalid_next = 1'b1;
                    m_axis_rsp_tlast_next = 1'b0;

                    state_next = STATE_SEND_RSP;
                end
                CMD_OP_CFG: begin
                    // dump config page
                    cmd_ptr_next = 2;
                    cnt_next = 2;
                    state_next = STATE_CFG_READ;
                end
                CMD_OP_ACCESS_REG: begin
                    // access register
                    state_next = STATE_REG_1;
                end
                CMD_OP_PTP: begin
                    // PTP control
                    if (PTP_EN) begin
                        if (flags_reg[15:0] != 0) begin
                            // update something
                            cmd_ptr_next = 2;
                            dp_ptr_next = PTP_BASE_ADDR_DP + 'h50;
                            cnt_next = '0;
                            state_next = STATE_PTP_SET;
                        end else begin
                            // dump state
                            cmd_ptr_next = 2;
                            dp_ptr_next = PTP_BASE_ADDR_DP + 'h30;
                            cnt_next = '0;
                            state_next = STATE_PTP_READ_1;
                        end
                    end else begin
                        // PTP not enabled
                        m_axis_rsp_tdata_next = '0; // TODO
                        m_axis_rsp_tvalid_next = 1'b1;
                        m_axis_rsp_tlast_next = 1'b0;

                        state_next = STATE_SEND_RSP;
                    end
                end
                CMD_OP_CREATE_EQ,
                CMD_OP_CREATE_CQ,
                CMD_OP_CREATE_SQ,
                CMD_OP_CREATE_RQ:
                begin
                    // create queue operation
                    dw3_next = '0;
                    state_next = STATE_CREATE_Q_FIND_1;
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
                    state_next = STATE_DESTROY_Q_DISABLE;
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
        STATE_CFG_READ: begin
            // read config page data
            id_rom_rd_addr = ID_AW'(cnt_reg);

            cmd_ram_wr_data = id_rom_rd_data;
            cmd_ram_wr_addr = cmd_ptr_reg;
            cmd_ram_wr_en = 1'b1;
            if (cmd_ptr_reg == 2) begin
                cmd_ram_wr_data[15:0] = dw2_reg[15:0];
            end

            cnt_next = cnt_reg + 1;
            cmd_ptr_next = cmd_ptr_reg + 1;

            if (cmd_ptr_reg == 15) begin
                // done
                m_axis_rsp_tdata_next = '0; // TODO
                m_axis_rsp_tvalid_next = 1'b1;
                m_axis_rsp_tlast_next = 1'b0;

                state_next = STATE_SEND_RSP;
            end else if (cmd_ptr_reg == 7) begin
                // jump to selected page
                cnt_next = 16'((dw2_reg + 1) * 8);
                state_next = STATE_CFG_READ;
            end else begin
                // more to read
                state_next = STATE_CFG_READ;
            end
        end
        STATE_REG_1: begin
            // register access 1
            cmd_ram_rd_addr = 7;
            if (!m_apb_dp_ctrl_psel_reg) begin
                m_apb_dp_ctrl_paddr_next = DP_APB_ADDR_W'(cmd_ram_rd_data);

                state_next = STATE_REG_2;
            end else begin
                state_next = STATE_REG_1;
            end
        end
        STATE_REG_2: begin
            // register access 2
            cmd_ram_rd_addr = 8;
            if (!m_apb_dp_ctrl_psel_reg) begin
                m_apb_dp_ctrl_psel_next = 1'b1;
                m_apb_dp_ctrl_pwrite_next = flags_reg[0];
                m_apb_dp_ctrl_pwdata_next = cmd_ram_rd_data;
                m_apb_dp_ctrl_pstrb_next = '1;

                state_next = STATE_REG_3;
            end else begin
                state_next = STATE_REG_2;
            end
        end
        STATE_REG_3: begin
            // register access 3

            cmd_ram_wr_data = m_apb_dp_ctrl.prdata;
            cmd_ram_wr_addr = 10;
            cmd_ram_wr_en = 1'b1;

            if (m_apb_dp_ctrl.pready) begin
                m_axis_rsp_tdata_next = '0; // TODO
                m_axis_rsp_tvalid_next = 1'b1;
                m_axis_rsp_tlast_next = 1'b0;

                state_next = STATE_SEND_RSP;
            end else begin
                state_next = STATE_REG_3;
            end
        end
        STATE_CREATE_Q_FIND_1: begin
            // read queue enable bit
            if (!m_apb_dp_ctrl_psel_reg) begin
                m_apb_dp_ctrl_paddr_next = dp_ptr_reg + 'h0000;
                m_apb_dp_ctrl_psel_next = 1'b1;
                m_apb_dp_ctrl_pwrite_next = 1'b0;
                m_apb_dp_ctrl_pwdata_next = 32'h00000000;
                m_apb_dp_ctrl_pstrb_next = '1;

                state_next = STATE_CREATE_Q_FIND_2;
            end else begin
                state_next = STATE_CREATE_Q_FIND_1;
            end
        end
        STATE_CREATE_Q_FIND_2: begin
            // check queue enable bit
            if (m_apb_dp_ctrl.pready) begin
                cnt_next = cnt_reg - 1;

                if (m_apb_dp_ctrl.prdata[0] == 0) begin
                    // queue is inactive
                    state_next = STATE_CREATE_Q_RESET_1;
                end else begin
                    // queue is active
                    dw3_next = dw3_reg + 1;
                    dp_ptr_next = dp_ptr_reg + WQ_REG_STRIDE;
                    host_ptr_next = host_ptr_reg + WQ_REG_STRIDE;
                    if (cnt_reg == 0) begin
                        // no more queues
                        m_axis_rsp_tdata_next = '0; // TODO
                        m_axis_rsp_tvalid_next = 1'b1;
                        m_axis_rsp_tlast_next = 1'b0;

                        state_next = STATE_PAD_RSP;
                    end else begin
                        // try next queue
                        state_next = STATE_CREATE_Q_FIND_1;
                    end
                end
            end else begin
                state_next = STATE_CREATE_Q_FIND_2;
            end
        end
        STATE_CREATE_Q_RESET_1: begin
            // reset queue 1

            // store queue number
            cmd_ram_wr_data = dw3_reg;
            cmd_ram_wr_addr = 3;
            cmd_ram_wr_en = 1'b1;

            if (!m_apb_dp_ctrl_psel_reg) begin
                m_apb_dp_ctrl_paddr_next = dp_ptr_reg + 'h0000;
                m_apb_dp_ctrl_psel_next = 1'b1;
                m_apb_dp_ctrl_pwrite_next = 1'b1;
                m_apb_dp_ctrl_pwdata_next = 32'h00000000;
                m_apb_dp_ctrl_pstrb_next = '1;

                state_next = STATE_CREATE_Q_RESET_2;
            end else begin
                state_next = STATE_CREATE_Q_RESET_1;
            end
        end
        STATE_CREATE_Q_RESET_2: begin
            // reset queue 2

            // store doorbell offset
            if (qtype_reg == QTYPE_SQ || qtype_reg == QTYPE_RQ) begin
                cmd_ram_wr_data = host_ptr_reg + 'h0008;
            end else begin
                cmd_ram_wr_data = host_ptr_reg + 'h000C;
            end
            cmd_ram_wr_addr = 7;
            cmd_ram_wr_en = 1'b1;

            if (!m_apb_dp_ctrl_psel_reg) begin
                m_apb_dp_ctrl_paddr_next = dp_ptr_reg + 'h0008;
                m_apb_dp_ctrl_psel_next = 1'b1;
                m_apb_dp_ctrl_pwrite_next = 1'b1;
                m_apb_dp_ctrl_pwdata_next = 32'h00000000;
                m_apb_dp_ctrl_pstrb_next = '1;

                state_next = STATE_CREATE_Q_RESET_3;
            end else begin
                state_next = STATE_CREATE_Q_RESET_2;
            end
        end
        STATE_CREATE_Q_RESET_3: begin
            // reset queue 2

            if (!m_apb_dp_ctrl_psel_reg) begin
                m_apb_dp_ctrl_paddr_next = dp_ptr_reg + 'h000c;
                m_apb_dp_ctrl_psel_next = 1'b1;
                m_apb_dp_ctrl_pwrite_next = 1'b1;
                m_apb_dp_ctrl_pwdata_next = 32'h00000000;
                m_apb_dp_ctrl_pstrb_next = '1;

                state_next = STATE_CREATE_Q_SET_BASE_L;
            end else begin
                state_next = STATE_CREATE_Q_RESET_3;
            end
        end
        STATE_CREATE_Q_SET_BASE_L: begin
            // set queue base addr (LSB)
            cmd_ram_rd_addr = 8;
            if (!m_apb_dp_ctrl_psel_reg) begin
                m_apb_dp_ctrl_paddr_next = dp_ptr_reg + 'h0018;
                m_apb_dp_ctrl_psel_next = 1'b1;
                m_apb_dp_ctrl_pwrite_next = 1'b1;
                m_apb_dp_ctrl_pwdata_next = cmd_ram_rd_data;
                m_apb_dp_ctrl_pstrb_next = '1;

                state_next = STATE_CREATE_Q_SET_BASE_H;
            end else begin
                state_next = STATE_CREATE_Q_SET_BASE_L;
            end
        end
        STATE_CREATE_Q_SET_BASE_H: begin
            // set queue base addr (MSB)
            cmd_ram_rd_addr = 9;
            if (!m_apb_dp_ctrl_psel_reg) begin
                m_apb_dp_ctrl_paddr_next = dp_ptr_reg + 'h001C;
                m_apb_dp_ctrl_psel_next = 1'b1;
                m_apb_dp_ctrl_pwrite_next = 1'b1;
                m_apb_dp_ctrl_pwdata_next = cmd_ram_rd_data;
                m_apb_dp_ctrl_pstrb_next = '1;

                state_next = STATE_CREATE_Q_ENABLE;
            end else begin
                state_next = STATE_CREATE_Q_SET_DQN;
            end
        end
        STATE_CREATE_Q_SET_DQN: begin
            // set CQN/EQN/IRQN
            cmd_ram_rd_addr = 4;
            if (!m_apb_dp_ctrl_psel_reg) begin
                m_apb_dp_ctrl_paddr_next = dp_ptr_reg + 'h0004;
                m_apb_dp_ctrl_psel_next = 1'b1;
                m_apb_dp_ctrl_pwrite_next = 1'b1;
                m_apb_dp_ctrl_pwdata_next = cmd_ram_rd_data;
                m_apb_dp_ctrl_pstrb_next = '1;

                state_next = STATE_CREATE_Q_ENABLE;
            end else begin
                state_next = STATE_CREATE_Q_SET_DQN;
            end
        end
        STATE_CREATE_Q_ENABLE: begin
            // enable queue
            cmd_ram_rd_addr = 6;
            if (!m_apb_dp_ctrl_psel_reg) begin
                m_apb_dp_ctrl_paddr_next = dp_ptr_reg + 'h0000;
                m_apb_dp_ctrl_psel_next = 1'b1;
                m_apb_dp_ctrl_pwrite_next = 1'b1;
                m_apb_dp_ctrl_pwdata_next = '0;
                m_apb_dp_ctrl_pwdata_next[23:20] = 4'(qtype_reg); // type
                m_apb_dp_ctrl_pwdata_next[19:16] = cmd_ram_rd_data[3:0]; // size
                m_apb_dp_ctrl_pwdata_next[0] = 1'b1; // enable
                m_apb_dp_ctrl_pstrb_next = '1;

                state_next = STATE_CREATE_Q_PORT_CONFIG;
            end else begin
                state_next = STATE_CREATE_Q_ENABLE;
            end
        end
        STATE_CREATE_Q_PORT_CONFIG: begin
            // set up port
            if (!m_apb_dp_ctrl_psel_reg) begin
                if (qtype_reg == QTYPE_SQ) begin
                    m_apb_dp_ctrl_paddr_next = DP_APB_ADDR_W'(PORT_BASE_ADDR_DP + (dw2_reg[15:0] * PORT_STRIDE) + PORT_CTRL_OFFSET + 'h0010);
                end else begin
                    m_apb_dp_ctrl_paddr_next = DP_APB_ADDR_W'(PORT_BASE_ADDR_DP + (dw2_reg[15:0] * PORT_STRIDE) + PORT_CTRL_OFFSET + 'h0020);
                end
                m_apb_dp_ctrl_psel_next = 1'b1;
                m_apb_dp_ctrl_pwrite_next = qtype_reg == QTYPE_SQ || qtype_reg == QTYPE_RQ;
                m_apb_dp_ctrl_pwdata_next = dw3_reg;
                m_apb_dp_ctrl_pstrb_next = '1;

                m_axis_rsp_tdata_next = '0; // TODO
                m_axis_rsp_tvalid_next = 1'b1;
                m_axis_rsp_tlast_next = 1'b0;

                state_next = STATE_SEND_RSP;
            end else begin
                state_next = STATE_CREATE_Q_PORT_CONFIG;
            end
        end
        STATE_DESTROY_Q_DISABLE: begin
            // disable queue
            if (!m_apb_dp_ctrl_psel_reg) begin
                m_apb_dp_ctrl_paddr_next = dp_ptr_reg + 'h0000;
                m_apb_dp_ctrl_psel_next = 1'b1;
                m_apb_dp_ctrl_pwrite_next = 1'b1;
                m_apb_dp_ctrl_pwdata_next = 32'h00000000;
                m_apb_dp_ctrl_pstrb_next = '1;

                m_axis_rsp_tdata_next = '0; // TODO
                m_axis_rsp_tvalid_next = 1'b1;
                m_axis_rsp_tlast_next = 1'b0;

                state_next = STATE_SEND_RSP;
            end else begin
                state_next = STATE_DESTROY_Q_DISABLE;
            end
        end
        STATE_PTP_READ_1: begin
            // read PTP register
            if (!m_apb_dp_ctrl_psel_reg) begin
                m_apb_dp_ctrl_paddr_next = dp_ptr_reg;
                m_apb_dp_ctrl_psel_next = 1'b1;
                m_apb_dp_ctrl_pwrite_next = 1'b0;
                m_apb_dp_ctrl_pwdata_next = '0;
                m_apb_dp_ctrl_pstrb_next = '1;

                state_next = STATE_PTP_READ_2;
            end else begin
                state_next = STATE_PTP_READ_1;
            end
        end
        STATE_PTP_READ_2: begin
            // store read value and iterate
            cmd_ram_wr_data = m_apb_dp_ctrl.prdata;
            cmd_ram_wr_addr = cmd_ptr_reg;
            cmd_ram_wr_en = 1'b1;

            if (m_apb_dp_ctrl.pready) begin
                cnt_next = cnt_reg + 1;
                cmd_ptr_next = cmd_ptr_reg + 1;
                dp_ptr_next = dp_ptr_reg + 4;

                if (cnt_reg == 11) begin
                    // done
                    m_axis_rsp_tdata_next = '0; // TODO
                    m_axis_rsp_tvalid_next = 1'b1;
                    m_axis_rsp_tlast_next = 1'b0;

                    state_next = STATE_SEND_RSP;
                end else if (cnt_reg == 7) begin
                    // jump to period registers
                    dp_ptr_next = PTP_BASE_ADDR_DP + 'h70;
                    state_next = STATE_PTP_READ_1;
                end else begin
                    // more to read
                    state_next = STATE_PTP_READ_1;
                end
            end else begin
                state_next = STATE_PTP_READ_2;
            end
        end
        STATE_PTP_SET: begin
            // update PTP registers
            if (!m_apb_dp_ctrl_psel_reg) begin
                cnt_next = cnt_reg + 1;
                dp_ptr_next = dp_ptr_reg + 4;

                case (cnt_reg[3:0])
                    4'd0: begin
                        // offset ToD
                        cmd_ram_rd_addr = 3;
                        m_apb_dp_ctrl_psel_next = flags_reg[1];
                    end
                    4'd1: begin
                        // set ToD ns
                        cmd_ram_rd_addr = 3;
                        m_apb_dp_ctrl_psel_next = flags_reg[0];
                    end
                    4'd2: begin
                        // set ToD sec l
                        cmd_ram_rd_addr = 4;
                        m_apb_dp_ctrl_psel_next = flags_reg[0];
                    end
                    4'd3: begin
                        // set ToD sec h
                        cmd_ram_rd_addr = 5;
                        m_apb_dp_ctrl_psel_next = flags_reg[0];
                    end
                    4'd4: begin
                        // set rel ns l
                        cmd_ram_rd_addr = 6;
                        m_apb_dp_ctrl_psel_next = flags_reg[2];
                    end
                    4'd5: begin
                        // set rel ns h
                        cmd_ram_rd_addr = 7;
                        m_apb_dp_ctrl_psel_next = flags_reg[2];
                    end
                    4'd6: begin
                        // offset rel
                        cmd_ram_rd_addr = 6;
                        m_apb_dp_ctrl_psel_next = flags_reg[3];
                    end
                    4'd7: begin
                        // offset FNS
                        cmd_ram_rd_addr = 2;
                        m_apb_dp_ctrl_psel_next = flags_reg[4];
                    end
                    4'd10: begin
                        // period fns
                        cmd_ram_rd_addr = 12;
                        m_apb_dp_ctrl_psel_next = flags_reg[7];
                    end
                    4'd11: begin
                        // period ns
                        cmd_ram_rd_addr = 13;
                        m_apb_dp_ctrl_psel_next = flags_reg[7];
                    end
                    default: begin
                        // skip
                        m_apb_dp_ctrl_psel_next = 1'b0;
                    end
                endcase

                m_apb_dp_ctrl_paddr_next = dp_ptr_reg;
                m_apb_dp_ctrl_pwrite_next = 1'b1;
                m_apb_dp_ctrl_pwdata_next = cmd_ram_rd_data;
                m_apb_dp_ctrl_pstrb_next = '1;

                if (cnt_reg == 11) begin
                    // done
                    m_axis_rsp_tdata_next = '0; // TODO
                    m_axis_rsp_tvalid_next = 1'b1;
                    m_axis_rsp_tlast_next = 1'b0;

                    state_next = STATE_SEND_RSP;
                end else begin
                    // loop
                    state_next = STATE_PTP_SET;
                end
            end else begin
                state_next = STATE_PTP_SET;
            end
        end
        STATE_SEND_RSP: begin
            // send response in the form of an edited command
            cmd_ram_rd_addr = rsp_rd_ptr_reg;
            if (m_axis_rsp.tready || !m_axis_rsp.tvalid) begin
                m_axis_rsp_tdata_next = cmd_ram_rd_data;
                m_axis_rsp_tvalid_next = 1'b1;
                m_axis_rsp_tlast_next = &rsp_rd_ptr_reg;

                if (&rsp_rd_ptr_reg) begin
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
                m_axis_rsp_tlast_next = &rsp_rd_ptr_reg;

                if (&rsp_rd_ptr_reg) begin
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
            rsp_rd_ptr_next = '0;
        end else begin
            rsp_rd_ptr_next = rsp_rd_ptr_reg + 1;
            rsp_frame_next = 1'b1;
        end
    end

    if (m_axis_rsp.tready && m_axis_rsp.tvalid) begin
        if (m_axis_rsp.tlast) begin
            rsp_frame_next = 1'b0;
            rsp_rd_ptr_next = '0;
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
    cmd_wr_ptr_reg <= cmd_wr_ptr_next;
    rsp_frame_reg <= rsp_frame_next;
    rsp_rd_ptr_reg <= rsp_rd_ptr_next;

    drop_cmd_reg <= drop_cmd_next;

    opcode_reg <= opcode_next;
    flags_reg <= flags_next;
    dw2_reg <= dw2_next;
    dw3_reg <= dw3_next;
    dw4_reg <= dw4_next;
    qtype_reg <= qtype_next;

    cmd_ptr_reg <= cmd_ptr_next;
    dp_ptr_reg <= dp_ptr_next;
    host_ptr_reg <= host_ptr_next;
    cnt_reg <= cnt_next;

    if (rst) begin
        state_reg <= STATE_IDLE;

        s_axis_cmd_tready_reg <= 1'b0;
        m_axis_rsp_tvalid_reg <= 1'b0;

        m_apb_dp_ctrl_psel_reg <= 1'b0;
        m_apb_dp_ctrl_penable_reg <= 1'b0;

        cmd_frame_reg <= 1'b0;
        cmd_wr_ptr_reg <= '0;
        rsp_frame_reg <= 1'b0;
        rsp_rd_ptr_reg <= '0;

        drop_cmd_reg <= 1'b0;
    end
end

endmodule

`resetall
