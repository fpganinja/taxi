// SPDX-License-Identifier: CERN-OHL-S-2.0
/*

Copyright (c) 2021-2025 FPGA Ninja, LLC

Authors:
- Alex Forencich

*/

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * Statistics collector
 */
module taxi_stats_collect #
(
    // Channel count
    parameter CNT = 8,
    // Increment width (bits)
    parameter INC_W = 8,
    // Base statistic ID
    parameter ID_BASE = 0,
    // Statistics counter update period (cycles)
    parameter UPDATE_PERIOD = 1024,
    // Enable strings
    parameter logic STR_EN = 1'b0,
    // Common prefix string (8 characters)
    parameter logic [8*8-1:0] PREFIX_STR = "BLK"
)
(
    input  wire logic              clk,
    input  wire logic              rst,

    /*
     * Increment inputs
     */
    input  wire logic [INC_W-1:0]  stat_inc[CNT],
    input  wire logic              stat_valid[CNT] = '{CNT{1'b1}},
    input  wire logic [8*8-1:0]    stat_str[CNT] = '{CNT{'0}},

    /*
     * Statistics increment output
     */
    taxi_axis_if.src               m_axis_stat,

    /*
     * Control inputs
     */
    input  wire logic              gate = 1'b1,
    input  wire logic              update = 1'b0
);

// check configuration
if (STR_EN) begin
    if (!m_axis_stat.USER_EN)
        $fatal(0, "Error: statistics strings requires tuser (instance %m)");
    if (m_axis_stat.DATA_W < 16)
        $fatal(0, "Error: statistics strings requires tdata width of at least 16 (instance %m)");
end

if (ID_BASE+CNT > 2**m_axis_stat.ID_W)
    $fatal(0, "Error: insufficient tid width (instance %m)");

localparam STAT_INC_W = m_axis_stat.DATA_W;
localparam STAT_ID_W = m_axis_stat.ID_W;

localparam CNT_W = $clog2(CNT);
localparam PERIOD_CNT_W = $clog2(UPDATE_PERIOD+1);
localparam ACC_W = INC_W+CNT_W+1;

typedef enum logic [0:0] {
    STATE_READ,
    STATE_WRITE
} state_t;

state_t state_reg = STATE_READ, state_next;

logic [STAT_INC_W-1:0] m_axis_stat_tdata_reg = '0, m_axis_stat_tdata_next;
logic [STAT_ID_W-1:0] m_axis_stat_tid_reg = '0, m_axis_stat_tid_next;
logic m_axis_stat_tvalid_reg = 1'b0, m_axis_stat_tvalid_next;
logic m_axis_stat_tuser_reg = 1'b0, m_axis_stat_tuser_next;

logic [CNT_W-1:0] count_reg = '0, count_next;
logic [PERIOD_CNT_W-1:0] update_period_reg = PERIOD_CNT_W'(UPDATE_PERIOD), update_period_next;
logic zero_reg = 1'b1, zero_next;
logic update_req_reg = 1'b0, update_req_next;
logic update_reg = 1'b0, update_next;
logic [CNT-1:0] update_shift_reg = '0, update_shift_next;
logic [ACC_W-1:0] ch_reg = '0, ch_next;

function automatic [8*6-1:0] pack_str(logic [8*8-1:0] str);
    // determine length
    integer j = 0;
    for (integer i = 0; i < 8; i = i + 1) begin
        if (str[i*8 +: 8] != 0) begin
            j = i;
        end
    end

    // convert to 6 bit and pack
    pack_str = '0;
    for (integer i = 0; i < 8 && i <= j; i = i + 1) begin
        pack_str[i*6 +: 6] = {str[8*(j-i) + 6], str[8*(j-i) +: 5]};
    end
endfunction

logic [3:0][11:0] prefix_str_rom = pack_str(PREFIX_STR);
logic [CNT*4-1:0][11:0] str_rom;
logic [CNT_W-1:0] str_sel_reg = '0, str_sel_next;
logic str_prfx_reg = 1'b0, str_prfx_next;
logic [1:0] str_ptr_reg = '0, str_ptr_next;
logic str_update_reg = 1'b0, str_update_next;

for (genvar n = 0; n < CNT; n = n + 1) begin
    assign str_rom[n*4 +: 4] = pack_str(stat_str[n]);
end

wire [ACC_W-1:0] acc_int[CNT];
logic [CNT-1:0] acc_clear;

(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic [STAT_INC_W-1:0] mem_reg[CNT];

logic [STAT_INC_W-1:0] mem_rd_data_reg = '0;

logic mem_rd_en;
logic mem_wr_en;
logic [STAT_INC_W-1:0] mem_wr_data;

assign m_axis_stat.tdata = m_axis_stat_tdata_reg;
assign m_axis_stat.tkeep = 1'b1;
assign m_axis_stat.tstrb = m_axis_stat.tkeep;
assign m_axis_stat.tvalid = m_axis_stat_tvalid_reg;
assign m_axis_stat.tlast = 1'b1;
assign m_axis_stat.tid = m_axis_stat_tid_reg;
assign m_axis_stat.tdest = '0;
assign m_axis_stat.tuser = STR_EN ? m_axis_stat_tuser_reg : '0;

for (genvar n = 0; n < CNT; n = n + 1) begin : ch
    logic [ACC_W-1:0] acc_reg = '0;

    assign acc_int[n] = acc_reg;

    always_ff @(posedge clk) begin
        if (acc_clear[n]) begin
            if (stat_valid[n] && gate) begin
                acc_reg <= ACC_W'(stat_inc[n]);
            end else begin
                acc_reg <= '0;
            end
        end else begin
            if (stat_valid[n] && gate) begin
                acc_reg <= acc_reg + ACC_W'(stat_inc[n]);
            end
        end

        if (rst) begin
            acc_reg <= '0;
        end
    end
end

always_comb begin
    state_next = STATE_READ;

    m_axis_stat_tdata_next = m_axis_stat_tdata_reg;
    m_axis_stat_tid_next = m_axis_stat_tid_reg;
    m_axis_stat_tvalid_next = m_axis_stat_tvalid_reg && !m_axis_stat.tready;
    m_axis_stat_tuser_next = m_axis_stat_tuser_reg;

    count_next = count_reg;
    update_period_next = update_period_reg;
    zero_next = zero_reg;
    update_req_next = update_req_reg;
    update_next = update_reg;
    update_shift_next = update_shift_reg;
    ch_next = ch_reg;

    str_sel_next = str_sel_reg;
    str_prfx_next = str_prfx_reg;
    str_ptr_next = str_ptr_reg;
    str_update_next = str_update_reg;

    acc_clear = '0;

    mem_rd_en = 1'b0;
    mem_wr_en = 1'b0;
    mem_wr_data = mem_rd_data_reg + STAT_INC_W'(ch_reg);

    if (!m_axis_stat_tvalid_reg) begin
        m_axis_stat_tdata_next = mem_rd_data_reg + STAT_INC_W'(ch_reg);
        m_axis_stat_tid_next = STAT_ID_W'(count_reg+ID_BASE);
    end

    case (state_reg)
        STATE_READ: begin
            acc_clear[count_reg] = 1'b1;
            ch_next = acc_int[count_reg];
            mem_rd_en = 1'b1;
            state_next = STATE_WRITE;
        end
        STATE_WRITE: begin
            mem_wr_en = 1'b1;
            update_shift_next = {update_reg || update_shift_reg[0], update_shift_reg[CNT-1:1]};
            if (zero_reg) begin
                mem_wr_data = STAT_INC_W'(ch_reg);
            end else if (!m_axis_stat_tvalid_reg && (update_reg || update_shift_reg[0])) begin
                update_shift_next[CNT-1] = 1'b0;
                mem_wr_data = '0;
                m_axis_stat_tdata_next = mem_rd_data_reg + STAT_INC_W'(ch_reg);
                m_axis_stat_tid_next = STAT_ID_W'(count_reg+ID_BASE);
                m_axis_stat_tvalid_next = mem_rd_data_reg != 0 || ch_reg != 0;
                m_axis_stat_tuser_next = 1'b0;
            end else begin
                mem_wr_data = mem_rd_data_reg + STAT_INC_W'(ch_reg);

                if (STR_EN && !m_axis_stat_tvalid_reg && str_update_reg && count_reg == str_sel_reg) begin
                    str_update_next = 1'b0;
                    m_axis_stat_tdata_next[15:4] = str_prfx_reg ? str_rom[{str_sel_reg, str_ptr_reg}] : prefix_str_rom[str_ptr_reg];
                    m_axis_stat_tdata_next[3:0] = {1'b0, str_prfx_reg, str_ptr_reg};
                    m_axis_stat_tid_next = STAT_ID_W'(count_reg+ID_BASE);
                    m_axis_stat_tvalid_next = 1'b1;
                    m_axis_stat_tuser_next = 1'b1;
                    str_ptr_next = str_ptr_reg + 1;
                    if (str_ptr_reg == 2'b11) begin
                        str_prfx_next = !str_prfx_reg;
                        if (str_prfx_reg) begin
                            str_sel_next = str_sel_reg + 1;
                        end
                    end
                end
            end

            if (count_reg == CNT_W'(CNT-1)) begin
                zero_next = 1'b0;
                update_req_next = 1'b0;
                update_next = update_req_reg;
                if (update_req_reg) begin
                    str_update_next = 1'b1;
                end
                count_next = '0;
            end else begin
                count_next = count_reg + 1;
            end

            state_next = STATE_READ;
        end
    endcase

    if (update_period_reg == 0 || update) begin
        update_req_next = 1'b1;
        update_period_next = PERIOD_CNT_W'(UPDATE_PERIOD);
    end else begin
        update_period_next = update_period_reg - 1;
    end
end

always_ff @(posedge clk) begin
    state_reg <= state_next;

    m_axis_stat_tdata_reg <= m_axis_stat_tdata_next;
    m_axis_stat_tid_reg <= m_axis_stat_tid_next;
    m_axis_stat_tvalid_reg <= m_axis_stat_tvalid_next;
    m_axis_stat_tuser_reg <= m_axis_stat_tuser_next;

    count_reg <= count_next;
    update_period_reg <= update_period_next;
    zero_reg <= zero_next;
    update_req_reg <= update_req_next;
    update_reg <= update_next;
    update_shift_reg <= update_shift_next;
    ch_reg <= ch_next;

    str_sel_reg <= str_sel_next;
    str_prfx_reg <= str_prfx_next;
    str_ptr_reg <= str_ptr_next;
    str_update_reg <= str_update_next;

    if (mem_wr_en) begin
        mem_reg[count_reg] <= mem_wr_data;
    end else if (mem_rd_en) begin
        mem_rd_data_reg <= mem_reg[count_reg];
    end

    if (rst) begin
        state_reg <= STATE_READ;
        m_axis_stat_tvalid_reg <= 1'b0;
        count_reg <= '0;
        update_period_reg <= PERIOD_CNT_W'(UPDATE_PERIOD);
        zero_reg <= 1'b1;
        update_req_reg <= 1'b0;
        update_reg <= 1'b0;

        str_sel_reg <= '0;
        str_prfx_reg <= 1'b0;
        str_ptr_reg <= '0;
        str_update_reg <= 1'b0;
    end
end

endmodule

`resetall
