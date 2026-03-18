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
 * Board control module
 */
module cndm_brd_ctrl_i2c #
(
    // Optical module config
    parameter logic OPTIC_EN = 1'b1,
    parameter OPTIC_CNT = 2,

    // EEPROM config
    parameter logic EEPROM_EN = 1'b1,
    parameter EEPROM_IDX = OPTIC_EN ? OPTIC_CNT : 0,

    // MAC in EEPROM config
    parameter logic MAC_EEPROM_EN = EEPROM_EN,
    parameter MAC_EEPROM_IDX = EEPROM_IDX,
    parameter MAC_EEPROM_OFFSET = 0,
    parameter MAC_COUNT = OPTIC_CNT,
    parameter logic MAC_FROM_BASE = 1'b1,

    // Serial number in EEPROM config
    parameter logic SN_EEPROM_EN = EEPROM_EN,
    parameter SN_EEPROM_IDX = EEPROM_IDX,
    parameter SN_EEPROM_OFFSET = 0,
    parameter SN_LEN = 16,

    // PLL configuration
    parameter logic PLL_EN = 1'b1,
    parameter PLL_IDX = EEPROM_IDX + (EEPROM_EN ? 1 : 0),
    // TODO

    // Mux configuration
    parameter logic MUX_EN = 1'b1,
    parameter MUX_CNT = 1,
    // I2C addresses of muxes
    parameter logic [MUX_CNT-1:0][6:0] MUX_I2C_ADDR = 7'h74,

    // I2C device config
    // Optical module commands index list directly, so optical modules must be
    // listed first and in order, folllowed by other devices
    // Total nuber of devices
    parameter DEV_CNT = PLL_IDX + (PLL_EN ? 1 : 0),
    // Device I2C addresses
    parameter logic [DEV_CNT-1:0][6:0] DEV_I2C_ADDR = {DEV_CNT{7'h50}},
    // Device addressing configuration
    // 31:24 - bank register offset
    // 23:16 - page register offset
    // 6 - uses multiple I2C addresses
    // 5 - has bank register
    // 4 - has page register
    // 1:0 - address size (1, 2, 4, or 8 bytes)
    // Examples:
    // 2K EEPROM: 32'h00_00_0000
    // 8K EEPROM: 32'h00_00_0040 (four I2C addresses)
    // SFP: 32'h00_7f_0050 (two I2C addresses)
    // QSFP-DD: 32'h7e_7f_0030
    // Most general optic: 32'h7e_7f_0070
    parameter logic [DEV_CNT-1:0][31:0] DEV_ADDR_CFG = {DEV_CNT{32'h7e_7f_0070}},
    // Mux settings for each device
    parameter logic [DEV_CNT-1:0][MUX_CNT-1:0][7:0] DEV_MUX_MASK = '0,

    // Prescaler for I2C master
    parameter I2C_PRESCALE = 125000/(400*4)
)
(
    input  wire logic                clk,
    input  wire logic                rst,

    /*
     * Board control command interface
     */
    taxi_axis_if.snk                 s_axis_cmd,
    taxi_axis_if.src                 m_axis_rsp,

    /*
     * I2C interface
     */
    input  wire logic                i2c_scl_i,
    output wire logic                i2c_scl_o,
    input  wire logic                i2c_sda_i,
    output wire logic                i2c_sda_o,

    output wire logic [DEV_CNT-1:0]  dev_sel,
    output wire logic [DEV_CNT-1:0]  dev_rst
);

// extract parameters
localparam CMD_ID_W = s_axis_cmd.ID_W;

localparam CL_DEV_IDX = DEV_CNT > 1 ? $clog2(DEV_CNT) : 1;
localparam CL_MUX_IDX = MUX_CNT > 1 ? $clog2(MUX_CNT) : 1;

typedef enum logic [15:0] {
    CMD_BRD_OP_NOP = 16'h0000,

    CMD_BRD_OP_FLASH_RD  = 16'h0100,
    CMD_BRD_OP_FLASH_WR  = 16'h0101,
    CMD_BRD_OP_FLASH_CMD = 16'h0108,

    CMD_BRD_OP_EEPROM_RD = 16'h0200,
    CMD_BRD_OP_EEPROM_WR = 16'h0201,

    CMD_BRD_OP_OPTIC_RD = 16'h0300,
    CMD_BRD_OP_OPTIC_WR = 16'h0301,

    CMD_BRD_OP_HWID_SN_RD  = 16'h0400,
    CMD_BRD_OP_HWID_VPD_RD = 16'h0410,
    CMD_BRD_OP_HWID_MAC_RD = 16'h0480,

    CMD_BRD_OP_PLL_STATUS_RD   = 16'h0500,
    CMD_BRD_OP_PLL_TUNE_RAW_RD = 16'h0502,
    CMD_BRD_OP_PLL_TUNE_RAW_WR = 16'h0503,
    CMD_BRD_OP_PLL_TUNE_PPT_RD = 16'h0504,
    CMD_BRD_OP_PLL_TUNE_PPT_WR = 16'h0505,

    CMD_BRD_OP_I2C_RD = 16'h8100,
    CMD_BRD_OP_I2C_WR = 16'h8101
} cmd_brd_opcode_t;

typedef enum logic [15:0] {
    CMD_STS_OK = 16'h0000,
    CMD_STS_EPERM = 16'h0001,
    CMD_STS_EIO = 16'h0005,
    CMD_STS_ENXIO = 16'h0006,
    CMD_STS_EAGAIN = 16'h000B,
    CMD_STS_ENOMEM = 16'h000C,
    CMD_STS_EACCESS = 16'h000D,
    CMD_STS_EFAULT = 16'h000E,
    CMD_STS_EBUSY = 16'h0010,
    CMD_STS_ENODEV = 16'h0013,
    CMD_STS_EINVAL = 16'h0016,
    CMD_STS_ENOSPC = 16'h001C,
    CMD_STS_EDOM = 16'h0021,
    CMD_STS_ERANGE = 16'h0022,
    CMD_STS_ENOTSUP = 16'h005F,
    CMD_STS_ETIMEDOUT = 16'h006E
} cmd_status_t;

typedef enum logic [4:0] {
    STATE_IDLE,
    STATE_START,
    STATE_OP_DONE,
    STATE_I2C_START,
    STATE_I2C_SET_MUX,
    STATE_I2C_SET_PAGE_1,
    STATE_I2C_SET_PAGE_2,
    STATE_I2C_SET_BANK_1,
    STATE_I2C_SET_BANK_2,
    STATE_I2C_SET_ADDR_1,
    STATE_I2C_SET_ADDR_2,
    STATE_I2C_RD_DATA,
    STATE_I2C_WR_DATA,
    STATE_SEND_RSP,
    STATE_PAD_RSP
} state_t;

state_t state_reg = STATE_IDLE, state_next;
state_t ret_state_reg = STATE_IDLE, ret_state_next;

logic s_axis_cmd_tready_reg = 1'b0, s_axis_cmd_tready_next;

assign s_axis_cmd.tready = s_axis_cmd_tready_reg;

logic [31:0] m_axis_rsp_tdata_reg = '0, m_axis_rsp_tdata_next;
logic m_axis_rsp_tvalid_reg = 1'b0, m_axis_rsp_tvalid_next;
logic m_axis_rsp_tlast_reg = 1'b0, m_axis_rsp_tlast_next;
logic [CMD_ID_W-1:0] m_axis_rsp_tid_reg = '0, m_axis_rsp_tid_next;

assign m_axis_rsp.tdata  = m_axis_rsp_tdata_reg;
assign m_axis_rsp.tkeep  = '1;
assign m_axis_rsp.tstrb  = m_axis_rsp.tkeep;
assign m_axis_rsp.tvalid = m_axis_rsp_tvalid_reg;
assign m_axis_rsp.tlast  = m_axis_rsp_tlast_reg;
assign m_axis_rsp.tid    = m_axis_rsp_tid_reg;
assign m_axis_rsp.tdest  = '0;
assign m_axis_rsp.tuser  = '0;

// command RAM
localparam CMD_AW = 4;

logic [31:0] cmd_ram[2**CMD_AW] = '{default: '0};
logic [31:0] cmd_ram_wr_data;
logic [3:0] cmd_ram_wr_strb;
logic [CMD_AW-1:0] cmd_ram_wr_addr;
logic cmd_ram_wr_en;
logic [CMD_AW-1:0] cmd_ram_rd_addr;
wire [31:0] cmd_ram_rd_data = cmd_ram[cmd_ram_rd_addr];

taxi_axis_if #(.DATA_W(12), .KEEP_W(1)) axis_i2c_cmd();
taxi_axis_if #(.DATA_W(8)) axis_i2c_tx();
taxi_axis_if #(.DATA_W(8)) axis_i2c_rx();

localparam logic [11:0]
    I2C_CMD_START        = 12'h080,
    I2C_CMD_READ         = 12'h100,
    I2C_CMD_WRITE        = 12'h200,
    I2C_CMD_WRITE_MULTI  = 12'h400,
    I2C_CMD_STOP         = 12'h800;

taxi_i2c_master
i2c_master_inst (
    .clk(clk),
    .rst(rst),

    /*
    * Host interface
    */
    .s_axis_cmd(axis_i2c_cmd),
    .s_axis_tx(axis_i2c_tx),
    .m_axis_rx(axis_i2c_rx),

    /*
    * I2C interface
    */
    .scl_i(i2c_scl_i),
    .scl_o(i2c_scl_o),
    .sda_i(i2c_sda_i),
    .sda_o(i2c_sda_o),

    /*
    * Status
    */
    .busy(),
    .bus_control(),
    .bus_active(),
    .missed_ack(),

    /*
    * Configuration
    */
    .prescale(16'(I2C_PRESCALE)),
    .stop_on_idle(1'b0)
);

logic [11:0] axis_i2c_cmd_tdata_reg = '0, axis_i2c_cmd_tdata_next;
logic axis_i2c_cmd_tvalid_reg = '0, axis_i2c_cmd_tvalid_next;

assign axis_i2c_cmd.tdata  = axis_i2c_cmd_tdata_reg;
assign axis_i2c_cmd.tkeep  = '1;
assign axis_i2c_cmd.tstrb  = axis_i2c_cmd.tkeep;
assign axis_i2c_cmd.tvalid = axis_i2c_cmd_tvalid_reg;
assign axis_i2c_cmd.tlast  = 1'b1;
assign axis_i2c_cmd.tid    = '0;
assign axis_i2c_cmd.tdest  = '0;
assign axis_i2c_cmd.tuser  = '0;

logic [7:0] axis_i2c_tx_tdata_reg = '0, axis_i2c_tx_tdata_next;
logic axis_i2c_tx_tlast_reg = '0, axis_i2c_tx_tlast_next;
logic axis_i2c_tx_tvalid_reg = '0, axis_i2c_tx_tvalid_next;

assign axis_i2c_tx.tdata  = axis_i2c_tx_tdata_reg;
assign axis_i2c_tx.tkeep  = '1;
assign axis_i2c_tx.tstrb  = axis_i2c_tx.tkeep;
assign axis_i2c_tx.tvalid = axis_i2c_tx_tvalid_reg;
assign axis_i2c_tx.tlast  = axis_i2c_tx_tlast_reg;
assign axis_i2c_tx.tid    = '0;
assign axis_i2c_tx.tdest  = '0;
assign axis_i2c_tx.tuser  = '0;

logic axis_i2c_rx_tready_reg = '0, axis_i2c_rx_tready_next;

assign axis_i2c_rx.tready = axis_i2c_rx_tready_reg;

logic [DEV_CNT-1:0] dev_sel_reg = '0, dev_sel_next;
logic [DEV_CNT-1:0] dev_rst_reg = '0, dev_rst_next;

assign dev_sel = dev_sel_reg;
assign dev_rst = dev_rst_reg;

logic cmd_frame_reg = 1'b0, cmd_frame_next;
logic [3:0] cmd_wr_ptr_reg = '0, cmd_wr_ptr_next;
logic rsp_frame_reg = 1'b0, rsp_frame_next;
logic [3:0] rsp_rd_ptr_reg = '0, rsp_rd_ptr_next;

logic drop_cmd_reg = 1'b0, drop_cmd_next;

logic [15:0] opcode_reg = '0, opcode_next;
logic [15:0] idx_reg = '0, idx_next;
logic [31:0] flags_reg = '0, flags_next;
logic [31:0] dw2_reg = '0, dw2_next;
logic [31:0] dw3_reg = '0, dw3_next;
logic [31:0] dw4_reg = '0, dw4_next;

logic [5:0] cmd_ptr_reg = '0, cmd_ptr_next;
logic [15:0] cnt_reg = '0, cnt_next;

logic [CL_MUX_IDX-1:0] mux_idx_reg = '0, mux_idx_next;
logic [CL_DEV_IDX-1:0] dev_idx_reg = '0, dev_idx_next;

logic [6:0] i2c_addr_reg = '0, i2c_addr_next;
logic [31:0] dev_addr_reg = '0, dev_addr_next;
logic [7:0] dev_bank_reg = '0, dev_bank_next;
logic [7:0] dev_page_reg = '0, dev_page_next;
logic [31:0] dev_addr_cfg_reg = '0, dev_addr_cfg_next;
logic [1:0] addr_ptr_reg = '0, addr_ptr_next;
logic mode_write_reg = 1'b0, mode_write_next;

always_comb begin
    state_next = STATE_IDLE;
    ret_state_next = ret_state_reg;

    s_axis_cmd_tready_next = 1'b0;

    m_axis_rsp_tdata_next = m_axis_rsp_tdata_reg;
    m_axis_rsp_tvalid_next = m_axis_rsp_tvalid_reg && !m_axis_rsp.tready;
    m_axis_rsp_tlast_next = m_axis_rsp_tlast_reg;
    m_axis_rsp_tid_next = m_axis_rsp_tid_reg;

    axis_i2c_cmd_tdata_next = axis_i2c_cmd_tdata_reg;
    axis_i2c_cmd_tvalid_next = axis_i2c_cmd_tvalid_reg && !axis_i2c_cmd.tready;

    axis_i2c_tx_tdata_next = axis_i2c_tx_tdata_reg;
    axis_i2c_tx_tlast_next = axis_i2c_tx_tlast_reg;
    axis_i2c_tx_tvalid_next = axis_i2c_tx_tvalid_reg && !axis_i2c_tx.tready;

    axis_i2c_rx_tready_next = 1'b0;

    dev_sel_next = dev_sel_reg;
    dev_rst_next = dev_rst_reg;

    cmd_ram_wr_data = s_axis_cmd.tdata;
    cmd_ram_wr_strb = '1;
    cmd_ram_wr_addr = cmd_wr_ptr_reg;
    cmd_ram_wr_en = 1'b0;
    cmd_ram_rd_addr = '0;

    cmd_frame_next = cmd_frame_reg;
    cmd_wr_ptr_next = cmd_wr_ptr_reg;
    rsp_frame_next = rsp_frame_reg;
    rsp_rd_ptr_next = rsp_rd_ptr_reg;

    drop_cmd_next = drop_cmd_reg;

    opcode_next = opcode_reg;
    idx_next = idx_reg;
    flags_next = flags_reg;
    dw2_next = dw2_reg;
    dw3_next = dw3_reg;
    dw4_next = dw4_reg;

    cmd_ptr_next = cmd_ptr_reg;
    cnt_next = cnt_reg;

    mux_idx_next = mux_idx_reg;
    dev_idx_next = dev_idx_reg;

    i2c_addr_next = i2c_addr_reg;
    dev_addr_next = dev_addr_reg;
    dev_bank_next = dev_bank_reg;
    dev_page_next = dev_page_reg;
    dev_addr_cfg_next = dev_addr_cfg_reg;
    addr_ptr_next = addr_ptr_reg;
    mode_write_next = mode_write_reg;

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
            dev_sel_next = '0;

            s_axis_cmd_tready_next = !m_axis_rsp_tvalid_reg && !rsp_frame_reg;

            cmd_ram_wr_data = s_axis_cmd.tdata;
            cmd_ram_wr_strb = '1;
            cmd_ram_wr_addr = cmd_wr_ptr_reg;
            cmd_ram_wr_en = 1'b1;

            // save some important fields
            case (cmd_wr_ptr_reg)
                4'd0: {opcode_next, idx_next} = s_axis_cmd.tdata;
                4'd1: flags_next = s_axis_cmd.tdata;
                4'd2: dw2_next = s_axis_cmd.tdata;
                4'd3: dw3_next = s_axis_cmd.tdata;
                4'd4: dw4_next = s_axis_cmd.tdata;
                default: begin end
            endcase

            if (s_axis_cmd.tready && s_axis_cmd.tvalid && !drop_cmd_reg) begin
                if (s_axis_cmd.tlast || &cmd_wr_ptr_reg) begin
                    s_axis_cmd_tready_next = !s_axis_cmd.tlast;
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
            cnt_next = '0;

            case (opcode_reg)
                CMD_BRD_OP_NOP: begin
                    // NOP
                    m_axis_rsp_tdata_next[15:0] = '0; // rsvd
                    m_axis_rsp_tdata_next[31:16] = CMD_STS_OK;
                    m_axis_rsp_tvalid_next = 1'b1;
                    m_axis_rsp_tlast_next = 1'b0;

                    state_next = STATE_SEND_RSP;
                end
                CMD_BRD_OP_EEPROM_RD: begin
                    if (EEPROM_EN) begin
                        dev_idx_next = EEPROM_IDX;
                        i2c_addr_next = DEV_I2C_ADDR[dev_idx_next];
                        dev_addr_next = dw3_reg;
                        dev_bank_next = dw2_reg[15:8];
                        dev_page_next = dw2_reg[7:0];
                        cnt_next = 16'(dw4_reg);
                        cmd_ptr_next = 24;

                        mode_write_next = 1'b0;

                        ret_state_next = STATE_OP_DONE;
                        state_next = STATE_I2C_START;
                    end else begin
                        m_axis_rsp_tdata_next[15:0] = '0; // rsvd
                        m_axis_rsp_tdata_next[31:16] = CMD_STS_ENOTSUP;
                        m_axis_rsp_tvalid_next = 1'b1;
                        m_axis_rsp_tlast_next = 1'b0;

                        state_next = STATE_PAD_RSP;
                    end
                end
                CMD_BRD_OP_EEPROM_WR: begin
                    if (EEPROM_EN) begin
                        dev_idx_next = EEPROM_IDX;
                        i2c_addr_next = DEV_I2C_ADDR[dev_idx_next];
                        dev_addr_next = dw3_reg;
                        dev_bank_next = dw2_reg[15:8];
                        dev_page_next = dw2_reg[7:0];
                        cnt_next = 16'(dw4_reg);
                        cmd_ptr_next = 24;

                        mode_write_next = 1'b1;

                        ret_state_next = STATE_OP_DONE;
                        state_next = STATE_I2C_START;
                    end else begin
                        m_axis_rsp_tdata_next[15:0] = '0; // rsvd
                        m_axis_rsp_tdata_next[31:16] = CMD_STS_ENOTSUP;
                        m_axis_rsp_tvalid_next = 1'b1;
                        m_axis_rsp_tlast_next = 1'b0;

                        state_next = STATE_PAD_RSP;
                    end
                end
                CMD_BRD_OP_OPTIC_RD: begin
                    if (OPTIC_EN) begin
                        dev_idx_next = CL_DEV_IDX'(idx_reg);
                        i2c_addr_next = DEV_I2C_ADDR[dev_idx_next];
                        dev_addr_next = dw3_reg;
                        dev_bank_next = dw2_reg[15:8];
                        dev_page_next = dw2_reg[7:0];
                        cnt_next = 16'(dw4_reg);
                        cmd_ptr_next = 24;

                        mode_write_next = 1'b0;

                        ret_state_next = STATE_OP_DONE;
                        state_next = STATE_I2C_START;
                    end else begin
                        m_axis_rsp_tdata_next[15:0] = '0; // rsvd
                        m_axis_rsp_tdata_next[31:16] = CMD_STS_ENOTSUP;
                        m_axis_rsp_tvalid_next = 1'b1;
                        m_axis_rsp_tlast_next = 1'b0;

                        state_next = STATE_PAD_RSP;
                    end
                end
                CMD_BRD_OP_OPTIC_WR: begin
                    if (OPTIC_EN) begin
                        dev_idx_next = CL_DEV_IDX'(idx_reg);
                        i2c_addr_next = DEV_I2C_ADDR[dev_idx_next];
                        dev_addr_next = dw3_reg;
                        dev_bank_next = dw2_reg[15:8];
                        dev_page_next = dw2_reg[7:0];
                        cnt_next = 16'(dw4_reg);
                        cmd_ptr_next = 24;

                        mode_write_next = 1'b1;

                        ret_state_next = STATE_OP_DONE;
                        state_next = STATE_I2C_START;
                    end else begin
                        m_axis_rsp_tdata_next[15:0] = '0; // rsvd
                        m_axis_rsp_tdata_next[31:16] = CMD_STS_ENOTSUP;
                        m_axis_rsp_tvalid_next = 1'b1;
                        m_axis_rsp_tlast_next = 1'b0;

                        state_next = STATE_PAD_RSP;
                    end
                end
                CMD_BRD_OP_HWID_SN_RD: begin
                    if (SN_EEPROM_EN) begin
                        dev_idx_next = SN_EEPROM_IDX;
                        i2c_addr_next = DEV_I2C_ADDR[dev_idx_next];
                        dev_addr_next = SN_EEPROM_OFFSET;
                        dev_bank_next = 0;
                        dev_page_next = 0;
                        cnt_next = SN_LEN;
                        cmd_ptr_next = 24;

                        // TODO write len

                        mode_write_next = 1'b0;

                        ret_state_next = STATE_OP_DONE;
                        state_next = STATE_I2C_START;
                    end else begin
                        m_axis_rsp_tdata_next[15:0] = '0; // rsvd
                        m_axis_rsp_tdata_next[31:16] = CMD_STS_ENOTSUP;
                        m_axis_rsp_tvalid_next = 1'b1;
                        m_axis_rsp_tlast_next = 1'b0;

                        state_next = STATE_PAD_RSP;
                    end
                end
                // CMD_BRD_OP_HWID_VPD_RD
                CMD_BRD_OP_HWID_MAC_RD: begin
                    if (MAC_EEPROM_EN) begin
                        dev_idx_next = MAC_EEPROM_IDX;
                        i2c_addr_next = DEV_I2C_ADDR[dev_idx_next];
                        dev_addr_next = MAC_EEPROM_OFFSET;
                        dev_bank_next = 0;
                        dev_page_next = 0;
                        cnt_next = 6;
                        cmd_ptr_next = 26;

                        // TODO write count, len

                        mode_write_next = 1'b0;

                        ret_state_next = STATE_OP_DONE;
                        state_next = STATE_I2C_START;
                    end else begin
                        m_axis_rsp_tdata_next[15:0] = '0; // rsvd
                        m_axis_rsp_tdata_next[31:16] = CMD_STS_ENOTSUP;
                        m_axis_rsp_tvalid_next = 1'b1;
                        m_axis_rsp_tlast_next = 1'b0;

                        state_next = STATE_PAD_RSP;
                    end
                end
                // CMD_BRD_OP_PLL_STATUS_RD
                // CMD_BRD_OP_PLL_TUNE_RAW_RD
                // CMD_BRD_OP_PLL_TUNE_RAW_WR
                // CMD_BRD_OP_PLL_TUNE_PPT_RD
                // CMD_BRD_OP_PLL_TUNE_PPT_WR
                CMD_BRD_OP_I2C_RD: begin
                    dev_idx_next = CL_DEV_IDX'(idx_reg);
                    i2c_addr_next = DEV_I2C_ADDR[dev_idx_next];
                    dev_addr_next = dw3_reg;
                    dev_bank_next = dw2_reg[15:8];
                    dev_page_next = dw2_reg[7:0];
                    cnt_next = 16'(dw4_reg);
                    cmd_ptr_next = 24;

                    mode_write_next = 1'b0;

                    ret_state_next = STATE_OP_DONE;
                    state_next = STATE_I2C_START;
                end
                CMD_BRD_OP_I2C_WR: begin
                    dev_idx_next = CL_DEV_IDX'(idx_reg);
                    i2c_addr_next = DEV_I2C_ADDR[dev_idx_next];
                    dev_addr_next = dw3_reg;
                    dev_bank_next = dw2_reg[15:8];
                    dev_page_next = dw2_reg[7:0];
                    cnt_next = 16'(dw4_reg);
                    cmd_ptr_next = 24;

                    mode_write_next = 1'b1;

                    ret_state_next = STATE_OP_DONE;
                    state_next = STATE_I2C_START;
                end
                default: begin
                    // unknown opcode
                    m_axis_rsp_tdata_next[15:0] = '0; // rsvd
                    m_axis_rsp_tdata_next[31:16] = CMD_STS_EINVAL;
                    m_axis_rsp_tvalid_next = 1'b1;
                    m_axis_rsp_tlast_next = 1'b0;

                    state_next = STATE_PAD_RSP;
                end
            endcase
        end
        STATE_OP_DONE: begin
            // return status code
            m_axis_rsp_tdata_next[15:0] = '0; // rsvd
            m_axis_rsp_tdata_next[31:16] = CMD_STS_OK;
            m_axis_rsp_tvalid_next = 1'b1;
            m_axis_rsp_tlast_next = 1'b0;

            state_next = STATE_SEND_RSP;
        end
        STATE_I2C_START: begin
            mux_idx_next = '0;
            dev_sel_next = '0;
            dev_sel_next[dev_idx_reg] = 1'b1;

            dev_addr_cfg_next = DEV_ADDR_CFG[dev_idx_reg];
            addr_ptr_next = dev_addr_cfg_next[1:0];

            if (MUX_EN) begin
                state_next = STATE_I2C_SET_MUX;
            end else begin
                if (dev_addr_cfg_next[5]) begin
                    state_next = STATE_I2C_SET_BANK_1;
                end else if (dev_addr_cfg_next[4]) begin
                    state_next = STATE_I2C_SET_PAGE_1;
                end else begin
                    state_next = STATE_I2C_SET_ADDR_1;
                end
            end
        end
        STATE_I2C_SET_MUX: begin
            // Configure I2C mux(es)
            if (!axis_i2c_cmd_tvalid_reg && !axis_i2c_tx_tvalid_reg) begin
                axis_i2c_cmd_tdata_next = 12'(MUX_I2C_ADDR[mux_idx_reg]) | I2C_CMD_START | I2C_CMD_WRITE | I2C_CMD_STOP;
                axis_i2c_cmd_tvalid_next = 1'b1;

                axis_i2c_tx_tdata_next = DEV_MUX_MASK[dev_idx_reg][mux_idx_reg];
                axis_i2c_tx_tlast_next = 1'b1;
                axis_i2c_tx_tvalid_next = 1'b1;

                mux_idx_next = mux_idx_reg + 1;

                if (mux_idx_reg == CL_MUX_IDX'(MUX_CNT-1)) begin
                    if (dev_addr_cfg_next[5]) begin
                        state_next = STATE_I2C_SET_BANK_1;
                    end else if (dev_addr_cfg_next[4]) begin
                        state_next = STATE_I2C_SET_PAGE_1;
                    end else begin
                        state_next = STATE_I2C_SET_ADDR_1;
                    end
                end else begin
                    state_next = STATE_I2C_SET_MUX;
                end
            end else begin
                state_next = STATE_I2C_SET_MUX;
            end
        end
        STATE_I2C_SET_BANK_1: begin
            // Select bank register
            if (!axis_i2c_cmd_tvalid_reg && !axis_i2c_tx_tvalid_reg) begin
                axis_i2c_cmd_tdata_next = 12'(i2c_addr_reg) | I2C_CMD_START | I2C_CMD_WRITE;
                axis_i2c_cmd_tvalid_next = 1'b1;

                axis_i2c_tx_tdata_next = dev_addr_cfg_reg[24 +: 8];
                axis_i2c_tx_tlast_next = 1'b1;
                axis_i2c_tx_tvalid_next = 1'b1;

                state_next = STATE_I2C_SET_BANK_2;
            end else begin
                state_next = STATE_I2C_SET_BANK_1;
            end
        end
        STATE_I2C_SET_BANK_2: begin
            // Set bank register
            if (!axis_i2c_cmd_tvalid_reg && !axis_i2c_tx_tvalid_reg) begin
                axis_i2c_cmd_tdata_next = 12'(i2c_addr_reg) | I2C_CMD_WRITE | I2C_CMD_STOP;
                axis_i2c_cmd_tvalid_next = 1'b1;

                axis_i2c_tx_tdata_next = dev_bank_reg;
                axis_i2c_tx_tlast_next = 1'b1;
                axis_i2c_tx_tvalid_next = 1'b1;

                if (dev_addr_cfg_next[4]) begin
                    state_next = STATE_I2C_SET_PAGE_1;
                end else begin
                    state_next = STATE_I2C_SET_ADDR_1;
                end
            end else begin
                state_next = STATE_I2C_SET_BANK_2;
            end
        end
        STATE_I2C_SET_PAGE_1: begin
            // Select page register
            if (!axis_i2c_cmd_tvalid_reg && !axis_i2c_tx_tvalid_reg) begin
                axis_i2c_cmd_tdata_next = 12'(i2c_addr_reg) | I2C_CMD_START | I2C_CMD_WRITE;
                axis_i2c_cmd_tvalid_next = 1'b1;

                axis_i2c_tx_tdata_next = dev_addr_cfg_reg[16 +: 8];
                axis_i2c_tx_tlast_next = 1'b1;
                axis_i2c_tx_tvalid_next = 1'b1;

                state_next = STATE_I2C_SET_PAGE_2;
            end else begin
                state_next = STATE_I2C_SET_PAGE_1;
            end
        end
        STATE_I2C_SET_PAGE_2: begin
            // Set page register
            if (!axis_i2c_cmd_tvalid_reg && !axis_i2c_tx_tvalid_reg) begin
                axis_i2c_cmd_tdata_next = 12'(i2c_addr_reg) | I2C_CMD_WRITE | I2C_CMD_STOP;
                axis_i2c_cmd_tvalid_next = 1'b1;

                axis_i2c_tx_tdata_next = dev_page_reg;
                axis_i2c_tx_tlast_next = 1'b1;
                axis_i2c_tx_tvalid_next = 1'b1;

                state_next = STATE_I2C_SET_ADDR_1;
            end else begin
                state_next = STATE_I2C_SET_PAGE_2;
            end
        end
        STATE_I2C_SET_ADDR_1: begin
            // Set device internal address
            if (!axis_i2c_cmd_tvalid_reg && !axis_i2c_tx_tvalid_reg) begin
                axis_i2c_cmd_tdata_next = 12'(i2c_addr_reg) | I2C_CMD_START | I2C_CMD_WRITE;
                axis_i2c_cmd_tvalid_next = 1'b1;

                axis_i2c_tx_tdata_next = dev_addr_reg[addr_ptr_reg*8 +: 8];
                axis_i2c_tx_tlast_next = 1'b1;
                axis_i2c_tx_tvalid_next = 1'b1;

                addr_ptr_next = addr_ptr_reg - 1;

                if (addr_ptr_reg == 0) begin
                    if (mode_write_reg) begin
                        state_next = STATE_I2C_WR_DATA;
                    end else begin
                        state_next = STATE_I2C_RD_DATA;
                    end
                end else begin
                    state_next = STATE_I2C_SET_ADDR_2;
                end
            end else begin
                state_next = STATE_I2C_SET_ADDR_1;
            end
        end
        STATE_I2C_SET_ADDR_2: begin
            // Set device internal address
            if (!axis_i2c_cmd_tvalid_reg && !axis_i2c_tx_tvalid_reg) begin
                axis_i2c_cmd_tdata_next = 12'(i2c_addr_reg) | I2C_CMD_WRITE;
                axis_i2c_cmd_tvalid_next = 1'b1;

                axis_i2c_tx_tdata_next = dev_addr_reg[addr_ptr_reg*8 +: 8];
                axis_i2c_tx_tlast_next = 1'b1;
                axis_i2c_tx_tvalid_next = 1'b1;

                addr_ptr_next = addr_ptr_reg - 1;

                if (addr_ptr_reg == 0) begin
                    if (mode_write_reg) begin
                        state_next = STATE_I2C_WR_DATA;
                    end else begin
                        state_next = STATE_I2C_RD_DATA;
                    end
                end else begin
                    state_next = STATE_I2C_SET_ADDR_2;
                end
            end else begin
                state_next = STATE_I2C_SET_ADDR_2;
            end
        end
        STATE_I2C_RD_DATA: begin
            // Copy data from I2C to RAM

            // start I2C reads
            if (!axis_i2c_cmd_tvalid_reg) begin
                axis_i2c_cmd_tdata_next = 12'(i2c_addr_reg) | I2C_CMD_READ | ((cnt_reg == 0 || cnt_reg == 1) ? I2C_CMD_STOP : '0);
                if (cnt_reg != 0) begin
                    axis_i2c_cmd_tvalid_next = 1'b1;
                    cnt_next = cnt_reg - 1;
                end
            end

            // store data
            axis_i2c_rx_tready_next = 1'b1;

            cmd_ram_wr_data = {4{axis_i2c_rx.tdata}};
            cmd_ram_wr_strb = '0;
            cmd_ram_wr_strb[cmd_ptr_reg[1:0]] = 1'b1;
            cmd_ram_wr_addr = cmd_ptr_reg[5:2];

            if (axis_i2c_rx.tready && axis_i2c_rx.tvalid) begin
                axis_i2c_rx_tready_next = 1'b0;
                cmd_ram_wr_en = 1'b1;
                cmd_ptr_next = cmd_ptr_reg + 1;
                if (axis_i2c_rx.tlast) begin
                    state_next = ret_state_reg;
                end else begin
                    state_next = STATE_I2C_RD_DATA;
                end
            end else begin
                state_next = STATE_I2C_RD_DATA;
            end
        end
        STATE_I2C_WR_DATA: begin
            // Copy data from RAM to I2C
            cmd_ram_rd_addr = cmd_ptr_reg[5:2];

            if (!axis_i2c_cmd_tvalid_reg && !axis_i2c_tx_tvalid_reg) begin
                cmd_ptr_next = cmd_ptr_reg + 1;

                axis_i2c_cmd_tdata_next = 12'(i2c_addr_reg) | I2C_CMD_WRITE | ((cnt_reg == 0 || cnt_reg == 1) ? I2C_CMD_STOP : '0);
                axis_i2c_cmd_tvalid_next = 1'b1;

                axis_i2c_tx_tdata_next = cmd_ram_rd_data[cmd_ptr_reg[1:0]*8 +: 8];
                axis_i2c_tx_tlast_next = 1'b1;
                axis_i2c_tx_tvalid_next = 1'b1;

                cnt_next = cnt_reg - 1;
                if (cnt_reg == 0) begin
                    state_next = ret_state_reg;
                end else begin
                    state_next = STATE_I2C_WR_DATA;
                end
            end else begin
                state_next = STATE_I2C_WR_DATA;
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
        for (integer i = 0; i < 4; i = i + 1) begin
            if (cmd_ram_wr_strb[i]) begin
                cmd_ram[cmd_ram_wr_addr][i*8 +: 8] = cmd_ram_wr_data[i*8 +: 8];
            end
        end
    end
end

always_ff @(posedge clk) begin
    state_reg <= state_next;
    ret_state_reg <= ret_state_next;

    s_axis_cmd_tready_reg <= s_axis_cmd_tready_next;

    m_axis_rsp_tdata_reg <= m_axis_rsp_tdata_next;
    m_axis_rsp_tvalid_reg <= m_axis_rsp_tvalid_next;
    m_axis_rsp_tlast_reg <= m_axis_rsp_tlast_next;
    m_axis_rsp_tid_reg <= m_axis_rsp_tid_next;

    axis_i2c_cmd_tdata_reg <= axis_i2c_cmd_tdata_next;
    axis_i2c_cmd_tvalid_reg <= axis_i2c_cmd_tvalid_next;

    axis_i2c_tx_tdata_reg <= axis_i2c_tx_tdata_next;
    axis_i2c_tx_tlast_reg <= axis_i2c_tx_tlast_next;
    axis_i2c_tx_tvalid_reg <= axis_i2c_tx_tvalid_next;

    axis_i2c_rx_tready_reg <= axis_i2c_rx_tready_next;

    dev_sel_reg <= dev_sel_next;
    dev_rst_reg <= dev_rst_next;

    cmd_frame_reg <= cmd_frame_next;
    cmd_wr_ptr_reg <= cmd_wr_ptr_next;
    rsp_frame_reg <= rsp_frame_next;
    rsp_rd_ptr_reg <= rsp_rd_ptr_next;

    drop_cmd_reg <= drop_cmd_next;

    opcode_reg <= opcode_next;
    idx_reg <= idx_next;
    flags_reg <= flags_next;
    dw2_reg <= dw2_next;
    dw3_reg <= dw3_next;
    dw4_reg <= dw4_next;

    cmd_ptr_reg <= cmd_ptr_next;
    cnt_reg <= cnt_next;

    mux_idx_reg <= mux_idx_next;
    dev_idx_reg <= dev_idx_next;

    i2c_addr_reg <= i2c_addr_next;
    dev_addr_reg <= dev_addr_next;
    dev_bank_reg <= dev_bank_next;
    dev_page_reg <= dev_page_next;
    dev_addr_cfg_reg <= dev_addr_cfg_next;
    addr_ptr_reg <= addr_ptr_next;
    mode_write_reg <= mode_write_next;

    if (rst) begin
        state_reg <= STATE_IDLE;

        s_axis_cmd_tready_reg <= 1'b0;
        m_axis_rsp_tvalid_reg <= 1'b0;

        axis_i2c_cmd_tvalid_reg <= 1'b0;
        axis_i2c_tx_tvalid_reg <= 1'b0;
        axis_i2c_rx_tready_reg <= 1'b0;

        dev_sel_reg <= '0;
        dev_rst_reg <= '0;

        cmd_frame_reg <= 1'b0;
        cmd_wr_ptr_reg <= '0;
        rsp_frame_reg <= 1'b0;
        rsp_rd_ptr_reg <= '0;

        drop_cmd_reg <= 1'b0;
    end
end

endmodule

`resetall
