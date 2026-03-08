// SPDX-License-Identifier: CERN-OHL-S-2.0
/*

Copyright (c) 2019-2025 FPGA Ninja, LLC

Authors:
- Alex Forencich

*/

`resetall
`timescale 1ns / 1fs
`default_nettype none

/*
 * PTP clock CDC (clock domain crossing) module
 */
module taxi_ptp_clock_cdc #
(
    parameter TS_W = 96,
    parameter NS_W = 4,
    parameter LOG_RATE = 3,
    parameter PIPELINE_OUTPUT = 0
)
(
    input  wire logic             input_clk,
    input  wire logic             input_rst,
    input  wire logic             output_clk,
    input  wire logic             output_rst,
    input  wire logic             sample_clk,

    /*
     * Timestamp inputs from source PTP clock
     */
    input  wire logic [TS_W-1:0]  input_ts,
    input  wire logic             input_ts_step,

    /*
     * Timestamp outputs
     */
    output wire logic [TS_W-1:0]  output_ts,
    output wire logic             output_ts_step,

    /*
     * PPS output
     */
    output wire logic             output_pps,
    output wire logic             output_pps_str,

    /*
     * Status
     */
    output wire logic             locked
);

// Check configuration
if (TS_W != 64 && TS_W != 96)
    $fatal(0, "Error: Timestamp width must be 64 or 96");

localparam FNS_W = 16;

localparam TS_NS_W = TS_W == 96 ? 30 : 48;
localparam TS_FNS_W = FNS_W > 16 ? 16 : FNS_W;

localparam CMP_FNS_W = 4;

localparam PHASE_CNT_W = LOG_RATE;
localparam PHASE_ACC_W = PHASE_CNT_W+16;

localparam LOG_SAMPLE_SYNC_RATE = LOG_RATE;
localparam SAMPLE_ACC_W = LOG_SAMPLE_SYNC_RATE+2;

localparam LOG_PHASE_ERR_RATE = 4;
localparam PHASE_ERR_ACC_W = LOG_PHASE_ERR_RATE+2;

localparam DEST_SYNC_LOCK_W = 7;
localparam FREQ_LOCK_W = 8;
localparam PTP_LOCK_W = 8;

localparam TIME_ERR_INT_W = NS_W+FNS_W;

localparam [30:0] NS_PER_S = 31'd1_000_000_000;

logic [NS_W+FNS_W-1:0] period_ns_reg = '0, period_ns_next;
logic [NS_W+FNS_W-1:0] period_ns_delay_reg = '0, period_ns_delay_next;
logic [31+FNS_W-1:0] period_ns_ovf_reg = '0, period_ns_ovf_next;

logic [47:0] src_ts_s_capt_reg = '0;
logic [TS_NS_W+CMP_FNS_W-1:0] src_ts_ns_capt_reg = '0;
logic src_ts_step_capt_reg = '0;

logic [47:0] dest_ts_s_capt_reg = '0;
logic [TS_NS_W+CMP_FNS_W-1:0] dest_ts_ns_capt_reg = '0;

logic [47:0] src_ts_s_sync_reg = '0;
logic [TS_NS_W+CMP_FNS_W-1:0] src_ts_ns_sync_reg = '0;
logic src_ts_step_sync_reg = '0;

logic [47:0] ts_s_reg = '0, ts_s_next;
logic [TS_NS_W+FNS_W-1:0] ts_ns_reg = '0, ts_ns_next;
logic [TS_NS_W+FNS_W-1:0] ts_ns_inc_reg = '0, ts_ns_inc_next;
logic [TS_NS_W+FNS_W+1-1:0] ts_ns_ovf_reg = '1, ts_ns_ovf_next;

logic ts_step_reg = 1'b0, ts_step_next;

logic pps_reg = 1'b0;
logic pps_str_reg = 1'b0;

logic [47:0] ts_s_pipe_reg[0:PIPELINE_OUTPUT-1] = '{default: '0};
logic [TS_NS_W+CMP_FNS_W-1:0] ts_ns_pipe_reg[0:PIPELINE_OUTPUT-1] = '{default: '0};
logic ts_step_pipe_reg[0:PIPELINE_OUTPUT-1] = '{default: '0};
logic pps_pipe_reg[0:PIPELINE_OUTPUT-1] = '{default: '0};

logic [PHASE_CNT_W-1:0] src_phase_reg = '0;
logic [PHASE_ACC_W-1:0] dest_phase_reg = '0, dest_phase_next;
logic [PHASE_ACC_W-1:0] dest_phase_inc_reg = '0, dest_phase_inc_next;

logic src_sync_reg = 1'b0;
logic src_update_reg = 1'b0;
logic src_phase_sync_reg = 1'b0;
logic dest_sync_reg = 1'b0;
logic dest_update_reg = 1'b0, dest_update_next;
logic dest_phase_sync_reg = 1'b0;

logic src_sync_sync1_reg = 1'b0;
logic src_sync_sync2_reg = 1'b0;
logic src_sync_sync3_reg = 1'b0;
logic src_phase_sync_sync1_reg = 1'b0;
logic src_phase_sync_sync2_reg = 1'b0;
logic src_phase_sync_sync3_reg = 1'b0;
logic dest_phase_sync_sync1_reg = 1'b0;
logic dest_phase_sync_sync2_reg = 1'b0;
logic dest_phase_sync_sync3_reg = 1'b0;

logic src_sync_sample_sync1_reg = 1'b0;
logic src_sync_sample_sync2_reg = 1'b0;
logic src_sync_sample_sync3_reg = 1'b0;
logic dest_sync_sample_sync1_reg = 1'b0;
logic dest_sync_sample_sync2_reg = 1'b0;
logic dest_sync_sample_sync3_reg = 1'b0;

logic [SAMPLE_ACC_W-1:0] sample_acc_reg = '0;
logic [SAMPLE_ACC_W-1:0] sample_acc_out_reg = '0;
logic [LOG_SAMPLE_SYNC_RATE-1:0] sample_cnt_reg = '0;
logic sample_update_reg = 1'b0;
logic sample_update_sync1_reg = 1'b0;
logic sample_update_sync2_reg = 1'b0;
logic sample_update_sync3_reg = 1'b0;

if (PIPELINE_OUTPUT > 0) begin

    // pipeline
    (* shreg_extract = "no" *)
    logic [TS_W-1:0]  output_ts_reg[0:PIPELINE_OUTPUT-1] = '{default: '0};
    (* shreg_extract = "no" *)
    logic             output_ts_step_reg[0:PIPELINE_OUTPUT-1] = '{default: '0};
    (* shreg_extract = "no" *)
    logic             output_pps_reg[0:PIPELINE_OUTPUT-1] = '{default: '0};
    (* shreg_extract = "no" *)
    logic             output_pps_str_reg[0:PIPELINE_OUTPUT-1] = '{default: '0};

    assign output_ts = output_ts_reg[PIPELINE_OUTPUT-1];
    assign output_ts_step = output_ts_step_reg[PIPELINE_OUTPUT-1];
    assign output_pps = output_pps_reg[PIPELINE_OUTPUT-1];
    assign output_pps_str = output_pps_str_reg[PIPELINE_OUTPUT-1];

    always_ff @(posedge output_clk) begin
        if (TS_W == 96) begin
            output_ts_reg[0][95:48] <= ts_s_reg;
            output_ts_reg[0][47:46] <= 2'b00;
            output_ts_reg[0][45:0]  <= 46'({ts_ns_reg, 16'd0} >> FNS_W);
        end else if (TS_W == 64) begin
            output_ts_reg[0]  <= 64'({ts_ns_reg, 16'd0} >> FNS_W);
        end

        output_ts_step_reg[0] <= ts_step_reg;
        output_pps_reg[0] <= pps_reg;
        output_pps_str_reg[0] <= pps_str_reg;

        for (integer i = 0; i < PIPELINE_OUTPUT-1; i = i + 1) begin
            output_ts_reg[i+1] <= output_ts_reg[i];
            output_ts_step_reg[i+1] <= output_ts_step_reg[i];
            output_pps_reg[i+1] <= output_pps_reg[i];
            output_pps_str_reg[i+1] <= output_pps_str_reg[i];
        end

        if (output_rst) begin
            for (integer i = 0; i < PIPELINE_OUTPUT; i = i + 1) begin
                output_ts_reg[i] <= 0;
                output_ts_step_reg[i] <= 1'b0;
                output_pps_reg[i] <= 1'b0;
                output_pps_str_reg[i] <= 1'b0;
            end
        end
    end

end else begin

    if (TS_W == 96) begin
        assign output_ts[95:48] = ts_s_reg;
        assign output_ts[47:46] = 2'b00;
        assign output_ts[45:0]  = 46'({ts_ns_reg, 16'd0} >> FNS_W);
    end else if (TS_W == 64) begin
        assign output_ts = 64'({ts_ns_reg, 16'd0} >> FNS_W);
    end

    assign output_ts_step = ts_step_reg;

    assign output_pps = pps_reg;
    assign output_pps_str = pps_str_reg;

end

// source PTP clock capture and sync logic
logic input_ts_step_reg = 1'b0;

always_ff @(posedge input_clk) begin
    input_ts_step_reg <= input_ts_step || input_ts_step_reg;

    src_phase_sync_reg <= input_ts[16+8];

    {src_update_reg, src_phase_reg} <= src_phase_reg+1;

    if (src_update_reg) begin
        // capture source TS
        if (TS_W == 96) begin
            src_ts_s_capt_reg <= 48'(input_ts >> 48);
            src_ts_ns_capt_reg <= (TS_NS_W+CMP_FNS_W)'(input_ts[45:0] >> (16-CMP_FNS_W));
        end else begin
            src_ts_ns_capt_reg <= (TS_NS_W+CMP_FNS_W)'(input_ts >> (16-CMP_FNS_W));
        end
        src_ts_step_capt_reg <= input_ts_step || input_ts_step_reg;
        input_ts_step_reg <= 1'b0;
        src_sync_reg <= !src_sync_reg;
    end

    if (input_rst) begin
        input_ts_step_reg <= 1'b0;

        src_phase_reg <= '0;
        src_sync_reg <= 1'b0;
        src_update_reg <= 1'b0;
    end
end

// CDC logic
always_ff @(posedge output_clk) begin
    src_sync_sync1_reg <= src_sync_reg;
    src_sync_sync2_reg <= src_sync_sync1_reg;
    src_sync_sync3_reg <= src_sync_sync2_reg;
    src_phase_sync_sync1_reg <= src_phase_sync_reg;
    src_phase_sync_sync2_reg <= src_phase_sync_sync1_reg;
    src_phase_sync_sync3_reg <= src_phase_sync_sync2_reg;
    dest_phase_sync_sync1_reg <= dest_phase_sync_reg;
    dest_phase_sync_sync2_reg <= dest_phase_sync_sync1_reg;
    dest_phase_sync_sync3_reg <= dest_phase_sync_sync2_reg;
end

always_ff @(posedge sample_clk) begin
    src_sync_sample_sync1_reg <= src_sync_reg;
    src_sync_sample_sync2_reg <= src_sync_sample_sync1_reg;
    src_sync_sample_sync3_reg <= src_sync_sample_sync2_reg;
    dest_sync_sample_sync1_reg <= dest_sync_reg;
    dest_sync_sample_sync2_reg <= dest_sync_sample_sync1_reg;
    dest_sync_sample_sync3_reg <= dest_sync_sample_sync2_reg;
end

logic edge_1_reg = 1'b0;
logic edge_2_reg = 1'b0;

logic [3:0] active_reg = '0;

always_ff @(posedge sample_clk) begin
    // phase and frequency detector
    if (dest_sync_sample_sync2_reg && !dest_sync_sample_sync3_reg) begin
        if (src_sync_sample_sync2_reg && !src_sync_sample_sync3_reg) begin
            edge_1_reg <= 1'b0;
            edge_2_reg <= 1'b0;
        end else begin
            edge_1_reg <= !edge_2_reg;
            edge_2_reg <= 1'b0;
        end
    end else if (src_sync_sample_sync2_reg && !src_sync_sample_sync3_reg) begin
        edge_1_reg <= 1'b0;
        edge_2_reg <= !edge_1_reg;
    end

    // accumulator
    sample_acc_reg <= $signed(sample_acc_reg) + SAMPLE_ACC_W'($signed({1'b0, edge_2_reg})) - SAMPLE_ACC_W'($signed({1'b0, edge_1_reg}));

    sample_cnt_reg <= sample_cnt_reg + 1;

    if (src_sync_sample_sync2_reg && !src_sync_sample_sync3_reg) begin
        active_reg[0] <= 1'b1;
    end

    if (sample_cnt_reg == 0) begin
        active_reg <= {active_reg[2:0], src_sync_sample_sync2_reg && !src_sync_sample_sync3_reg};
        sample_acc_reg <= SAMPLE_ACC_W'($signed({1'b0, edge_2_reg}) - $signed({1'b0, edge_1_reg}));
        sample_acc_out_reg <= sample_acc_reg;
        if (active_reg != 0) begin
            sample_update_reg <= !sample_update_reg;
        end
    end
end

always_ff @(posedge output_clk) begin
    sample_update_sync1_reg <= sample_update_reg;
    sample_update_sync2_reg <= sample_update_sync1_reg;
    sample_update_sync3_reg <= sample_update_sync2_reg;
end

logic [SAMPLE_ACC_W-1:0] sample_acc_sync_reg = '0;
logic sample_acc_sync_valid_reg = '0;

logic [PHASE_ACC_W-1:0] dest_err_int_reg = '0, dest_err_int_next;
logic [1:0] dest_ovf;

logic [DEST_SYNC_LOCK_W-1:0] dest_sync_lock_count_reg = '0, dest_sync_lock_count_next;
logic dest_sync_locked_reg = 1'b0, dest_sync_locked_next;

always_comb begin
    {dest_update_next, dest_phase_next} = dest_phase_reg + dest_phase_inc_reg;
    dest_phase_inc_next = dest_phase_inc_reg;

    dest_err_int_next = dest_err_int_reg;

    dest_sync_lock_count_next = dest_sync_lock_count_reg;
    dest_sync_locked_next = dest_sync_locked_reg;

    dest_ovf = 0;

    if (sample_acc_sync_valid_reg) begin
        // updated sampled dest_phase error

        // time integral of error
        if (dest_sync_locked_reg) begin
            {dest_ovf, dest_err_int_next} = $signed({1'b0, dest_err_int_reg}) + (PHASE_ACC_W+2)'($signed(sample_acc_sync_reg));
        end else begin
            {dest_ovf, dest_err_int_next} = $signed({1'b0, dest_err_int_reg}) + (PHASE_ACC_W+2)'($signed(sample_acc_sync_reg) * 2**6);
        end

        // saturate
        if (dest_ovf[1]) begin
            // sign bit set indicating underflow across zero; saturate to zero
            dest_err_int_next = '0;
        end else if (dest_ovf[0]) begin
            // sign bit clear but carry bit set indicating overflow; saturate to all 1
            dest_err_int_next = '1;
        end

        // compute output
        if (dest_sync_locked_reg) begin
            {dest_ovf, dest_phase_inc_next} = $signed({1'b0, dest_err_int_reg}) + ($signed(sample_acc_sync_reg) * 2**4);
        end else begin
            {dest_ovf, dest_phase_inc_next} = $signed({1'b0, dest_err_int_reg}) + ($signed(sample_acc_sync_reg) * 2**10);
        end

        // saturate
        if (dest_ovf[1]) begin
            // sign bit set indicating underflow across zero; saturate to zero
            dest_phase_inc_next = '0;
        end else if (dest_ovf[0]) begin
            // sign bit clear but carry bit set indicating overflow; saturate to all 1
            dest_phase_inc_next = '1;
        end

        // locked status
        if ($signed(sample_acc_sync_reg[SAMPLE_ACC_W-1:2]) == 0 || $signed(sample_acc_sync_reg[SAMPLE_ACC_W-1:1]) == -1) begin
            if (&dest_sync_lock_count_reg) begin
                dest_sync_locked_next = 1'b1;
            end else begin
                dest_sync_lock_count_next = dest_sync_lock_count_reg + 1;
            end
        end else begin
            dest_sync_lock_count_next = '0;
            dest_sync_locked_next = 1'b0;
        end
    end
end

logic [PHASE_ERR_ACC_W-1:0] phase_err_acc_reg = '0;
logic [PHASE_ERR_ACC_W-1:0] phase_err_out_reg = '0;
logic [LOG_PHASE_ERR_RATE-1:0] phase_err_cnt_reg = '0;
logic phase_err_out_valid_reg = '0;

logic phase_edge_1_reg = 1'b0;
logic phase_edge_2_reg = 1'b0;

logic [5:0] phase_active_reg = '0;

logic ts_sync_valid_reg = 1'b0;

always_ff @(posedge output_clk) begin
    dest_phase_reg <= dest_phase_next;
    dest_phase_inc_reg <= dest_phase_inc_next;
    dest_update_reg <= dest_update_next;

    sample_acc_sync_valid_reg <= 1'b0;
    if (sample_update_sync2_reg ^ sample_update_sync3_reg) begin
        // latch in synchronized counts from phase detector
        sample_acc_sync_reg <= sample_acc_out_reg;
        sample_acc_sync_valid_reg <= 1'b1;
    end

    if (PIPELINE_OUTPUT > 0) begin
        dest_phase_sync_reg <= ts_ns_pipe_reg[PIPELINE_OUTPUT-1][8+FNS_W];
    end else begin
        dest_phase_sync_reg <= ts_ns_reg[8+FNS_W];
    end

    // phase and frequency detector
    if (dest_phase_sync_sync2_reg && !dest_phase_sync_sync3_reg) begin
        if (src_phase_sync_sync2_reg && !src_phase_sync_sync3_reg) begin
            phase_edge_1_reg <= 1'b0;
            phase_edge_2_reg <= 1'b0;
        end else begin
            phase_edge_1_reg <= !phase_edge_2_reg;
            phase_edge_2_reg <= 1'b0;
        end
    end else if (src_phase_sync_sync2_reg && !src_phase_sync_sync3_reg) begin
        phase_edge_1_reg <= 1'b0;
        phase_edge_2_reg <= !phase_edge_1_reg;
    end

    // accumulator
    phase_err_acc_reg <= $signed(phase_err_acc_reg) + PHASE_ERR_ACC_W'($signed({1'b0, phase_edge_2_reg})) - PHASE_ERR_ACC_W'($signed({1'b0, phase_edge_1_reg}));

    phase_err_cnt_reg <= phase_err_cnt_reg + 1;

    if (src_phase_sync_sync2_reg && !src_phase_sync_sync3_reg) begin
        phase_active_reg[0] <= 1'b1;
    end

    phase_err_out_valid_reg <= 1'b0;
    if (phase_err_cnt_reg == 0) begin
        phase_active_reg <= {phase_active_reg[4:0], src_phase_sync_sync2_reg && !src_phase_sync_sync3_reg};
        phase_err_acc_reg <= PHASE_ERR_ACC_W'($signed({1'b0, phase_edge_2_reg}) - $signed({1'b0, phase_edge_1_reg}));
        phase_err_out_reg <= phase_err_acc_reg;
        if (phase_active_reg != 0) begin
            phase_err_out_valid_reg <= 1'b1;
        end
    end

    if (dest_update_reg) begin
        // capture local TS
        if (PIPELINE_OUTPUT > 0) begin
            dest_ts_s_capt_reg <= ts_s_pipe_reg[PIPELINE_OUTPUT-1];
            dest_ts_ns_capt_reg <= ts_ns_pipe_reg[PIPELINE_OUTPUT-1];
        end else begin
            dest_ts_s_capt_reg <= ts_s_reg;
            dest_ts_ns_capt_reg <= (TS_NS_W+CMP_FNS_W)'(ts_ns_reg >> FNS_W-CMP_FNS_W);
        end

        dest_sync_reg <= !dest_sync_reg;
    end

    ts_sync_valid_reg <= 1'b0;

    if (src_sync_sync2_reg ^ src_sync_sync3_reg) begin
        // store captured source TS
        if (TS_W == 96) begin
            src_ts_s_sync_reg <= src_ts_s_capt_reg;
        end
        src_ts_ns_sync_reg <= src_ts_ns_capt_reg;
        src_ts_step_sync_reg <= src_ts_step_capt_reg;

        ts_sync_valid_reg <= 1'b1;
    end

    dest_err_int_reg <= dest_err_int_next;

    dest_sync_lock_count_reg <= dest_sync_lock_count_next;
    dest_sync_locked_reg <= dest_sync_locked_next;

    if (output_rst) begin
        dest_phase_reg <= '0;
        dest_phase_inc_reg <= '0;
        dest_sync_reg <= 1'b0;
        dest_update_reg <= 1'b0;

        dest_err_int_reg <= '0;

        dest_sync_lock_count_reg <= '0;
        dest_sync_locked_reg <= 1'b0;

        ts_sync_valid_reg <= 1'b0;
    end
end

logic ts_diff_reg = 1'b0, ts_diff_next;
logic ts_diff_valid_reg = 1'b0, ts_diff_valid_next;
logic [3:0] mismatch_cnt_reg = '0, mismatch_cnt_next;
logic load_ts_reg = 1'b0, load_ts_next;

logic [9+CMP_FNS_W-1:0] ts_ns_diff_reg = '0, ts_ns_diff_next;

logic [TIME_ERR_INT_W-1:0] time_err_int_reg = '0, time_err_int_next;

logic [1:0] ptp_ovf;

logic [FREQ_LOCK_W-1:0] freq_lock_count_reg = '0, freq_lock_count_next;
logic freq_locked_reg = 1'b0, freq_locked_next;
logic [PTP_LOCK_W-1:0] ptp_lock_count_reg = '0, ptp_lock_count_next;
logic ptp_locked_reg = 1'b0, ptp_locked_next;

logic gain_sel_reg = '0, gain_sel_next;

assign locked = ptp_locked_reg && freq_locked_reg && dest_sync_locked_reg;

always_comb begin
    period_ns_next = period_ns_reg;

    ts_s_next = ts_s_reg;
    ts_ns_next = ts_ns_reg;
    ts_ns_inc_next = ts_ns_inc_reg;
    ts_ns_ovf_next = ts_ns_ovf_reg;

    ts_step_next = '0;

    ts_diff_next = 1'b0;
    ts_diff_valid_next = 1'b0;
    mismatch_cnt_next = mismatch_cnt_reg;
    load_ts_next = load_ts_reg;

    ts_ns_diff_next = ts_ns_diff_reg;

    time_err_int_next = time_err_int_reg;

    freq_lock_count_next = freq_lock_count_reg;
    freq_locked_next = freq_locked_reg;
    ptp_lock_count_next = ptp_lock_count_reg;
    ptp_locked_next = ptp_locked_reg;

    gain_sel_next = gain_sel_reg;

    // PTP clock
    period_ns_delay_next = period_ns_reg;

    if (TS_W == 96) begin
        // 96 bit timestamp
        ts_ns_inc_next = ts_ns_inc_reg + (TS_NS_W+FNS_W)'(period_ns_delay_reg);
        ts_ns_ovf_next = ts_ns_inc_reg - (TS_NS_W+FNS_W)'(period_ns_ovf_reg);
        ts_ns_next = ts_ns_inc_reg;
        period_ns_ovf_next = (31+FNS_W)'({NS_PER_S, {FNS_W{1'b0}}}) - (31+FNS_W)'(period_ns_reg);

        if (!ts_ns_ovf_reg[30+FNS_W]) begin
            // if the overflow lookahead did not borrow, one second has elapsed
            // increment seconds field, pre-compute normal increment, force overflow lookahead borrow bit set
            ts_ns_inc_next = ts_ns_ovf_reg[TS_NS_W+FNS_W-1:0] + (TS_NS_W+FNS_W)'(period_ns_delay_reg);
            ts_ns_ovf_next[30+FNS_W] = 1'b1;
            ts_ns_next = ts_ns_ovf_reg[TS_NS_W+FNS_W-1:0];
            ts_s_next = ts_s_reg + 1;
        end
    end else if (TS_W == 64) begin
        // 64 bit timestamp
        ts_ns_next = ts_ns_reg + (TS_NS_W+FNS_W)'(period_ns_reg);
    end

    if (ts_sync_valid_reg) begin
        // Read new value
        if (TS_W == 96) begin
            if (src_ts_step_sync_reg || load_ts_reg) begin
                // input stepped
                load_ts_next = 1'b0;

                ts_s_next = src_ts_s_sync_reg;
                ts_ns_next[TS_NS_W+FNS_W-1:9+FNS_W] = src_ts_ns_sync_reg[TS_NS_W+CMP_FNS_W-1:9+CMP_FNS_W];
                ts_ns_inc_next[TS_NS_W+FNS_W-1:9+FNS_W] = src_ts_ns_sync_reg[TS_NS_W+CMP_FNS_W-1:9+CMP_FNS_W];
                ts_ns_ovf_next[30+FNS_W] = 1'b1;
                ts_step_next = 1;
            end else begin
                // input did not step
                load_ts_next = 1'b0;
                ts_diff_valid_next = freq_locked_reg;
            end
            // compute difference
            ts_ns_diff_next = (9+CMP_FNS_W)'(src_ts_ns_sync_reg - dest_ts_ns_capt_reg);
            ts_diff_next = src_ts_s_sync_reg != dest_ts_s_capt_reg || src_ts_ns_sync_reg[TS_NS_W+CMP_FNS_W-1:9+CMP_FNS_W] != dest_ts_ns_capt_reg[TS_NS_W+CMP_FNS_W-1:9+CMP_FNS_W];
        end else if (TS_W == 64) begin
            if (src_ts_step_sync_reg || load_ts_reg) begin
                // input stepped
                load_ts_next = 1'b0;

                ts_ns_next[TS_NS_W+FNS_W-1:9+FNS_W] = src_ts_ns_sync_reg[TS_NS_W+CMP_FNS_W-1:9+CMP_FNS_W];
                ts_step_next = 1;
            end else begin
                // input did not step
                load_ts_next = 1'b0;
                ts_diff_valid_next = freq_locked_reg;
            end
            // compute difference
            ts_ns_diff_next = (9+CMP_FNS_W)'(src_ts_ns_sync_reg - dest_ts_ns_capt_reg);
            ts_diff_next = src_ts_ns_sync_reg[TS_NS_W+CMP_FNS_W-1:9+CMP_FNS_W] != dest_ts_ns_capt_reg[TS_NS_W+CMP_FNS_W-1:9+CMP_FNS_W];
        end
    end

    if (ts_diff_valid_reg) begin
        if (ts_diff_reg) begin
            if (&mismatch_cnt_reg) begin
                load_ts_next = 1'b1;
                mismatch_cnt_next = '0;
            end else begin
                mismatch_cnt_next = mismatch_cnt_reg + 1;
            end
        end else begin
            mismatch_cnt_next = '0;
        end
    end

    if (phase_err_out_valid_reg) begin
        // coarse phase/frequency lock of PTP clock
        if ($signed(phase_err_out_reg) > 4 || $signed(phase_err_out_reg) < -4) begin
            if (freq_lock_count_reg != 0) begin
                freq_lock_count_next = freq_lock_count_reg - 1;
            end else begin
                freq_locked_next = 1'b0;
            end
        end else begin
            if (&freq_lock_count_reg) begin
                freq_locked_next = 1'b1;
            end else begin
                freq_lock_count_next = freq_lock_count_reg + 1;
            end
        end

        if (!freq_locked_reg) begin
            ts_ns_diff_next = $signed(phase_err_out_reg) * 8 * 2**CMP_FNS_W;
            ts_diff_valid_next = 1'b1;
        end
    end

    if (ts_diff_valid_reg) begin
        // PI control

        // gain scheduling
        casez (ts_ns_diff_reg[9+CMP_FNS_W-5 +: 5])
            5'b01zzz: gain_sel_next = 1'b1;
            5'b001zz: gain_sel_next = 1'b1;
            5'b0001z: gain_sel_next = 1'b1;
            5'b00001: gain_sel_next = 1'b1;
            5'b00000: gain_sel_next = 1'b0;
            5'b11111: gain_sel_next = 1'b0;
            5'b11110: gain_sel_next = 1'b1;
            5'b1110z: gain_sel_next = 1'b1;
            5'b110zz: gain_sel_next = 1'b1;
            5'b10zzz: gain_sel_next = 1'b1;
            default: gain_sel_next = 1'b0;
        endcase

        // time integral of error
        case (gain_sel_reg)
            1'b0: {ptp_ovf, time_err_int_next} = $signed({1'b0, time_err_int_reg}) + (TIME_ERR_INT_W+2)'($signed(ts_ns_diff_reg) / 2**4);
            1'b1: {ptp_ovf, time_err_int_next} = $signed({1'b0, time_err_int_reg}) + (TIME_ERR_INT_W+2)'($signed(ts_ns_diff_reg) * 2**2);
        endcase

        // saturate
        if (ptp_ovf[1]) begin
            // sign bit set indicating underflow across zero; saturate to zero
            time_err_int_next = '0;
        end else if (ptp_ovf[0]) begin
            // sign bit clear but carry bit set indicating overflow; saturate to all 1
            time_err_int_next = '1;
        end

        // compute output
        case (gain_sel_reg)
            1'b0: {ptp_ovf, period_ns_next} = $signed({1'b0, time_err_int_reg}) + (TIME_ERR_INT_W+2)'($signed(ts_ns_diff_reg) * 2**2);
            1'b1: {ptp_ovf, period_ns_next} = $signed({1'b0, time_err_int_reg}) + (TIME_ERR_INT_W+2)'($signed(ts_ns_diff_reg) * 2**6);
        endcase

        // saturate
        if (ptp_ovf[1]) begin
            // sign bit set indicating underflow across zero; saturate to zero
            period_ns_next = '0;
        end else if (ptp_ovf[0]) begin
            // sign bit clear but carry bit set indicating overflow; saturate to all 1
            period_ns_next = '1;
        end

        // adjust period if integrator is saturated
        if (time_err_int_reg == 0) begin
            period_ns_next = '0;
        end else if (~time_err_int_reg == 0) begin
            period_ns_next = '1;
        end

        // locked status
        if (!freq_locked_reg) begin
            ptp_lock_count_next = 0;
            ptp_locked_next = 1'b0;
        end else if (gain_sel_reg == 1'b0) begin
            if (&ptp_lock_count_reg) begin
                ptp_locked_next = 1'b1;
            end else begin
                ptp_lock_count_next = ptp_lock_count_reg + 1;
            end
        end else begin
            if (ptp_lock_count_reg != 0) begin
                ptp_lock_count_next = ptp_lock_count_reg - 1;
            end else begin
                ptp_locked_next = 1'b0;
            end
        end
    end
end

always_ff @(posedge output_clk) begin
    period_ns_reg <= period_ns_next;
    period_ns_delay_reg <= period_ns_delay_next;
    period_ns_ovf_reg <= period_ns_ovf_next;

    ts_s_reg <= ts_s_next;
    ts_ns_reg <= ts_ns_next;
    ts_ns_inc_reg <= ts_ns_inc_next;
    ts_ns_ovf_reg <= ts_ns_ovf_next;

    ts_step_reg <= ts_step_next;

    ts_diff_reg <= ts_diff_next;
    ts_diff_valid_reg <= ts_diff_valid_next;
    mismatch_cnt_reg <= mismatch_cnt_next;
    load_ts_reg <= load_ts_next;

    ts_ns_diff_reg <= ts_ns_diff_next;

    time_err_int_reg <= time_err_int_next;

    freq_lock_count_reg <= freq_lock_count_next;
    freq_locked_reg <= freq_locked_next;
    ptp_lock_count_reg <= ptp_lock_count_next;
    ptp_locked_reg <= ptp_locked_next;

    gain_sel_reg <= gain_sel_next;

    // PPS output
    pps_reg <= 1'b0;
    if (TS_W == 96) begin
        if (ts_ns_reg[29]) begin
            pps_str_reg <= 1'b0;
        end
        if (!ts_ns_ovf_reg[30+FNS_W]) begin
            pps_reg <= 1'b1;
            pps_str_reg <= 1'b1;
        end
    end

    // pipeline
    if (PIPELINE_OUTPUT > 0) begin
        ts_s_pipe_reg[0] <= ts_s_reg;
        ts_ns_pipe_reg[0] <= (TS_NS_W+CMP_FNS_W)'(ts_ns_reg >> FNS_W-TS_FNS_W);
        ts_step_pipe_reg[0] <= ts_step_reg;
        pps_pipe_reg[0] <= pps_reg;

        for (integer i = 0; i < PIPELINE_OUTPUT-1; i = i + 1) begin
            ts_s_pipe_reg[i+1] <= ts_s_pipe_reg[i];
            ts_ns_pipe_reg[i+1] <= ts_ns_pipe_reg[i];
            ts_step_pipe_reg[i+1] <= ts_step_pipe_reg[i];
            pps_pipe_reg[i+1] <= pps_pipe_reg[i];
        end
    end

    if (output_rst) begin
        period_ns_reg <= '0;
        ts_s_reg <= '0;
        ts_ns_reg <= '0;
        ts_ns_inc_reg <= '0;
        ts_ns_ovf_reg[30+FNS_W] <= 1'b1;
        ts_step_reg <= '0;
        pps_reg <= '0;

        ts_diff_reg <= 1'b0;
        ts_diff_valid_reg <= 1'b0;
        mismatch_cnt_reg <= '0;
        load_ts_reg <= '0;

        time_err_int_reg <= '0;

        freq_lock_count_reg <= '0;
        freq_locked_reg <= 1'b0;
        ptp_lock_count_reg <= '0;
        ptp_locked_reg <= 1'b0;

        for (integer i = 0; i < PIPELINE_OUTPUT; i = i + 1) begin
            ts_s_pipe_reg[i] <= '0;
            ts_ns_pipe_reg[i] <= '0;
            ts_step_pipe_reg[i] <= 1'b0;
            pps_pipe_reg[i] <= 1'b0;
        end
    end
end

endmodule

`resetall
