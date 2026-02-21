// SPDX-License-Identifier: CERN-OHL-S-2.0
/*

Copyright (c) 2019-2025 FPGA Ninja, LLC

Authors:
- Alex Forencich

*/

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * DMA interface descriptor mux
 */
module taxi_dma_desc_mux #
(
    // Number of ports
    parameter PORTS = 2,
    // Extend select signals
    parameter logic EXTEND_SEL = 1'b1,
    // select round robin arbitration
    parameter logic ARB_ROUND_ROBIN = 1'b0,
    // LSB priority selection
    parameter logic ARB_LSB_HIGH_PRIO = 1'b1
)
(
    input  wire               clk,
    input  wire               rst,

    /*
     * DMA descriptors from clients
     */
    taxi_dma_desc_if.req_snk  client_req[PORTS],
    taxi_dma_desc_if.sts_src  client_sts[PORTS],

    /*
     * DMA descriptors to DMA engines
     */
    taxi_dma_desc_if.req_src  dma_req,
    taxi_dma_desc_if.sts_snk  dma_sts
);

localparam CL_PORTS = $clog2(PORTS);

localparam SRC_ADDR_W = dma_req.SRC_ADDR_W;
localparam logic SRC_SEL_EN = dma_req.SRC_SEL_EN;
localparam DMA_SRC_SEL_W = dma_req.SRC_SEL_W;
localparam logic SRC_ASID_EN = dma_req.SRC_ASID_EN;
localparam SRC_ASID_W = dma_req.SRC_ASID_W;
localparam DST_ADDR_W = dma_req.DST_ADDR_W;
localparam logic DST_SEL_EN = dma_req.DST_SEL_EN;
localparam DMA_DST_SEL_W = dma_req.DST_SEL_W;
localparam logic DST_ASID_EN = dma_req.DST_ASID_EN;
localparam DST_ASID_W = dma_req.DST_ASID_W;
localparam logic IMM_EN = dma_req.IMM_EN;
localparam IMM_W = dma_req.IMM_W;
localparam LEN_W = dma_req.LEN_W;
localparam DMA_TAG_W = dma_req.TAG_W;
localparam logic ID_EN = dma_req.ID_EN;
localparam ID_W = dma_req.ID_W;
localparam logic DEST_EN = dma_req.DEST_EN;
localparam DEST_W = dma_req.DEST_W;
localparam logic USER_EN = dma_req.USER_EN;
localparam USER_W = dma_req.USER_W;

localparam CLIENT_SRC_SEL_W = client_req[0].SRC_SEL_W;
localparam CLIENT_DST_SEL_W = client_req[0].DST_SEL_W;
localparam CLIENT_TAG_W = client_req[0].TAG_W;

// check configuration
if (DMA_TAG_W < CLIENT_TAG_W+$clog2(PORTS))
    $fatal(0, "Error: DMA_TAG_W must be at least $clog2(PORTS) larger than CLIENT_TAG_W (instance %m)");

if (EXTEND_SEL && PORTS > 1) begin
    if (SRC_SEL_EN && DMA_SRC_SEL_W < CLIENT_SRC_SEL_W+$clog2(PORTS))
        $fatal(0, "Error: DMA_SRC_SEL_W must be at least $clog2(PORTS) larger than CLIENT_SRC_SEL_W (instance %m)");
    if (DST_SEL_EN && DMA_DST_SEL_W < CLIENT_DST_SEL_W+$clog2(PORTS))
        $fatal(0, "Error: DMA_DST_SEL_W must be at least $clog2(PORTS) larger than CLIENT_DST_SEL_W (instance %m)");
end else begin
    if (SRC_SEL_EN && DMA_SRC_SEL_W < CLIENT_SRC_SEL_W)
        $fatal(0, "Error: DMA_SRC_SEL_W must be no smaller than CLIENT_SRC_SEL_W (instance %m)");
    if (DST_SEL_EN && DMA_DST_SEL_W < CLIENT_DST_SEL_W)
        $fatal(0, "Error: DMA_DST_SEL_W must be no smaller than CLIENT_DST_SEL_W (instance %m)");
end

// internal datapath
logic [SRC_ADDR_W-1:0]     dma_req_src_addr_int;
logic [DMA_SRC_SEL_W-1:0]  dma_req_src_sel_int;
logic [SRC_ASID_W-1:0]     dma_req_src_asid_int;
logic [DST_ADDR_W-1:0]     dma_req_dst_addr_int;
logic [DMA_DST_SEL_W-1:0]  dma_req_dst_sel_int;
logic [DST_ASID_W-1:0]     dma_req_dst_asid_int;
logic [IMM_W-1:0]          dma_req_imm_int;
logic                      dma_req_imm_en_int;
logic [LEN_W-1:0]          dma_req_len_int;
logic [DMA_TAG_W-1:0]      dma_req_tag_int;
logic [ID_W-1:0]           dma_req_id_int;
logic [DEST_W-1:0]         dma_req_dest_int;
logic [USER_W-1:0]         dma_req_user_int;
logic                      dma_req_valid_int;
logic                      dma_req_ready_int_reg = 1'b0;
wire                       dma_req_ready_int_early;

if (PORTS == 1) begin
    // degenerate case

    assign client_req[0].req_ready = dma_req_ready_int_reg;

    always_comb begin
        // pass through selected request data
        dma_req_src_addr_int = client_req[0].req_src_addr;
        dma_req_src_sel_int = client_req[0].req_src_sel;
        dma_req_src_asid_int = client_req[0].req_src_asid;
        dma_req_dst_addr_int = client_req[0].req_dst_addr;
        dma_req_dst_sel_int = client_req[0].req_dst_sel;
        dma_req_dst_asid_int = client_req[0].req_dst_asid;
        dma_req_imm_int = client_req[0].req_imm;
        dma_req_imm_en_int = client_req[0].req_imm_en;
        dma_req_len_int = client_req[0].req_len;
        dma_req_tag_int = DMA_TAG_W'(client_req[0].req_tag);
        dma_req_id_int = client_req[0].req_id;
        dma_req_dest_int = client_req[0].req_dest;
        dma_req_user_int = client_req[0].req_user;
        dma_req_valid_int = client_req[0].req_valid && dma_req_ready_int_reg;
    end

end else begin

    wire [PORTS-1:0] req;
    wire [PORTS-1:0] ack;
    wire [PORTS-1:0] grant;
    wire grant_valid;
    wire [CL_PORTS-1:0] grant_index;

    // input registers to pipeline arbitration delay
    logic [SRC_ADDR_W-1:0]        req_src_addr_reg[PORTS] = '{PORTS{'0}};
    logic [CLIENT_SRC_SEL_W-1:0]  req_src_sel_reg[PORTS] = '{PORTS{'0}};
    logic [SRC_ASID_W-1:0]        req_src_asid_reg[PORTS] = '{PORTS{'0}};
    logic [DST_ADDR_W-1:0]        req_dst_addr_reg[PORTS] = '{PORTS{'0}};
    logic [CLIENT_DST_SEL_W-1:0]  req_dst_sel_reg[PORTS] = '{PORTS{'0}};
    logic [DST_ASID_W-1:0]        req_dst_asid_reg[PORTS] = '{PORTS{'0}};
    logic [IMM_W-1:0]             req_imm_reg[PORTS] = '{PORTS{'0}};
    logic                         req_imm_en_reg[PORTS] = '{PORTS{'0}};
    logic [LEN_W-1:0]             req_len_reg[PORTS] = '{PORTS{'0}};
    logic [CLIENT_TAG_W-1:0]      req_tag_reg[PORTS] = '{PORTS{'0}};
    logic [ID_W-1:0]              req_id_reg[PORTS] = '{PORTS{'0}};
    logic [DEST_W-1:0]            req_dest_reg[PORTS] = '{PORTS{'0}};
    logic [USER_W-1:0]            req_user_reg[PORTS] = '{PORTS{'0}};
    logic [PORTS-1:0]             req_valid_reg = '0;
    logic [PORTS-1:0]             req_ready_reg = '0;

    // unpack interface array
    wire [PORTS-1:0]  req_valid;
    wire [PORTS-1:0]  req_ready;

    for (genvar n = 0; n < PORTS; n = n + 1) begin
        assign req_valid[n] = client_req[n].req_valid;
        assign client_req[n].req_ready = req_ready[n];
    end

    assign req_ready = ~req_valid_reg | ({PORTS{dma_req_ready_int_reg}} & grant);

    // mux for incoming packet
    wire [SRC_ADDR_W-1:0]        current_req_src_addr  = req_src_addr_reg[grant_index];
    wire [CLIENT_SRC_SEL_W-1:0]  current_req_src_sel   = req_src_sel_reg[grant_index];
    wire [SRC_ASID_W-1:0]        current_req_src_asid  = req_src_asid_reg[grant_index];
    wire [DST_ADDR_W-1:0]        current_req_dst_addr  = req_dst_addr_reg[grant_index];
    wire [CLIENT_DST_SEL_W-1:0]  current_req_dst_sel   = req_dst_sel_reg[grant_index];
    wire [DST_ASID_W-1:0]        current_req_dst_asid  = req_dst_asid_reg[grant_index];
    wire [IMM_W-1:0]             current_req_imm       = req_imm_reg[grant_index];
    wire                         current_req_imm_en    = req_imm_en_reg[grant_index];
    wire [LEN_W-1:0]             current_req_len       = req_len_reg[grant_index];
    wire [CLIENT_TAG_W-1:0]      current_req_tag       = req_tag_reg[grant_index];
    wire [ID_W-1:0]              current_req_id        = req_id_reg[grant_index];
    wire [DEST_W-1:0]            current_req_dest      = req_dest_reg[grant_index];
    wire [USER_W-1:0]            current_req_user      = req_user_reg[grant_index];
    wire                         current_req_valid     = req_valid_reg[grant_index];

    // arbiter instance
    taxi_arbiter #(
        .PORTS(PORTS),
        .ARB_ROUND_ROBIN(ARB_ROUND_ROBIN),
        .ARB_BLOCK(1'b1),
        .ARB_BLOCK_ACK(1'b1),
        .LSB_HIGH_PRIO(ARB_LSB_HIGH_PRIO)
    )
    arb_inst (
        .clk(clk),
        .rst(rst),
        .req(req),
        .ack(ack),
        .grant(grant),
        .grant_valid(grant_valid),
        .grant_index(grant_index)
    );

    assign req = req_valid | (req_valid_reg & ~grant);
    assign ack = grant & req_valid_reg & {PORTS{dma_req_ready_int_reg}};

    always_comb begin
        // pass through selected descriptor data
        dma_req_src_addr_int = current_req_src_addr;
        dma_req_src_sel_int = DMA_SRC_SEL_W'(current_req_src_sel);
        if (EXTEND_SEL && SRC_SEL_EN) begin
            // workaround verilator bug - unreachable by parameter value
            /* verilator lint_off SELRANGE */
            dma_req_src_sel_int[DMA_SRC_SEL_W-1:DMA_SRC_SEL_W-CL_PORTS] = grant_index;
            /* verilator lint_on SELRANGE */
        end
        dma_req_src_asid_int = current_req_src_asid;
        dma_req_dst_addr_int = current_req_dst_addr;
        dma_req_dst_sel_int = DMA_DST_SEL_W'(current_req_dst_sel);
        if (EXTEND_SEL && DST_SEL_EN) begin
            // workaround verilator bug - unreachable by parameter value
            /* verilator lint_off SELRANGE */
            dma_req_dst_sel_int[DMA_DST_SEL_W-1:DMA_DST_SEL_W-CL_PORTS] = grant_index;
            /* verilator lint_on SELRANGE */
        end
        dma_req_dst_asid_int = current_req_dst_asid;
        dma_req_imm_int = current_req_imm;
        dma_req_imm_en_int = current_req_imm_en;
        dma_req_len_int = current_req_len;
        dma_req_tag_int = DMA_TAG_W'(current_req_tag);
        dma_req_tag_int[DMA_TAG_W-1:DMA_TAG_W-CL_PORTS] = grant_index;
        dma_req_id_int = current_req_id;
        dma_req_dest_int = current_req_dest;
        dma_req_user_int = current_req_user;
        dma_req_valid_int = current_req_valid && dma_req_ready_int_reg && grant_valid;
    end

    for (genvar n = 0; n < PORTS; n = n + 1) begin
        always_ff @(posedge clk) begin
            // register inputs
            if (req_ready[n]) begin
                req_src_addr_reg[n] <= client_req[n].req_src_addr;
                req_src_sel_reg[n] <= client_req[n].req_src_sel;
                req_src_asid_reg[n] <= client_req[n].req_src_asid;
                req_dst_addr_reg[n] <= client_req[n].req_dst_addr;
                req_dst_sel_reg[n] <= client_req[n].req_dst_sel;
                req_dst_asid_reg[n] <= client_req[n].req_dst_asid;
                req_imm_reg[n] <= client_req[n].req_imm;
                req_imm_en_reg[n] <= client_req[n].req_imm_en;
                req_len_reg[n] <= client_req[n].req_len;
                req_tag_reg[n] <= client_req[n].req_tag;
                req_id_reg[n] <= client_req[n].req_id;
                req_dest_reg[n] <= client_req[n].req_dest;
                req_user_reg[n] <= client_req[n].req_user;
                req_valid_reg[n] <= client_req[n].req_valid;
            end

            if (rst) begin
                req_valid_reg[n] <= 1'b0;
            end
        end
    end

end

// output datapath logic
logic [SRC_ADDR_W-1:0]     dma_req_src_addr_reg = '0;
logic [DMA_SRC_SEL_W-1:0]  dma_req_src_sel_reg = '0;
logic [SRC_ASID_W-1:0]     dma_req_src_asid_reg = '0;
logic [DST_ADDR_W-1:0]     dma_req_dst_addr_reg = '0;
logic [DMA_DST_SEL_W-1:0]  dma_req_dst_sel_reg = '0;
logic [DST_ASID_W-1:0]     dma_req_dst_asid_reg = '0;
logic [IMM_W-1:0]          dma_req_imm_reg = '0;
logic                      dma_req_imm_en_reg = 1'b0;
logic [LEN_W-1:0]          dma_req_len_reg = '0;
logic [DMA_TAG_W-1:0]      dma_req_tag_reg = '0;
logic [ID_W-1:0]           dma_req_id_reg = '0;
logic [DEST_W-1:0]         dma_req_dest_reg = '0;
logic [USER_W-1:0]         dma_req_user_reg = '0;
logic                      dma_req_valid_reg = '0, dma_req_valid_next;

logic [SRC_ADDR_W-1:0]     temp_dma_req_src_addr_reg = '0;
logic [DMA_SRC_SEL_W-1:0]  temp_dma_req_src_sel_reg = '0;
logic [SRC_ASID_W-1:0]     temp_dma_req_src_asid_reg = '0;
logic [DST_ADDR_W-1:0]     temp_dma_req_dst_addr_reg = '0;
logic [DMA_DST_SEL_W-1:0]  temp_dma_req_dst_sel_reg = '0;
logic [DST_ASID_W-1:0]     temp_dma_req_dst_asid_reg = '0;
logic [IMM_W-1:0]          temp_dma_req_imm_reg = '0;
logic                      temp_dma_req_imm_en_reg = 1'b0;
logic [LEN_W-1:0]          temp_dma_req_len_reg = '0;
logic [DMA_TAG_W-1:0]      temp_dma_req_tag_reg = '0;
logic [ID_W-1:0]           temp_dma_req_id_reg = '0;
logic [DEST_W-1:0]         temp_dma_req_dest_reg = '0;
logic [USER_W-1:0]         temp_dma_req_user_reg = '0;
logic                      temp_dma_req_valid_reg = '0, temp_dma_req_valid_next;

// datapath control
logic store_req_int_to_output;
logic store_req_int_to_temp;
logic store_req_temp_to_output;

assign dma_req.req_src_addr  = dma_req_src_addr_reg;
assign dma_req.req_src_sel   = SRC_SEL_EN  ? dma_req_src_sel_reg : '0;
assign dma_req.req_src_asid  = SRC_ASID_EN ? dma_req_src_asid_reg : '0;
assign dma_req.req_dst_addr  = dma_req_dst_addr_reg;
assign dma_req.req_dst_sel   = DST_SEL_EN  ? dma_req_dst_sel_reg : '0;
assign dma_req.req_dst_asid  = DST_ASID_EN ? dma_req_dst_asid_reg : '0;
assign dma_req.req_imm       = IMM_EN      ? dma_req_imm_reg : '0;
assign dma_req.req_imm_en    = IMM_EN      ? dma_req_imm_en_reg : 1'b0;
assign dma_req.req_len       = dma_req_len_reg;
assign dma_req.req_tag       = dma_req_tag_reg;
assign dma_req.req_id        = ID_EN       ? dma_req_id_reg : '0;
assign dma_req.req_dest      = DEST_EN     ? dma_req_dest_reg : '0;
assign dma_req.req_user      = USER_EN     ? dma_req_user_reg : '0;
assign dma_req.req_valid     = dma_req_valid_reg;

// enable ready input next cycle if output is ready or the temp reg will not be filled on the next cycle (output reg empty or no input)
assign dma_req_ready_int_early = dma_req.req_ready || (!temp_dma_req_valid_reg && (!dma_req_valid_reg || !dma_req_valid_int));

always_comb begin
    // transfer sink ready state to source
    dma_req_valid_next = dma_req_valid_reg;
    temp_dma_req_valid_next = temp_dma_req_valid_reg;

    store_req_int_to_output = 1'b0;
    store_req_int_to_temp = 1'b0;
    store_req_temp_to_output = 1'b0;

    if (dma_req_ready_int_reg) begin
        // input is ready
        if (dma_req.req_ready || !dma_req_valid_reg) begin
            // output is ready or currently not valid, transfer data to output
            dma_req_valid_next = dma_req_valid_int;
            store_req_int_to_output = 1'b1;
        end else begin
            // output is not ready, store input in temp
            temp_dma_req_valid_next = dma_req_valid_int;
            store_req_int_to_temp = 1'b1;
        end
    end else if (dma_req.req_ready) begin
        // input is not ready, but output is ready
        dma_req_valid_next = temp_dma_req_valid_reg;
        temp_dma_req_valid_next = 1'b0;
        store_req_temp_to_output = 1'b1;
    end
end

always_ff @(posedge clk) begin
    dma_req_valid_reg <= dma_req_valid_next;
    dma_req_ready_int_reg <= dma_req_ready_int_early;
    temp_dma_req_valid_reg <= temp_dma_req_valid_next;

    // datapath
    if (store_req_int_to_output) begin
        dma_req_src_addr_reg <= dma_req_src_addr_int;
        dma_req_src_sel_reg <= dma_req_src_sel_int;
        dma_req_src_asid_reg <= dma_req_src_asid_int;
        dma_req_dst_addr_reg <= dma_req_dst_addr_int;
        dma_req_dst_sel_reg <= dma_req_dst_sel_int;
        dma_req_dst_asid_reg <= dma_req_dst_asid_int;
        dma_req_imm_reg <= dma_req_imm_int;
        dma_req_imm_en_reg <= dma_req_imm_en_int;
        dma_req_len_reg <= dma_req_len_int;
        dma_req_tag_reg <= dma_req_tag_int;
        dma_req_id_reg <= dma_req_id_int;
        dma_req_dest_reg <= dma_req_dest_int;
        dma_req_user_reg <= dma_req_user_int;
    end else if (store_req_temp_to_output) begin
        dma_req_src_addr_reg <= temp_dma_req_src_addr_reg;
        dma_req_src_sel_reg <= temp_dma_req_src_sel_reg;
        dma_req_src_asid_reg <= temp_dma_req_src_asid_reg;
        dma_req_dst_addr_reg <= temp_dma_req_dst_addr_reg;
        dma_req_dst_sel_reg <= temp_dma_req_dst_sel_reg;
        dma_req_dst_asid_reg <= temp_dma_req_dst_asid_reg;
        dma_req_imm_reg <= temp_dma_req_imm_reg;
        dma_req_imm_en_reg <= temp_dma_req_imm_en_reg;
        dma_req_len_reg <= temp_dma_req_len_reg;
        dma_req_tag_reg <= temp_dma_req_tag_reg;
        dma_req_id_reg <= temp_dma_req_id_reg;
        dma_req_dest_reg <= temp_dma_req_dest_reg;
        dma_req_user_reg <= temp_dma_req_user_reg;
    end

    if (store_req_int_to_temp) begin
        temp_dma_req_src_addr_reg <= dma_req_src_addr_int;
        temp_dma_req_src_sel_reg <= dma_req_src_sel_int;
        temp_dma_req_src_asid_reg <= dma_req_src_asid_int;
        temp_dma_req_dst_addr_reg <= dma_req_dst_addr_int;
        temp_dma_req_dst_sel_reg <= dma_req_dst_sel_int;
        temp_dma_req_dst_asid_reg <= dma_req_dst_asid_int;
        temp_dma_req_imm_reg <= dma_req_imm_int;
        temp_dma_req_imm_en_reg <= dma_req_imm_en_int;
        temp_dma_req_len_reg <= dma_req_len_int;
        temp_dma_req_tag_reg <= dma_req_tag_int;
        temp_dma_req_id_reg <= dma_req_id_int;
        temp_dma_req_dest_reg <= dma_req_dest_int;
        temp_dma_req_user_reg <= dma_req_user_int;
    end

    if (rst) begin
        dma_req_valid_reg <= 1'b0;
        dma_req_ready_int_reg <= 1'b0;
        temp_dma_req_valid_reg <= 1'b0;
    end
end

// descriptor status demux
logic [LEN_W-1:0]         client_sts_len_reg = '0;
logic [CLIENT_TAG_W-1:0]  client_sts_tag_reg = '0;
logic [ID_W-1:0]          client_sts_id_reg = '0;
logic [DEST_W-1:0]        client_sts_dest_reg = '0;
logic [USER_W-1:0]        client_sts_user_reg = '0;
logic [3:0]               client_sts_error_reg = 4'd0;
logic [PORTS-1:0]         client_sts_valid_reg = '0;

for (genvar n = 0; n < PORTS; n = n + 1) begin
    assign client_sts[n].sts_len = client_sts_len_reg;
    assign client_sts[n].sts_tag = client_sts_tag_reg;
    assign client_sts[n].sts_id = ID_EN ? client_sts_id_reg : '0;
    assign client_sts[n].sts_dest = DEST_EN ? client_sts_dest_reg : '0;
    assign client_sts[n].sts_user = USER_EN ? client_sts_user_reg : '0;
    assign client_sts[n].sts_error = client_sts_error_reg;
    assign client_sts[n].sts_valid = client_sts_valid_reg[n];
end

always_ff @(posedge clk) begin
    client_sts_len_reg <= dma_sts.sts_len;
    client_sts_tag_reg <= CLIENT_TAG_W'(dma_sts.sts_tag);
    client_sts_id_reg <= dma_sts.sts_id;
    client_sts_dest_reg <= dma_sts.sts_dest;
    client_sts_user_reg <= dma_sts.sts_user;
    client_sts_error_reg <= dma_sts.sts_error;
    if (PORTS > 1) begin
        client_sts_valid_reg <= '0;
        client_sts_valid_reg[CL_PORTS'(dma_sts.sts_tag >> (DMA_TAG_W-CL_PORTS))] <= dma_sts.sts_valid;
    end else begin
        client_sts_valid_reg <= PORTS'(dma_sts.sts_valid);
    end

    if (rst) begin
        client_sts_valid_reg <= '0;
    end
end

endmodule

`resetall
