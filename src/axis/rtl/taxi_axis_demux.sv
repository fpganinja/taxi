// SPDX-License-Identifier: CERN-OHL-S-2.0
/*

Copyright (c) 2018-2026 FPGA Ninja, LLC

Authors:
- Alex Forencich

*/

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * AXI4-Stream demultiplexer
 */
module taxi_axis_demux #
(
    // Number of AXI stream outputs
    parameter M_COUNT = 4,
    // route via tid
    parameter logic TID_ROUTE = 1'b0,
    // route via tdest
    parameter logic TDEST_ROUTE = 1'b0
)
(
    input  wire logic                        clk,
    input  wire logic                        rst,

    /*
     * AXI4-Stream input (sink)
     */
    taxi_axis_if.snk                         s_axis,

    /*
     * AXI4-Stream output (source)
     */
    taxi_axis_if.src                         m_axis[M_COUNT],

    /*
     * Control
     */
    input  wire logic                        enable,
    input  wire logic                        drop,
    input  wire logic [$clog2(M_COUNT)-1:0]  select
);

// extract parameters
localparam DATA_W = s_axis.DATA_W;
localparam logic KEEP_EN = s_axis.KEEP_EN && m_axis[0].KEEP_EN;
localparam KEEP_W = s_axis.KEEP_W;
localparam logic STRB_EN = s_axis.STRB_EN && m_axis[0].STRB_EN;
localparam logic LAST_EN = s_axis.LAST_EN && m_axis[0].LAST_EN;
localparam logic ID_EN = s_axis.ID_EN && m_axis[0].ID_EN;
localparam ID_W = s_axis.ID_W;
localparam logic DEST_EN = s_axis.DEST_EN && m_axis[0].DEST_EN;
localparam S_ID_W = s_axis.ID_W;
localparam M_ID_W = m_axis[0].ID_W;
localparam S_DEST_W = s_axis.DEST_W;
localparam M_DEST_W = m_axis[0].DEST_W;
localparam logic USER_EN = s_axis.USER_EN && m_axis[0].USER_EN;
localparam USER_W = s_axis.USER_W;

localparam CL_M_COUNT = $clog2(M_COUNT);

localparam M_DEST_W_INT = M_DEST_W > 0 ? M_DEST_W : 1;
localparam M_ID_W_INT = M_ID_W > 0 ? M_ID_W : 1;

// check configuration
if (m_axis[0].DATA_W != DATA_W)
    $fatal(0, "Error: Interface DATA_W parameter mismatch (instance %m)");

if (KEEP_EN && m_axis[0].KEEP_W != KEEP_W)
    $fatal(0, "Error: Interface KEEP_W parameter mismatch (instance %m)");

if (TID_ROUTE) begin
    if (!ID_EN)
        $fatal(0, "Error: TID_ROUTE set requires ID_EN set (instance %m)");

    if (S_ID_W < CL_M_COUNT)
        $fatal(0, "Error: S_ID_W too small for port count (instance %m)");

    if (TDEST_ROUTE)
        $fatal(0, "Error: Cannot enable both TID_ROUTE and TDEST_ROUTE (instance %m)");
end

if (TDEST_ROUTE) begin
    if (!DEST_EN)
        $fatal(0, "Error: TDEST_ROUTE set requires DEST_EN set (instance %m)");

    if (S_DEST_W < CL_M_COUNT)
        $fatal(0, "Error: S_DEST_W too small for port count (instance %m)");
end

logic [CL_M_COUNT-1:0] select_reg = '0, select_ctl, select_next;
logic drop_reg = 1'b0, drop_ctl, drop_next;
logic frame_reg = 1'b0, frame_ctl, frame_next;

logic s_axis_tready_reg = 1'b0, s_axis_tready_next;

// internal datapath
logic [DATA_W-1:0]    m_axis_tdata_int;
logic [KEEP_W-1:0]    m_axis_tkeep_int;
logic [KEEP_W-1:0]    m_axis_tstrb_int;
logic [M_COUNT-1:0]   m_axis_tvalid_int;
logic                 m_axis_tready_int_reg = 1'b0;
logic                 m_axis_tlast_int;
logic [M_ID_W-1:0]    m_axis_tid_int;
logic [M_DEST_W-1:0]  m_axis_tdest_int;
logic [USER_W-1:0]    m_axis_tuser_int;
wire                  m_axis_tready_int_early;

assign s_axis.tready = s_axis_tready_reg && enable;

always_comb begin
    select_next = select_reg;
    select_ctl = select_reg;
    drop_next = drop_reg;
    drop_ctl = drop_reg;
    frame_next = frame_reg;
    frame_ctl = frame_reg;

    if (s_axis.tvalid && s_axis.tready) begin
        // end of frame detection
        if (s_axis.tlast) begin
            frame_next = 1'b0;
            drop_next = 1'b0;
        end
    end

    if (!frame_reg && s_axis.tvalid && s_axis.tready) begin
        // start of frame, grab select value
        if (TID_ROUTE) begin
            if (M_COUNT > 1) begin
                select_ctl = s_axis.tid[S_ID_W-1:S_ID_W-CL_M_COUNT];
                drop_ctl = (CL_M_COUNT+1)'(select_ctl) >= (CL_M_COUNT+1)'(M_COUNT);
            end else begin
                select_ctl = '0;
                drop_ctl = 1'b0;
            end
        end else if (TDEST_ROUTE) begin
            if (M_COUNT > 1) begin
                select_ctl = s_axis.tdest[S_DEST_W-1:S_DEST_W-CL_M_COUNT];
                drop_ctl = (CL_M_COUNT+1)'(select_ctl) >= (CL_M_COUNT+1)'(M_COUNT);
            end else begin
                select_ctl = '0;
                drop_ctl = 1'b0;
            end
        end else begin
            select_ctl = select;
            drop_ctl = drop || (CL_M_COUNT+1)'(select) >= (CL_M_COUNT+1)'(M_COUNT);
        end
        frame_ctl = 1'b1;
        if (!(s_axis.tready && s_axis.tvalid && s_axis.tlast)) begin
            select_next = select_ctl;
            drop_next = drop_ctl;
            frame_next = 1'b1;
        end
    end

    m_axis_tdata_int  = s_axis.tdata;
    m_axis_tkeep_int  = s_axis.tkeep;
    m_axis_tstrb_int  = s_axis.tstrb;
    m_axis_tvalid_int = '0;
    m_axis_tvalid_int[select_ctl] = s_axis.tvalid && s_axis.tready && !drop_ctl;
    m_axis_tlast_int  = s_axis.tlast;
    m_axis_tid_int    = M_ID_W'(s_axis.tid);
    m_axis_tdest_int  = M_DEST_W'(s_axis.tdest);
    m_axis_tuser_int  = s_axis.tuser;
end

always_comb begin
    s_axis_tready_next = (m_axis_tready_int_early || drop_ctl);
end

always_ff @(posedge clk) begin
    select_reg <= select_next;
    drop_reg <= drop_next;
    frame_reg <= frame_next;
    s_axis_tready_reg <= s_axis_tready_next;

    if (rst) begin
        select_reg <= '0;
        drop_reg <= 1'b0;
        frame_reg <= 1'b0;
        s_axis_tready_reg <= 1'b0;
    end
end

// output datapath logic
logic [DATA_W-1:0]    m_axis_tdata_reg  = '0;
logic [KEEP_W-1:0]    m_axis_tkeep_reg  = '0;
logic [KEEP_W-1:0]    m_axis_tstrb_reg  = '0;
logic [M_COUNT-1:0]   m_axis_tvalid_reg = '0, m_axis_tvalid_next;
logic                 m_axis_tlast_reg  = 1'b0;
logic [M_ID_W-1:0]    m_axis_tid_reg    = '0;
logic [M_DEST_W-1:0]  m_axis_tdest_reg  = '0;
logic [USER_W-1:0]    m_axis_tuser_reg  = '0;

logic [DATA_W-1:0]    temp_m_axis_tdata_reg  = '0;
logic [KEEP_W-1:0]    temp_m_axis_tkeep_reg  = '0;
logic [KEEP_W-1:0]    temp_m_axis_tstrb_reg  = '0;
logic [M_COUNT-1:0]   temp_m_axis_tvalid_reg = '0, temp_m_axis_tvalid_next;
logic                 temp_m_axis_tlast_reg  = 1'b0;
logic [M_ID_W-1:0]    temp_m_axis_tid_reg    = '0;
logic [M_DEST_W-1:0]  temp_m_axis_tdest_reg  = '0;
logic [USER_W-1:0]    temp_m_axis_tuser_reg  = '0;

// datapath control
logic store_axis_int_to_output;
logic store_axis_int_to_temp;
logic store_axis_temp_to_output;

wire [M_COUNT-1:0] m_axis_tready;

for (genvar k = 0; k < M_COUNT; k = k + 1) begin
    assign m_axis[k].tdata  = m_axis_tdata_reg;
    assign m_axis[k].tkeep  = KEEP_EN ? m_axis_tkeep_reg : '1;
    assign m_axis[k].tstrb  = STRB_EN ? m_axis_tstrb_reg : m_axis[k].tkeep;
    assign m_axis[k].tvalid = m_axis_tvalid_reg[k];
    assign m_axis[k].tlast  = m_axis_tlast_reg;
    assign m_axis[k].tid    = ID_EN   ? m_axis_tid_reg   : '0;
    assign m_axis[k].tdest  = DEST_EN ? m_axis_tdest_reg : '0;
    assign m_axis[k].tuser  = USER_EN ? m_axis_tuser_reg : '0;

    assign m_axis_tready[k] = m_axis[k].tready;
end

// enable ready input next cycle if output is ready or the temp reg will not be filled on the next cycle (output reg empty or no input)
assign m_axis_tready_int_early = (m_axis_tready & m_axis_tvalid_reg) != 0 || (temp_m_axis_tvalid_reg == 0 && (m_axis_tvalid_reg == 0 || m_axis_tvalid_int == 0));

always_comb begin
    // transfer sink ready state to source
    m_axis_tvalid_next = m_axis_tvalid_reg;
    temp_m_axis_tvalid_next = temp_m_axis_tvalid_reg;

    store_axis_int_to_output = 1'b0;
    store_axis_int_to_temp = 1'b0;
    store_axis_temp_to_output = 1'b0;

    if (m_axis_tready_int_reg) begin
        // input is ready
        if ((m_axis_tready & m_axis_tvalid_reg) != 0 || m_axis_tvalid_reg == 0) begin
            // output is ready or currently not valid, transfer data to output
            m_axis_tvalid_next = m_axis_tvalid_int;
            store_axis_int_to_output = 1'b1;
        end else begin
            // output is not ready, store input in temp
            temp_m_axis_tvalid_next = m_axis_tvalid_int;
            store_axis_int_to_temp = 1'b1;
        end
    end else if ((m_axis_tready & m_axis_tvalid_reg) != 0) begin
        // input is not ready, but output is ready
        m_axis_tvalid_next = temp_m_axis_tvalid_reg;
        temp_m_axis_tvalid_next = '0;
        store_axis_temp_to_output = 1'b1;
    end
end

always_ff @(posedge clk) begin
    m_axis_tvalid_reg <= m_axis_tvalid_next;
    m_axis_tready_int_reg <= m_axis_tready_int_early;
    temp_m_axis_tvalid_reg <= temp_m_axis_tvalid_next;

    // datapath
    if (store_axis_int_to_output) begin
        m_axis_tdata_reg <= m_axis_tdata_int;
        m_axis_tkeep_reg <= m_axis_tkeep_int;
        m_axis_tstrb_reg <= m_axis_tstrb_int;
        m_axis_tlast_reg <= m_axis_tlast_int;
        m_axis_tid_reg   <= m_axis_tid_int;
        m_axis_tdest_reg <= m_axis_tdest_int;
        m_axis_tuser_reg <= m_axis_tuser_int;
    end else if (store_axis_temp_to_output) begin
        m_axis_tdata_reg <= temp_m_axis_tdata_reg;
        m_axis_tkeep_reg <= temp_m_axis_tkeep_reg;
        m_axis_tstrb_reg <= temp_m_axis_tstrb_reg;
        m_axis_tlast_reg <= temp_m_axis_tlast_reg;
        m_axis_tid_reg   <= temp_m_axis_tid_reg;
        m_axis_tdest_reg <= temp_m_axis_tdest_reg;
        m_axis_tuser_reg <= temp_m_axis_tuser_reg;
    end

    if (store_axis_int_to_temp) begin
        temp_m_axis_tdata_reg <= m_axis_tdata_int;
        temp_m_axis_tkeep_reg <= m_axis_tkeep_int;
        temp_m_axis_tstrb_reg <= m_axis_tstrb_int;
        temp_m_axis_tlast_reg <= m_axis_tlast_int;
        temp_m_axis_tid_reg   <= m_axis_tid_int;
        temp_m_axis_tdest_reg <= m_axis_tdest_int;
        temp_m_axis_tuser_reg <= m_axis_tuser_int;
    end

    if (rst) begin
        m_axis_tvalid_reg <= '0;
        m_axis_tready_int_reg <= 1'b0;
        temp_m_axis_tvalid_reg <= '0;
    end
end

endmodule

`resetall
