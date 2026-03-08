// SPDX-License-Identifier: CERN-OHL-S-2.0
/*

Copyright (c) 2015-2025 FPGA Ninja, LLC

Authors:
- Alex Forencich

*/

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * PTP clock module
 */
module taxi_ptp_clock #
(
    parameter PERIOD_NS_W = 4,
    parameter OFFSET_NS_W = 4,
    parameter FNS_W = 16,
    parameter PERIOD_NS_NUM = 32,
    parameter PERIOD_NS_DENOM = 5,
    parameter PIPELINE_OUTPUT = 0
)
(
    input  wire logic                    clk,
    input  wire logic                    rst,

    /*
     * Timestamp inputs for synchronization
     */
    input  wire logic [95:0]             input_ts_tod,
    input  wire logic                    input_ts_tod_valid,
    input  wire logic [63:0]             input_ts_rel,
    input  wire logic                    input_ts_rel_valid,

    /*
     * Period adjustment
     */
    input  wire logic [PERIOD_NS_W-1:0]  input_period_ns,
    input  wire logic [FNS_W-1:0]        input_period_fns,
    input  wire logic                    input_period_valid,

    /*
     * Offset adjustment
     */
    input  wire logic [OFFSET_NS_W-1:0]  input_adj_ns,
    input  wire logic [FNS_W-1:0]        input_adj_fns,
    input  wire logic [15:0]             input_adj_count,
    input  wire logic                    input_adj_valid,
    output wire logic                    input_adj_active,

    /*
     * Drift adjustment
     */
    input  wire logic [FNS_W-1:0]        input_drift_num,
    input  wire logic [15:0]             input_drift_denom,
    input  wire logic                    input_drift_valid,

    /*
     * Timestamp outputs
     */
    output wire logic [95:0]             output_ts_tod,
    output wire logic                    output_ts_tod_step,
    output wire logic [63:0]             output_ts_rel,
    output wire logic                    output_ts_rel_step,

    /*
     * PPS output
     */
    output wire logic                    output_pps,
    output wire logic                    output_pps_str
);

localparam PERIOD_NS = PERIOD_NS_NUM / PERIOD_NS_DENOM;
localparam PERIOD_NS_REM = PERIOD_NS_NUM - PERIOD_NS*PERIOD_NS_DENOM;
localparam PERIOD_FNS = (PERIOD_NS_REM * {32'd1, {FNS_W{1'b0}}}) / (32+FNS_W)'(PERIOD_NS_DENOM);
localparam PERIOD_FNS_REM = (PERIOD_NS_REM * {32'd1, {FNS_W{1'b0}}}) - PERIOD_FNS*PERIOD_NS_DENOM;

localparam INC_NS_W = $clog2(2**PERIOD_NS_W + 2**OFFSET_NS_W);

localparam [30:0] NS_PER_S = 31'd1_000_000_000;

logic [PERIOD_NS_W-1:0] period_ns_reg = PERIOD_NS_W'(PERIOD_NS);
logic [FNS_W-1:0] period_fns_reg = FNS_W'(PERIOD_FNS);

logic [OFFSET_NS_W-1:0] adj_ns_reg = '0;
logic [FNS_W-1:0] adj_fns_reg = '0;
logic [15:0] adj_count_reg = '0;
logic adj_active_reg = '0;

logic [FNS_W-1:0] drift_num_reg = FNS_W'(PERIOD_FNS_REM);
logic [15:0] drift_denom_reg = 16'(PERIOD_NS_DENOM);
logic [15:0] drift_cnt_reg = '0;
logic drift_apply_reg = 1'b0;

logic [INC_NS_W-1:0] ts_inc_ns_reg = '0;
logic [FNS_W-1:0] ts_inc_fns_reg = '0;
logic [INC_NS_W-1:0] ts_inc_ns_delay_reg = '0;
logic [FNS_W-1:0] ts_inc_fns_delay_reg = '0;
logic [30:0] ts_inc_ns_ovf_reg = '0;
logic [FNS_W-1:0] ts_inc_fns_ovf_reg = '0;

logic [47:0] ts_tod_s_reg = '0;
logic [29:0] ts_tod_ns_reg = '0;
logic [FNS_W-1:0] ts_tod_fns_reg = '0;
logic [29:0] ts_tod_ns_inc_reg = '0;
logic [FNS_W-1:0] ts_tod_fns_inc_reg = '0;
logic [30:0] ts_tod_ns_ovf_reg = '1;
logic [FNS_W-1:0] ts_tod_fns_ovf_reg = '1;

logic [47:0] ts_rel_ns_reg = '0;
logic [FNS_W-1:0] ts_rel_fns_reg = '0;

logic ts_tod_step_reg = 1'b0;
logic ts_rel_step_reg = 1'b0;

logic [47:0] temp;

logic pps_reg = 0;
logic pps_str_reg = 0;

assign input_adj_active = adj_active_reg;

if (PIPELINE_OUTPUT > 0) begin

    // pipeline
    (* shreg_extract = "no" *)
    logic [95:0]  output_ts_tod_reg[0:PIPELINE_OUTPUT-1] = '{default: '0};
    (* shreg_extract = "no" *)
    logic         output_ts_tod_step_reg[0:PIPELINE_OUTPUT-1] = '{default: '0};
    (* shreg_extract = "no" *)
    logic [63:0]  output_ts_rel_reg[0:PIPELINE_OUTPUT-1] = '{default: '0};
    (* shreg_extract = "no" *)
    logic         output_ts_rel_step_reg[0:PIPELINE_OUTPUT-1] = '{default: '0};
    (* shreg_extract = "no" *)
    logic         output_pps_reg[0:PIPELINE_OUTPUT-1] = '{default: '0};
    (* shreg_extract = "no" *)
    logic         output_pps_str_reg[0:PIPELINE_OUTPUT-1] = '{default: '0};

    assign output_ts_tod = output_ts_tod_reg[PIPELINE_OUTPUT-1];
    assign output_ts_tod_step = output_ts_tod_step_reg[PIPELINE_OUTPUT-1];

    assign output_ts_rel = output_ts_rel_reg[PIPELINE_OUTPUT-1];
    assign output_ts_rel_step = output_ts_rel_step_reg[PIPELINE_OUTPUT-1];

    assign output_pps = output_pps_reg[PIPELINE_OUTPUT-1];
    assign output_pps_str = output_pps_str_reg[PIPELINE_OUTPUT-1];

    always_ff @(posedge clk) begin
        output_ts_tod_reg[0][95:48] <= ts_tod_s_reg;
        output_ts_tod_reg[0][47:46] <= 2'b00;
        output_ts_tod_reg[0][45:16] <= ts_tod_ns_reg;
        output_ts_tod_reg[0][15:0]  <= {ts_tod_fns_reg, 16'd0} >> FNS_W;
        output_ts_tod_step_reg[0] <= ts_tod_step_reg;

        output_ts_rel_reg[0][63:16] <= ts_rel_ns_reg;
        output_ts_rel_reg[0][15:0]  <= {ts_rel_fns_reg, 16'd0} >> FNS_W;
        output_ts_rel_step_reg[0] <= ts_rel_step_reg;

        output_pps_reg[0] <= pps_reg;
        output_pps_str_reg[0] <= pps_str_reg;

        for (integer i = 0; i < PIPELINE_OUTPUT-1; i = i + 1) begin
            output_ts_tod_reg[i+1] <= output_ts_tod_reg[i];
            output_ts_tod_step_reg[i+1] <= output_ts_tod_step_reg[i];

            output_ts_rel_reg[i+1] <= output_ts_rel_reg[i];
            output_ts_rel_step_reg[i+1] <= output_ts_rel_step_reg[i];

            output_pps_reg[i+1] <= output_pps_reg[i];
            output_pps_str_reg[i+1] <= output_pps_str_reg[i];
        end

        if (rst) begin
            for (integer i = 0; i < PIPELINE_OUTPUT; i = i + 1) begin
                output_ts_tod_reg[i] <= '0;
                output_ts_tod_step_reg[i] <= 1'b0;

                output_ts_rel_reg[i] <= '0;
                output_ts_rel_step_reg[i] <= 1'b0;

                output_pps_reg[i] <= 1'b0;
                output_pps_str_reg[i] <= 1'b0;
            end
        end
    end

end else begin

    assign output_ts_tod[95:48] = ts_tod_s_reg;
    assign output_ts_tod[47:46] = 2'b00;
    assign output_ts_tod[45:16] = ts_tod_ns_reg;
    assign output_ts_tod[15:0]  = 16'({ts_tod_fns_reg, 16'd0} >> FNS_W);
    assign output_ts_tod_step = ts_tod_step_reg;

    assign output_ts_rel[63:16] = ts_rel_ns_reg;
    assign output_ts_rel[15:0]  = 16'({ts_rel_fns_reg, 16'd0} >> FNS_W);
    assign output_ts_rel_step = ts_rel_step_reg;

    assign output_pps = pps_reg;
    assign output_pps_str = pps_str_reg;

end

always_ff @(posedge clk) begin
    ts_tod_step_reg <= 1'b0;
    ts_rel_step_reg <= 1'b0;
    drift_apply_reg <= 1'b0;
    pps_reg <= 1'b0;

    // latch parameters
    if (input_period_valid) begin
        period_ns_reg <= input_period_ns;
        period_fns_reg <= input_period_fns;
    end

    if (input_adj_valid) begin
        adj_ns_reg <= input_adj_ns;
        adj_fns_reg <= input_adj_fns;
        adj_count_reg <= input_adj_count;
    end

    if (input_drift_valid) begin
        drift_num_reg <= input_drift_num;
        drift_denom_reg <= input_drift_denom;
    end

    // timestamp increment calculation
    {ts_inc_ns_reg, ts_inc_fns_reg} <= $signed({1'b0, period_ns_reg, period_fns_reg}) +
        (adj_active_reg ? (INC_NS_W+FNS_W)'($signed({adj_ns_reg, adj_fns_reg})) : '0) +
        (drift_apply_reg ? (INC_NS_W+FNS_W)'($signed(drift_num_reg)) : '0);

    // offset adjust counter
    if (adj_count_reg != 0) begin
        adj_count_reg <= adj_count_reg - 1;
        adj_active_reg <= 1;
        ts_tod_step_reg <= 1;
        ts_rel_step_reg <= 1;
    end else begin
        adj_active_reg <= 0;
    end

    // drift counter
    if (drift_cnt_reg != 0) begin
        drift_cnt_reg <= drift_cnt_reg - 1;
    end else begin
        drift_cnt_reg <= drift_denom_reg-1;
        drift_apply_reg <= 1'b1;
    end

    // 96 bit timestamp
    {ts_inc_ns_delay_reg, ts_inc_fns_delay_reg} <= {ts_inc_ns_reg, ts_inc_fns_reg};
    {ts_inc_ns_ovf_reg, ts_inc_fns_ovf_reg} <= {NS_PER_S, {FNS_W{1'b0}}} - (31+FNS_W)'({ts_inc_ns_reg, ts_inc_fns_reg});

    {ts_tod_ns_inc_reg, ts_tod_fns_inc_reg} <= {ts_tod_ns_inc_reg, ts_tod_fns_inc_reg} + (30+FNS_W)'({ts_inc_ns_delay_reg, ts_inc_fns_delay_reg});
    {ts_tod_ns_ovf_reg, ts_tod_fns_ovf_reg} <= {ts_tod_ns_inc_reg, ts_tod_fns_inc_reg} - (31+FNS_W)'({ts_inc_ns_ovf_reg[29:0], ts_inc_fns_ovf_reg});
    {ts_tod_ns_reg, ts_tod_fns_reg} <= {ts_tod_ns_inc_reg, ts_tod_fns_inc_reg};

    if (ts_tod_ns_reg[29]) begin
        pps_str_reg <= 1'b0;
    end

    if (!ts_tod_ns_ovf_reg[30]) begin
        // if the overflow lookahead did not borrow, one second has elapsed
        // increment seconds field, pre-compute normal increment, force overflow lookahead borrow bit set
        {ts_tod_ns_inc_reg, ts_tod_fns_inc_reg} <= (30+FNS_W)'({ts_tod_ns_ovf_reg[29:0], ts_tod_fns_ovf_reg} + {ts_inc_ns_delay_reg, ts_inc_fns_delay_reg});
        ts_tod_ns_ovf_reg[30] <= 1'b1;
        {ts_tod_ns_reg, ts_tod_fns_reg} <= {ts_tod_ns_ovf_reg[29:0], ts_tod_fns_ovf_reg};
        ts_tod_s_reg <= ts_tod_s_reg + 1;
        pps_reg <= 1'b1;
        pps_str_reg <= 1'b1;
    end

    if (input_ts_tod_valid) begin
        // load timestamp
        ts_tod_s_reg <= input_ts_tod[95:48];
        ts_tod_ns_reg <= input_ts_tod[45:16];
        ts_tod_ns_inc_reg <= input_ts_tod[45:16];
        ts_tod_ns_ovf_reg[30] <= 1'b1;
        ts_tod_fns_reg <= FNS_W > 16 ? input_ts_tod[15:0] << (FNS_W-16) : input_ts_tod[15:0] >> (16-FNS_W);
        ts_tod_fns_inc_reg <= FNS_W > 16 ? input_ts_tod[15:0] << (FNS_W-16) : input_ts_tod[15:0] >> (16-FNS_W);
        ts_tod_step_reg <= 1;
    end

    // 64 bit timestamp
    {ts_rel_ns_reg, ts_rel_fns_reg} <= {ts_rel_ns_reg, ts_rel_fns_reg} + (48+FNS_W)'({ts_inc_ns_reg, ts_inc_fns_reg});

    if (input_ts_rel_valid) begin
        // load timestamp
        {ts_rel_ns_reg, ts_rel_fns_reg} <= input_ts_rel;
        ts_rel_step_reg <= 1;
    end

    if (rst) begin
        period_ns_reg <= PERIOD_NS_W'(PERIOD_NS);
        period_fns_reg <= FNS_W'(PERIOD_FNS);

        adj_ns_reg <= '0;
        adj_fns_reg <= '0;
        adj_count_reg <= '0;
        adj_active_reg <= '0;

        drift_num_reg <= FNS_W'(PERIOD_FNS_REM);
        drift_denom_reg <= 16'(PERIOD_NS_DENOM);
        drift_cnt_reg <= '0;
        drift_apply_reg <= 1'b0;

        ts_tod_s_reg <= '0;
        ts_tod_ns_reg <= '0;
        ts_tod_fns_reg <= '0;
        ts_tod_ns_inc_reg <= '0;
        ts_tod_fns_inc_reg <= '0;
        ts_tod_ns_ovf_reg[30] <= 1'b1;
        ts_tod_step_reg <= '0;

        ts_rel_ns_reg <= '0;
        ts_rel_fns_reg <= '0;
        ts_rel_step_reg <= '0;

        pps_reg <= '0;
        pps_str_reg <= '0;
    end
end

endmodule

`resetall
