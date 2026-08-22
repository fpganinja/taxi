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
 * AXI4 interconnect
 */
module taxi_axi_interconnect_rd #
(
    // Number of AXI inputs (slave interfaces)
    parameter S_COUNT = 4,
    // Number of AXI outputs (master interfaces)
    parameter M_COUNT = 4,
    // Address width in bits for address decoding
    parameter ADDR_W = 32,
    // Number of regions per master interface
    parameter M_REGIONS = 1,
    // TODO fix parametrization once verilator issue 5890 is fixed
    // Master interface base addresses
    // M_COUNT concatenated fields of M_REGIONS concatenated fields of ADDR_W bits
    // set to zero for default addressing based on M_ADDR_W
    parameter M_BASE_ADDR = '0,
    // Master interface address widths
    // M_COUNT concatenated fields of M_REGIONS concatenated fields of 32 bits
    parameter M_ADDR_W = {M_COUNT{{M_REGIONS{32'd24}}}},
    // Read connections between interfaces
    // M_COUNT concatenated fields of S_COUNT bits
    parameter M_CONNECT = {M_COUNT{{S_COUNT{1'b1}}}},
    // Secure master (fail operations based on awprot/arprot)
    // M_COUNT bits
    parameter M_SECURE = {M_COUNT{1'b0}}
)
(
    input  wire logic   clk,
    input  wire logic   rst,

    /*
     * AXI4 slave interfaces
     */
    taxi_axi_if.rd_slv  s_axi_rd[S_COUNT],

    /*
     * AXI4 master interfaces
     */
    taxi_axi_if.rd_mst  m_axi_rd[M_COUNT]
);

// extract parameters
localparam DATA_W = s_axi_rd[0].DATA_W;
localparam S_ADDR_W = s_axi_rd[0].ADDR_W;
localparam STRB_W = s_axi_rd[0].STRB_W;
localparam S_ID_W = s_axi_rd[0].ID_W;
localparam M_ID_W = m_axi_rd[0].ID_W;
localparam logic ARUSER_EN = s_axi_rd[0].ARUSER_EN && m_axi_rd[0].ARUSER_EN;
localparam ARUSER_W = s_axi_rd[0].ARUSER_W;
localparam logic RUSER_EN = s_axi_rd[0].RUSER_EN && m_axi_rd[0].RUSER_EN;
localparam RUSER_W = s_axi_rd[0].RUSER_W;

localparam AXI_M_ADDR_W = m_axi_rd[0].ADDR_W;

localparam CL_S_COUNT = $clog2(S_COUNT);
localparam CL_M_COUNT = $clog2(M_COUNT);
localparam CL_S_COUNT_INT = CL_S_COUNT > 0 ? CL_S_COUNT : 1;
localparam CL_M_COUNT_INT = CL_M_COUNT > 0 ? CL_M_COUNT : 1;

localparam [M_COUNT*M_REGIONS-1:0][31:0] M_ADDR_W_INT = M_ADDR_W;
localparam [M_COUNT-1:0][S_COUNT-1:0] M_CONNECT_INT = M_CONNECT;
localparam [M_COUNT-1:0] M_SECURE_INT = M_SECURE;

// default address computation
function [M_COUNT*M_REGIONS-1:0][ADDR_W-1:0] calcBaseAddrs(input [31:0] dummy);
    logic [ADDR_W-1:0] base;
    integer width;
    logic [ADDR_W-1:0] size;
    logic [ADDR_W-1:0] mask;
    begin
        calcBaseAddrs = '0;
        base = '0;
        for (integer i = 0; i < M_COUNT*M_REGIONS; i = i + 1) begin
            width = M_ADDR_W_INT[i];
            mask = {ADDR_W{1'b1}} >> (ADDR_W - width);
            size = mask + 1;
            if (width > 0) begin
                if ((base & mask) != 0) begin
                    base = base + size - (base & mask); // align
                end
                calcBaseAddrs[i] = base;
                base = base + size; // increment
            end
        end
    end
endfunction

localparam [M_COUNT*M_REGIONS-1:0][ADDR_W-1:0] M_BASE_ADDR_INT = M_BASE_ADDR != 0 ? (M_COUNT*M_REGIONS*ADDR_W)'(M_BASE_ADDR) : calcBaseAddrs(0);

// check configuration
if (s_axi_rd[0].ADDR_W != ADDR_W)
    $fatal(0, "Error: Interface ADDR_W parameter mismatch (instance %m)");

if (m_axi_rd[0].DATA_W != DATA_W)
    $fatal(0, "Error: Interface DATA_W parameter mismatch (instance %m)");

if (m_axi_rd[0].STRB_W != STRB_W)
    $fatal(0, "Error: Interface STRB_W parameter mismatch (instance %m)");

if (M_REGIONS < 1 || M_REGIONS > 16)
    $fatal(0, "Error: M_REGIONS must be between 1 and 16 (instance %m)");

initial begin
    for (integer i = 0; i < M_COUNT*M_REGIONS; i = i + 1) begin
        /* verilator lint_off UNSIGNED */
        if (M_ADDR_W_INT[i] != 0 && (M_ADDR_W_INT[i] < $clog2(STRB_W) || M_ADDR_W_INT[i] > ADDR_W)) begin
            $error("Error: address width out of range (instance %m)");
            $finish;
        end
        /* verilator lint_on UNSIGNED */
    end

    $display("Addressing configuration for axi_interconnect instance %m");
    for (integer i = 0; i < M_COUNT*M_REGIONS; i = i + 1) begin
        if (M_ADDR_W_INT[i] != 0) begin
            $display("%2d (%2d): %x / %02d -- %x-%x",
                i/M_REGIONS, i%M_REGIONS,
                M_BASE_ADDR_INT[i],
                M_ADDR_W_INT[i],
                M_BASE_ADDR_INT[i] & ({ADDR_W{1'b1}} << M_ADDR_W_INT[i]),
                M_BASE_ADDR_INT[i] | ({ADDR_W{1'b1}} >> (ADDR_W - M_ADDR_W_INT[i]))
            );
        end
    end

    for (integer i = 0; i < M_COUNT*M_REGIONS; i = i + 1) begin
        if ((M_BASE_ADDR_INT[i] & (2**M_ADDR_W_INT[i]-1)) != 0) begin
            $display("Region not aligned:");
            $display("%2d (%2d): %x / %2d -- %x-%x",
                i/M_REGIONS, i%M_REGIONS,
                M_BASE_ADDR_INT[i],
                M_ADDR_W_INT[i],
                M_BASE_ADDR_INT[i] & ({ADDR_W{1'b1}} << M_ADDR_W_INT[i]),
                M_BASE_ADDR_INT[i] | ({ADDR_W{1'b1}} >> (ADDR_W - M_ADDR_W_INT[i]))
            );
            $error("Error: address range not aligned (instance %m)");
            $finish;
        end
    end

    for (integer i = 0; i < M_COUNT*M_REGIONS; i = i + 1) begin
        for (integer j = i+1; j < M_COUNT*M_REGIONS; j = j + 1) begin
            if (M_ADDR_W_INT[i] != 0 && M_ADDR_W_INT[j] != 0) begin
                if (((M_BASE_ADDR_INT[i] & ({ADDR_W{1'b1}} << M_ADDR_W_INT[i])) <= (M_BASE_ADDR_INT[j] | ({ADDR_W{1'b1}} >> (ADDR_W - M_ADDR_W_INT[j]))))
                        && ((M_BASE_ADDR_INT[j] & ({ADDR_W{1'b1}} << M_ADDR_W_INT[j])) <= (M_BASE_ADDR_INT[i] | ({ADDR_W{1'b1}} >> (ADDR_W - M_ADDR_W_INT[i]))))) begin
                    $display("Overlapping regions:");
                    $display("%2d (%2d): %x / %2d -- %x-%x",
                        i/M_REGIONS, i%M_REGIONS,
                        M_BASE_ADDR_INT[i],
                        M_ADDR_W_INT[i],
                        M_BASE_ADDR_INT[i] & ({ADDR_W{1'b1}} << M_ADDR_W_INT[i]),
                        M_BASE_ADDR_INT[i] | ({ADDR_W{1'b1}} >> (ADDR_W - M_ADDR_W_INT[i]))
                    );
                    $display("%2d (%2d): %x / %2d -- %x-%x",
                        j/M_REGIONS, j%M_REGIONS,
                        M_BASE_ADDR_INT[j],
                        M_ADDR_W_INT[j],
                        M_BASE_ADDR_INT[j] & ({ADDR_W{1'b1}} << M_ADDR_W_INT[j]),
                        M_BASE_ADDR_INT[j] | ({ADDR_W{1'b1}} >> (ADDR_W - M_ADDR_W_INT[j]))
                    );
                    $error("Error: address ranges overlap (instance %m)");
                    $finish;
                end
            end
        end
    end
end

typedef enum logic [2:0] {
    STATE_IDLE,
    STATE_DECODE,
    STATE_READ,
    STATE_READ_DROP,
    STATE_WAIT_IDLE
} state_t;

state_t state_reg = STATE_IDLE, state_next;

logic match;

logic [CL_M_COUNT_INT-1:0] m_select_reg = '0, m_select_next;
logic [S_ID_W-1:0] axi_id_reg = '0, axi_id_next;
logic [ADDR_W-1:0] axi_addr_reg = '0, axi_addr_next;
logic axi_addr_valid_reg = 1'b0, axi_addr_valid_next;
logic [7:0] axi_len_reg = 8'd0, axi_len_next;
logic [2:0] axi_size_reg = 3'd0, axi_size_next;
logic [1:0] axi_burst_reg = 2'd0, axi_burst_next;
logic axi_lock_reg = 1'b0, axi_lock_next;
logic [3:0] axi_cache_reg = 4'd0, axi_cache_next;
logic [2:0] axi_prot_reg = 3'b000, axi_prot_next;
logic [3:0] axi_qos_reg = 4'd0, axi_qos_next;
logic [3:0] axi_region_reg = 4'd0, axi_region_next;
logic [ARUSER_W-1:0] axi_aruser_reg = '0, axi_aruser_next;

logic [S_COUNT-1:0] s_axi_arready_reg = '0, s_axi_arready_next;

logic [M_COUNT-1:0] m_axi_arvalid_reg = '0, m_axi_arvalid_next;
logic [M_COUNT-1:0] m_axi_rready_reg = '0, m_axi_rready_next;

// internal datapath
logic  [S_ID_W-1:0]   s_axi_rid_int;
logic  [DATA_W-1:0]   s_axi_rdata_int;
logic  [1:0]          s_axi_rresp_int;
logic                 s_axi_rlast_int;
logic  [RUSER_W-1:0]  s_axi_ruser_int;
logic  [S_COUNT-1:0]  s_axi_rvalid_int;
logic                 s_axi_rready_int_reg = 1'b0;
wire                  s_axi_rready_int_early;

// unpack interface array
wire [S_ID_W-1:0]    s_axi_arid[S_COUNT];
wire [ADDR_W-1:0]    s_axi_araddr[S_COUNT];
wire [7:0]           s_axi_arlen[S_COUNT];
wire [2:0]           s_axi_arsize[S_COUNT];
wire [1:0]           s_axi_arburst[S_COUNT];
wire                 s_axi_arlock[S_COUNT];
wire [3:0]           s_axi_arcache[S_COUNT];
wire [2:0]           s_axi_prot[S_COUNT];
wire [3:0]           s_axi_arqos[S_COUNT];
wire [ARUSER_W-1:0]  s_axi_aruser[S_COUNT];
wire [S_COUNT-1:0]   s_axi_arvalid;

wire [M_COUNT-1:0]   m_axi_arready;
wire [M_ID_W-1:0]    m_axi_rid[M_COUNT];
wire [DATA_W-1:0]    m_axi_rdata[M_COUNT];
wire [1:0]           m_axi_rresp[M_COUNT];
wire                 m_axi_rlast[M_COUNT];
wire [RUSER_W-1:0]   m_axi_ruser[M_COUNT];
wire [M_COUNT-1:0]   m_axi_rvalid;

for (genvar n = 0; n < S_COUNT; n = n + 1) begin
    assign s_axi_arid[n] = s_axi_rd[n].arid;
    assign s_axi_araddr[n] = s_axi_rd[n].araddr;
    assign s_axi_arlen[n] = s_axi_rd[n].arlen;
    assign s_axi_arsize[n] = s_axi_rd[n].arsize;
    assign s_axi_arburst[n] = s_axi_rd[n].arburst;
    assign s_axi_arlock[n] = s_axi_rd[n].arlock;
    assign s_axi_arcache[n] = s_axi_rd[n].arcache;
    assign s_axi_prot[n] = s_axi_rd[n].arprot;
    assign s_axi_arqos[n] = s_axi_rd[n].arqos;
    assign s_axi_aruser[n] = s_axi_rd[n].aruser;
    assign s_axi_arvalid[n] = s_axi_rd[n].arvalid;
    assign s_axi_rd[n].arready = s_axi_arready_reg[n];
end

for (genvar n = 0; n < M_COUNT; n = n + 1) begin
    assign m_axi_rd[n].arid = axi_id_reg;
    assign m_axi_rd[n].araddr = AXI_M_ADDR_W'(axi_addr_reg);
    assign m_axi_rd[n].arlen = axi_len_reg;
    assign m_axi_rd[n].arsize = axi_size_reg;
    assign m_axi_rd[n].arburst = axi_burst_reg;
    assign m_axi_rd[n].arlock = axi_lock_reg;
    assign m_axi_rd[n].arcache = axi_cache_reg;
    assign m_axi_rd[n].arprot = axi_prot_reg;
    assign m_axi_rd[n].arqos = axi_qos_reg;
    assign m_axi_rd[n].aruser = ARUSER_EN ? axi_aruser_reg : '0;
    assign m_axi_rd[n].arvalid = m_axi_arvalid_reg[n];
    assign m_axi_arready[n] = m_axi_rd[n].arready;
    assign m_axi_rid[n] = m_axi_rd[n].rid;
    assign m_axi_rdata[n] = m_axi_rd[n].rdata;
    assign m_axi_rresp[n] = m_axi_rd[n].rresp;
    assign m_axi_rlast[n] = m_axi_rd[n].rlast;
    assign m_axi_ruser[n] = m_axi_rd[n].ruser;
    assign m_axi_rvalid[n] = m_axi_rd[n].rvalid;
    assign m_axi_rd[n].rready = m_axi_rready_reg[n];
end

// slave side mux
wire [CL_S_COUNT_INT-1:0] s_select;

wire [S_ID_W-1:0]    current_s_axi_arid    = s_axi_arid[s_select];
wire [ADDR_W-1:0]    current_s_axi_araddr  = s_axi_araddr[s_select];
wire [7:0]           current_s_axi_arlen   = s_axi_arlen[s_select];
wire [2:0]           current_s_axi_arsize  = s_axi_arsize[s_select];
wire [1:0]           current_s_axi_arburst = s_axi_arburst[s_select];
wire                 current_s_axi_arlock  = s_axi_arlock[s_select];
wire [3:0]           current_s_axi_arcache = s_axi_arcache[s_select];
wire [2:0]           current_s_axi_prot    = s_axi_prot[s_select];
wire [3:0]           current_s_axi_arqos   = s_axi_arqos[s_select];
wire [ARUSER_W-1:0]  current_s_axi_aruser  = s_axi_aruser[s_select];
wire                 current_s_axi_arvalid = s_axi_arvalid[s_select];
wire                 current_s_axi_rready  = s_axi_rready[s_select];

// master side mux
wire                 current_m_axi_arready = m_axi_arready[m_select_reg];
wire [M_ID_W-1:0]    current_m_axi_rid     = m_axi_rid[m_select_reg];
wire [DATA_W-1:0]    current_m_axi_rdata   = m_axi_rdata[m_select_reg];
wire [1:0]           current_m_axi_rresp   = m_axi_rresp[m_select_reg];
wire                 current_m_axi_rlast   = m_axi_rlast[m_select_reg];
wire [RUSER_W-1:0]   current_m_axi_ruser   = m_axi_ruser[m_select_reg];
wire                 current_m_axi_rvalid  = m_axi_rvalid[m_select_reg];

// arbiter instance
wire [S_COUNT-1:0] req;
wire [S_COUNT-1:0] ack;
wire [S_COUNT-1:0] grant;
wire grant_valid;
wire [CL_S_COUNT_INT-1:0] grant_index;

assign s_select = grant_index;

if (S_COUNT > 1) begin : arb

    taxi_arbiter #(
        .PORTS(S_COUNT),
        .ARB_ROUND_ROBIN(1),
        .ARB_BLOCK(1),
        .ARB_BLOCK_ACK(1),
        .LSB_HIGH_PRIO(1)
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

end else begin

    logic grant_valid_reg = 1'b0;

    always @(posedge clk) begin
        if (req) begin
            grant_valid_reg <= 1'b1;
        end

        if (ack || rst) begin
            grant_valid_reg <= 1'b0;
        end
    end

    assign grant_valid = grant_valid_reg;
    assign grant = '1;
    assign grant_index = '0;

end

// req generation
assign req = s_axi_arvalid;
assign ack = state_reg == STATE_WAIT_IDLE ? '1 : '0;

always_comb begin
    state_next = STATE_IDLE;

    match = 1'b0;

    m_select_next = m_select_reg;
    axi_id_next = axi_id_reg;
    axi_addr_next = axi_addr_reg;
    axi_addr_valid_next = axi_addr_valid_reg;
    axi_len_next = axi_len_reg;
    axi_size_next = axi_size_reg;
    axi_burst_next = axi_burst_reg;
    axi_lock_next = axi_lock_reg;
    axi_cache_next = axi_cache_reg;
    axi_prot_next = axi_prot_reg;
    axi_qos_next = axi_qos_reg;
    axi_region_next = axi_region_reg;
    axi_aruser_next = axi_aruser_reg;

    s_axi_arready_next = '0;

    m_axi_arvalid_next = m_axi_arvalid_reg & ~m_axi_arready;
    m_axi_rready_next = '0;

    s_axi_rid_int = axi_id_reg;
    s_axi_rdata_int = current_m_axi_rdata;
    s_axi_rresp_int = current_m_axi_rresp;
    s_axi_rlast_int = current_m_axi_rlast;
    s_axi_ruser_int = current_m_axi_ruser;
    s_axi_rvalid_int = '0;

    case (state_reg)
        STATE_IDLE: begin
            // idle state; wait for arbitration

            axi_addr_valid_next = 1'b1;
            axi_id_next = current_s_axi_arid;
            axi_addr_next = current_s_axi_araddr;
            axi_len_next = current_s_axi_arlen;
            axi_size_next = current_s_axi_arsize;
            axi_burst_next = current_s_axi_arburst;
            axi_lock_next = current_s_axi_arlock;
            axi_cache_next = current_s_axi_arcache;
            axi_prot_next = current_s_axi_prot;
            axi_qos_next = current_s_axi_arqos;
            axi_aruser_next = current_s_axi_aruser;

            if (grant_valid) begin
                s_axi_arready_next[s_select] = 1'b1;
                state_next = STATE_DECODE;
            end else begin
                state_next = STATE_IDLE;
            end
        end
        STATE_DECODE: begin
            // decode state; determine master interface

            match = 1'b0;
            for (integer i = 0; i < M_COUNT; i = i + 1) begin
                for (integer j = 0; j < M_REGIONS; j = j + 1) begin
                    if (M_ADDR_W_INT[i*M_REGIONS+j] != 0 && (!M_SECURE_INT[i] || !axi_prot_reg[1]) && M_CONNECT_INT[i][s_select] && (axi_addr_reg >> M_ADDR_W_INT[i*M_REGIONS+j]) == (M_BASE_ADDR_INT[i*M_REGIONS+j] >> M_ADDR_W_INT[i*M_REGIONS+j])) begin
                        m_select_next = CL_M_COUNT_INT'(i);
                        match = 1'b1;
                    end
                end
            end

            if (match) begin
                m_axi_rready_next[m_select_reg] = s_axi_rready_int_early;
                state_next = STATE_READ;
            end else begin
                // no match; return decode error
                state_next = STATE_READ_DROP;
            end
        end
        STATE_READ: begin
            // read state; store and forward read response
            m_axi_rready_next[m_select_reg] = s_axi_rready_int_early;

            if (axi_addr_valid_reg) begin
                m_axi_arvalid_next[m_select_reg] = 1'b1;
            end
            axi_addr_valid_next = 1'b0;

            s_axi_rid_int = axi_id_reg;
            s_axi_rdata_int = current_m_axi_rdata;
            s_axi_rresp_int = current_m_axi_rresp;
            s_axi_rlast_int = current_m_axi_rlast;
            s_axi_ruser_int = current_m_axi_ruser;

            if (m_axi_rready_reg != 0 && current_m_axi_rvalid) begin
                s_axi_rvalid_int[s_select] = 1'b1;

                if (current_m_axi_rlast) begin
                    m_axi_rready_next[m_select_reg] = 1'b0;
                    state_next = STATE_WAIT_IDLE;
                end else begin
                    state_next = STATE_READ;
                end
            end else begin
                state_next = STATE_READ;
            end
        end
        STATE_READ_DROP: begin
            // read drop state; generate decode error read response

            s_axi_rid_int = axi_id_reg;
            s_axi_rdata_int = '0;
            s_axi_rresp_int = 2'b11;
            s_axi_rlast_int = axi_len_reg == 0;
            s_axi_ruser_int = '0;
            s_axi_rvalid_int[s_select] = 1'b1;

            if (s_axi_rready_int_reg) begin
                axi_len_next = axi_len_reg - 1;
                if (axi_len_reg == 0) begin
                    state_next = STATE_WAIT_IDLE;
                end else begin
                    state_next = STATE_READ_DROP;
                end
            end else begin
                state_next = STATE_READ_DROP;
            end
        end
        STATE_WAIT_IDLE: begin
            // wait for idle state; wait untl grant valid is deasserted

            if (grant_valid == 0 || ack != 0) begin
                state_next = STATE_IDLE;
            end else begin
                state_next = STATE_WAIT_IDLE;
            end
        end
        default: begin
            // invalid state
            state_next = STATE_IDLE;
        end
    endcase
end

always_ff @(posedge clk) begin
    state_reg <= state_next;

    s_axi_arready_reg <= s_axi_arready_next;

    m_axi_arvalid_reg <= m_axi_arvalid_next;
    m_axi_rready_reg <= m_axi_rready_next;

    m_select_reg <= m_select_next;
    axi_id_reg <= axi_id_next;
    axi_addr_reg <= axi_addr_next;
    axi_addr_valid_reg <= axi_addr_valid_next;
    axi_len_reg <= axi_len_next;
    axi_size_reg <= axi_size_next;
    axi_burst_reg <= axi_burst_next;
    axi_lock_reg <= axi_lock_next;
    axi_cache_reg <= axi_cache_next;
    axi_prot_reg <= axi_prot_next;
    axi_qos_reg <= axi_qos_next;
    axi_region_reg <= axi_region_next;
    axi_aruser_reg <= axi_aruser_next;

    if (rst) begin
        state_reg <= STATE_IDLE;

        s_axi_arready_reg <= '0;

        m_axi_arvalid_reg <= '0;
        m_axi_rready_reg <= '0;
    end
end

// output datapath logic (R channel)
logic [S_ID_W-1:0]  s_axi_rid_reg    = '0;
logic [DATA_W-1:0]  s_axi_rdata_reg  = '0;
logic [1:0]         s_axi_rresp_reg  = 2'd0;
logic               s_axi_rlast_reg  = 1'b0;
logic [RUSER_W-1:0] s_axi_ruser_reg  = 1'b0;
logic [S_COUNT-1:0] s_axi_rvalid_reg = '0, s_axi_rvalid_next;

logic [S_ID_W-1:0]  temp_s_axi_rid_reg    = '0;
logic [DATA_W-1:0]  temp_s_axi_rdata_reg  = '0;
logic [1:0]         temp_s_axi_rresp_reg  = 2'd0;
logic               temp_s_axi_rlast_reg  = 1'b0;
logic [RUSER_W-1:0] temp_s_axi_ruser_reg  = 1'b0;
logic [S_COUNT-1:0] temp_s_axi_rvalid_reg = '0, temp_s_axi_rvalid_next;

// datapath control
logic store_axi_r_int_to_output;
logic store_axi_r_int_to_temp;
logic store_axi_r_temp_to_output;

wire [S_COUNT-1:0] s_axi_rready;

for (genvar n = 0; n < S_COUNT; n = n + 1) begin
    assign s_axi_rd[n].rid = s_axi_rid_reg;
    assign s_axi_rd[n].rdata = s_axi_rdata_reg;
    assign s_axi_rd[n].rresp = s_axi_rresp_reg;
    assign s_axi_rd[n].rlast = s_axi_rlast_reg;
    assign s_axi_rd[n].ruser = RUSER_EN ? s_axi_ruser_reg : '0;
    assign s_axi_rd[n].rvalid = s_axi_rvalid_reg[n];
    assign s_axi_rready[n] = s_axi_rd[n].rready;
end

// enable ready input next cycle if output is ready or the temp reg will not be filled on the next cycle (output reg empty or no input)
assign s_axi_rready_int_early = (s_axi_rready & s_axi_rvalid_reg) != 0 || (temp_s_axi_rvalid_reg == 0 && (s_axi_rvalid_reg == 0 || s_axi_rvalid_int == 0));

always_comb begin
    // transfer sink ready state to source
    s_axi_rvalid_next = s_axi_rvalid_reg;
    temp_s_axi_rvalid_next = temp_s_axi_rvalid_reg;

    store_axi_r_int_to_output = 1'b0;
    store_axi_r_int_to_temp = 1'b0;
    store_axi_r_temp_to_output = 1'b0;

    if (s_axi_rready_int_reg) begin
        // input is ready
        if ((s_axi_rready & s_axi_rvalid_reg) != 0 || s_axi_rvalid_reg == 0) begin
            // output is ready or currently not valid, transfer data to output
            s_axi_rvalid_next = s_axi_rvalid_int;
            store_axi_r_int_to_output = 1'b1;
        end else begin
            // output is not ready, store input in temp
            temp_s_axi_rvalid_next = s_axi_rvalid_int;
            store_axi_r_int_to_temp = 1'b1;
        end
    end else if ((s_axi_rready & s_axi_rvalid_reg) != 0) begin
        // input is not ready, but output is ready
        s_axi_rvalid_next = temp_s_axi_rvalid_reg;
        temp_s_axi_rvalid_next = '0;
        store_axi_r_temp_to_output = 1'b1;
    end
end

always_ff @(posedge clk) begin
    s_axi_rvalid_reg <= s_axi_rvalid_next;
    s_axi_rready_int_reg <= s_axi_rready_int_early;
    temp_s_axi_rvalid_reg <= temp_s_axi_rvalid_next;

    // datapath
    if (store_axi_r_int_to_output) begin
        s_axi_rid_reg <= s_axi_rid_int;
        s_axi_rdata_reg <= s_axi_rdata_int;
        s_axi_rresp_reg <= s_axi_rresp_int;
        s_axi_rlast_reg <= s_axi_rlast_int;
        s_axi_ruser_reg <= s_axi_ruser_int;
    end else if (store_axi_r_temp_to_output) begin
        s_axi_rid_reg <= temp_s_axi_rid_reg;
        s_axi_rdata_reg <= temp_s_axi_rdata_reg;
        s_axi_rresp_reg <= temp_s_axi_rresp_reg;
        s_axi_rlast_reg <= temp_s_axi_rlast_reg;
        s_axi_ruser_reg <= temp_s_axi_ruser_reg;
    end

    if (store_axi_r_int_to_temp) begin
        temp_s_axi_rid_reg <= s_axi_rid_int;
        temp_s_axi_rdata_reg <= s_axi_rdata_int;
        temp_s_axi_rresp_reg <= s_axi_rresp_int;
        temp_s_axi_rlast_reg <= s_axi_rlast_int;
        temp_s_axi_ruser_reg <= s_axi_ruser_int;
    end

    if (rst) begin
        s_axi_rvalid_reg <= '0;
        s_axi_rready_int_reg <= 1'b0;
        temp_s_axi_rvalid_reg <= '0;
    end
end

endmodule

`resetall
