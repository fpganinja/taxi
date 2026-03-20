// SPDX-License-Identifier: CERN-OHL-S-2.0
/*

Copyright (c) 2025 FPGA Ninja, LLC

Authors:
- Alex Forencich

*/

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * APB interconnect
 */
module taxi_apb_interconnect_1s #
(
    // Number of downstream APB interfaces
    parameter M_CNT = 4,
    // Width of address decoder in bits
    parameter ADDR_W = 16,
    // Number of regions per master interface
    parameter M_REGIONS = 1,
    // TODO fix parametrization once verilator issue 5890 is fixed
    // Master interface base addresses
    // M_CNT concatenated fields of M_REGIONS concatenated fields of ADDR_W bits
    // set to zero for default addressing based on M_ADDR_W
    parameter M_BASE_ADDR = '0,
    // Master interface address widths
    // M_CNT concatenated fields of M_REGIONS concatenated fields of 32 bits
    parameter M_ADDR_W = {M_CNT{{M_REGIONS{32'd24}}}},
    // Secure master (fail operations based on awprot/arprot)
    // M_CNT bits
    parameter M_SECURE = {M_CNT{1'b0}}
)
(
    input  wire logic               clk,
    input  wire logic               rst,

    /*
     * APB slave interface
     */
    taxi_apb_if.slv                 s_apb,

    /*
     * APB master interface
     */
    taxi_apb_if.mst                 m_apb[M_CNT]
);

// extract parameters
localparam DATA_W = s_apb.DATA_W;
localparam S_ADDR_W = s_apb.ADDR_W;
localparam STRB_W = s_apb.STRB_W;
localparam logic PAUSER_EN = s_apb.PAUSER_EN && m_apb[0].PAUSER_EN;
localparam PAUSER_W = s_apb.PAUSER_W;
localparam logic PWUSER_EN = s_apb.PWUSER_EN && m_apb[0].PWUSER_EN;
localparam PWUSER_W = s_apb.PWUSER_W;
localparam logic PRUSER_EN = s_apb.PRUSER_EN && m_apb[0].PRUSER_EN;
localparam PRUSER_W = s_apb.PRUSER_W;
localparam logic PBUSER_EN = s_apb.PBUSER_EN && m_apb[0].PBUSER_EN;
localparam PBUSER_W = s_apb.PBUSER_W;

localparam APB_M_ADDR_W = m_apb[0].ADDR_W;

localparam CL_M_CNT = $clog2(M_CNT);
localparam CL_M_CNT_INT = CL_M_CNT > 0 ? CL_M_CNT : 1;

localparam [M_CNT*M_REGIONS-1:0][31:0] M_ADDR_W_INT = M_ADDR_W;
localparam [M_CNT-1:0] M_SECURE_INT = M_SECURE;

// default address computation
function [M_CNT*M_REGIONS-1:0][ADDR_W-1:0] calcBaseAddrs(input [31:0] dummy);
    logic [ADDR_W-1:0] base;
    integer width;
    logic [ADDR_W-1:0] size;
    logic [ADDR_W-1:0] mask;
    begin
        calcBaseAddrs = '0;
        base = '0;
        for (integer i = 0; i < M_CNT*M_REGIONS; i = i + 1) begin
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

localparam [M_CNT*M_REGIONS-1:0][ADDR_W-1:0] M_BASE_ADDR_INT = M_BASE_ADDR != 0 ? (M_CNT*M_REGIONS*ADDR_W)'(M_BASE_ADDR) : calcBaseAddrs(0);

// check configuration
if (s_apb.ADDR_W != ADDR_W)
    $fatal(0, "Error: Interface ADDR_W parameter mismatch (instance %m)");

if (m_apb[0].DATA_W != DATA_W)
    $fatal(0, "Error: Interface DATA_W parameter mismatch (instance %m)");

if (m_apb[0].STRB_W != STRB_W)
    $fatal(0, "Error: Interface STRB_W parameter mismatch (instance %m)");

initial begin
    for (integer i = 0; i < M_CNT*M_REGIONS; i = i + 1) begin
        /* verilator lint_off UNSIGNED */
        if (M_ADDR_W_INT[i] != 0 && (M_ADDR_W_INT[i] < $clog2(STRB_W) || M_ADDR_W_INT[i] > ADDR_W)) begin
            $error("Error: address width out of range (instance %m)");
            $finish;
        end
        /* verilator lint_on UNSIGNED */
    end

    $display("Addressing configuration for apb_interconnect instance %m");
    for (integer i = 0; i < M_CNT*M_REGIONS; i = i + 1) begin
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

    for (integer i = 0; i < M_CNT*M_REGIONS; i = i + 1) begin
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

    for (integer i = 0; i < M_CNT*M_REGIONS; i = i + 1) begin
        for (integer j = i+1; j < M_CNT*M_REGIONS; j = j + 1) begin
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

logic [CL_M_CNT_INT-1:0] sel_reg = '0;
logic act_reg = 1'b0;

logic s_apb_pready_reg = 1'b0;
logic [DATA_W-1:0] s_apb_prdata_reg = '0;
logic s_apb_pslverr_reg = 1'b0;
logic [PRUSER_W-1:0] s_apb_pruser_reg = '0;
logic [PBUSER_W-1:0] s_apb_pbuser_reg = '0;

logic [ADDR_W-1:0] m_apb_paddr_reg = '0;
logic [2:0] m_apb_pprot_reg = '0;
logic [M_CNT-1:0] m_apb_psel_reg = '0;
logic m_apb_penable_reg = 1'b0;
logic m_apb_pwrite_reg = 1'b0;
logic [DATA_W-1:0] m_apb_pwdata_reg = '0;
logic [STRB_W-1:0] m_apb_pstrb_reg = '0;
logic [PAUSER_W-1:0] m_apb_pauser_reg = '0;
logic [PWUSER_W-1:0] m_apb_pwuser_reg = '0;

wire [M_CNT-1:0] m_apb_pready;
wire [DATA_W-1:0] m_apb_prdata[M_CNT];
wire m_apb_pslverr[M_CNT];
wire [PRUSER_W-1:0] m_apb_pruser[M_CNT];
wire [PBUSER_W-1:0] m_apb_pbuser[M_CNT];

assign s_apb.pready = s_apb_pready_reg;
assign s_apb.prdata = s_apb_prdata_reg;
assign s_apb.pslverr = s_apb_pslverr_reg;
assign s_apb.pruser = PRUSER_EN ? s_apb_pruser_reg : '0;
assign s_apb.pbuser = PBUSER_EN ? s_apb_pbuser_reg : '0;

for (genvar n = 0; n < M_CNT; n += 1) begin
    assign m_apb[n].paddr = APB_M_ADDR_W'(m_apb_paddr_reg);
    assign m_apb[n].pprot = m_apb_pprot_reg;
    assign m_apb[n].psel = m_apb_psel_reg[n];
    assign m_apb[n].penable = m_apb_penable_reg;
    assign m_apb[n].pwrite = m_apb_pwrite_reg;
    assign m_apb[n].pwdata = m_apb_pwdata_reg;
    assign m_apb[n].pstrb = m_apb_pstrb_reg;
    assign m_apb_pready[n] = m_apb[n].pready;
    assign m_apb_prdata[n] = m_apb[n].prdata;
    assign m_apb_pslverr[n] = m_apb[n].pslverr;
    assign m_apb[n].pauser = PAUSER_EN ? m_apb_pauser_reg : '0;
    assign m_apb[n].pwuser = PWUSER_EN ? m_apb_pwuser_reg : '0;
    assign m_apb_pruser[n] = m_apb[n].pruser;
    assign m_apb_pbuser[n] = m_apb[n].pbuser;
end

always_ff @(posedge clk) begin
    s_apb_pready_reg <= 1'b0;
    m_apb_penable_reg <= act_reg && s_apb.penable;

    s_apb_prdata_reg <= m_apb_prdata[sel_reg];
    s_apb_pslverr_reg <= m_apb_pslverr[sel_reg] | (m_apb_psel_reg == 0);
    s_apb_pruser_reg <= m_apb_pruser[sel_reg];
    s_apb_pbuser_reg <= m_apb_pbuser[sel_reg];

    if ((m_apb_psel_reg & ~m_apb_pready) == 0) begin
        m_apb_psel_reg <= '0;
        m_apb_penable_reg <= 1'b0;
        s_apb_pready_reg <= act_reg;
        act_reg <= 1'b0;
    end

    if (!act_reg) begin
        m_apb_paddr_reg <= s_apb.paddr;
        m_apb_pprot_reg <= s_apb.pprot;
        m_apb_pwrite_reg <= s_apb.pwrite;
        m_apb_pwdata_reg <= s_apb.pwdata;
        m_apb_pstrb_reg <= s_apb.pstrb;
        m_apb_pauser_reg <= s_apb.pauser;
        m_apb_pwuser_reg <= s_apb.pwuser;

        m_apb_psel_reg <= '0;
        m_apb_penable_reg <= 1'b0;

        if (s_apb.psel && !s_apb_pready_reg) begin
            act_reg <= 1'b1;
            for (integer i = 0; i < M_CNT; i = i + 1) begin
                for (integer j = 0; j < M_REGIONS; j = j + 1) begin
                    if (M_ADDR_W_INT[i*M_REGIONS+j] != 0 && (!M_SECURE_INT[i] || !s_apb.pprot[1]) && (s_apb.paddr >> M_ADDR_W_INT[i*M_REGIONS+j]) == (M_BASE_ADDR_INT[i*M_REGIONS+j] >> M_ADDR_W_INT[i*M_REGIONS+j])) begin
                        sel_reg <= CL_M_CNT_INT'(i);
                        m_apb_psel_reg[i] <= 1'b1;
                    end
                end
            end
        end
    end

    if (rst) begin
        act_reg <= 1'b0;
        s_apb_pready_reg <= 1'b0;
        m_apb_psel_reg <= '0;
        m_apb_penable_reg <= 1'b0;
    end
end

endmodule

`resetall
