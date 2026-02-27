// SPDX-License-Identifier: CERN-OHL-S-2.0
/*

Copyright (c) 2022-2026 FPGA Ninja, LLC

Authors:
- Alex Forencich

*/

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * PCIe MSI-X module with APB interface
 */
module taxi_pcie_msix_apb #
(
    // TLP interface configuration
    parameter logic TLP_FORCE_64_BIT_ADDR = 1'b0
)
(
    input  wire logic        clk,
    input  wire logic        rst,

    /*
     * APB interface for MSI-X tables
     */
    taxi_apb_if.slv          s_apb,

    /*
     * Interrupt request input
     */
    taxi_axis_if.snk         s_axis_irq,

    /*
     * Memory write TLP output
     */
    taxi_pcie_tlp_if.src     tx_wr_req_tlp,

    /*
     * Configuration
     */
    input  wire logic [7:0]  bus_num,
    input  wire logic [7:0]  func_num,
    input  wire logic        msix_enable,
    input  wire logic        msix_mask
);

// extract parameters
localparam TLP_SEGS = tx_wr_req_tlp.SEGS;
localparam TLP_SEG_DATA_W = tx_wr_req_tlp.SEG_DATA_W;
localparam TLP_SEG_EMPTY_W = tx_wr_req_tlp.SEG_EMPTY_W;
localparam TLP_DATA_W = TLP_SEGS*TLP_SEG_DATA_W;
localparam TLP_HDR_W = tx_wr_req_tlp.HDR_W;
localparam FUNC_NUM_W = tx_wr_req_tlp.FUNC_NUM_W;

localparam APB_DATA_W = s_apb.DATA_W;
localparam APB_ADDR_W = s_apb.ADDR_W;
localparam APB_STRB_W = s_apb.STRB_W;

localparam IRQ_INDEX_W = s_axis_irq.DATA_W;

localparam TLP_DATA_W_B = TLP_DATA_W/8;
localparam TLP_DATA_W_DW = TLP_DATA_W/32;

localparam TBL_ADDR_W = IRQ_INDEX_W+1;
localparam PBA_ADDR_W = IRQ_INDEX_W > 6 ? IRQ_INDEX_W-6 : 0;
localparam PBA_ADDR_W_INT = PBA_ADDR_W > 0 ? PBA_ADDR_W : 1;

localparam INDEX_SHIFT = $clog2(64/8);
localparam WORD_SELECT_SHIFT = $clog2(APB_DATA_W/8);
localparam WORD_SELECT_W = 64 > APB_DATA_W ? $clog2((64+7)/8) - $clog2(APB_DATA_W/8) : 0;

// bus width assertions
if (APB_STRB_W * 8 != APB_DATA_W)
    $fatal(0, "Error: APB interface requires byte (8-bit) granularity (instance %m)");

if (APB_DATA_W > 64)
    $fatal(0, "Error: APB data width must be 64 or less (instance %m)");

if (APB_ADDR_W < IRQ_INDEX_W+5)
    $fatal(0, "Error: APB address width too narrow (instance %m)");

if (IRQ_INDEX_W > 11)
    $fatal(0, "Error: IRQ index width must be 11 or less (instance %m)");

localparam [2:0]
    TLP_FMT_3DW = 3'b000,
    TLP_FMT_4DW = 3'b001,
    TLP_FMT_3DW_DATA = 3'b010,
    TLP_FMT_4DW_DATA = 3'b011,
    TLP_FMT_PREFIX = 3'b100;

localparam [1:0]
    STATE_IDLE = 2'd0,
    STATE_READ_TBL_1 = 2'd1,
    STATE_READ_TBL_2 = 2'd2,
    STATE_SEND_TLP = 2'd3;

logic [1:0] state_reg = STATE_IDLE, state_next;

logic [IRQ_INDEX_W-1:0] irq_index_reg = '0, irq_index_next;

logic [63:0] vec_addr_reg = '0, vec_addr_next;
logic [31:0] vec_data_reg = '0, vec_data_next;
logic vec_mask_reg = 1'b0, vec_mask_next;

logic [127:0] tlp_hdr;

logic tbl_apb_mem_rd_en;
logic tbl_apb_mem_wr_en;
logic [7:0] tbl_apb_mem_wr_be;
logic [63:0] tbl_apb_mem_wr_data;
logic pba_apb_mem_rd_en;

logic tbl_mem_rd_en;
logic [TBL_ADDR_W-1:0] tbl_mem_addr;
logic pba_mem_rd_en;
logic pba_mem_wr_en;
logic [PBA_ADDR_W-1:0] pba_mem_addr;
logic [63:0] pba_mem_wr_data;

logic s_apb_pready_reg = 1'b0, s_apb_pready_next;
logic [APB_DATA_W-1:0] s_apb_prdata_reg = '0, s_apb_prdata_next;

logic irq_ready_reg = 1'b0, irq_ready_next;

logic [31:0] tx_wr_req_tlp_data_reg = '0, tx_wr_req_tlp_data_next;
logic [TLP_HDR_W-1:0] tx_wr_req_tlp_hdr_reg = '0, tx_wr_req_tlp_hdr_next;
logic tx_wr_req_tlp_valid_reg = 0, tx_wr_req_tlp_valid_next;

logic msix_enable_reg = 1'b0;
logic msix_mask_reg = 1'b0;

// MSI-X table
(* ramstyle = "no_rw_check, mlab" *)
logic [63:0] tbl_mem[2**TBL_ADDR_W];

// MSI-X PBA
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic [63:0] pba_mem[2**PBA_ADDR_W];

logic tbl_rd_data_valid_reg = 1'b0, tbl_rd_data_valid_next;
logic pba_rd_data_valid_reg = 1'b0, pba_rd_data_valid_next;
logic [WORD_SELECT_W-1:0] rd_data_shift_reg = '0, rd_data_shift_next;

logic [63:0] tbl_mem_rd_data_reg = '0;
logic [63:0] pba_mem_rd_data_reg = '0;
logic [63:0] tbl_apb_mem_rd_data_reg = '0;
logic [63:0] pba_apb_mem_rd_data_reg = '0;

wire [TBL_ADDR_W-1:0] s_apb_paddr_index = s_apb.paddr[INDEX_SHIFT +: TBL_ADDR_W];
wire [WORD_SELECT_W-1:0] s_apb_paddr_word = APB_DATA_W < 64 ? s_apb.paddr[WORD_SELECT_SHIFT +: WORD_SELECT_W] : 0;

assign s_apb.pready = s_apb_pready_reg;
assign s_apb.prdata = s_apb_prdata_reg;
assign s_apb.pslverr = 1'b0;
assign s_apb.pruser = '0;
assign s_apb.pbuser = '0;

assign s_axis_irq.tready = irq_ready_reg;

assign tx_wr_req_tlp.data = TLP_DATA_W'(tx_wr_req_tlp_data_reg);
assign tx_wr_req_tlp.empty = '1;
assign tx_wr_req_tlp.hdr = tx_wr_req_tlp_hdr_reg;
assign tx_wr_req_tlp.seq = '0;
assign tx_wr_req_tlp.bar_id = '0;
assign tx_wr_req_tlp.func_num = '0;
assign tx_wr_req_tlp.error = '0;
assign tx_wr_req_tlp.valid = tx_wr_req_tlp_valid_reg;
assign tx_wr_req_tlp.sop = 1'b1;
assign tx_wr_req_tlp.eop = 1'b1;

initial begin
    for (integer i = 0; i < 2**TBL_ADDR_W; i = i + 1) begin
        tbl_mem[i] = '0;
    end
    for (integer i = 0; i < 2**PBA_ADDR_W; i = i + 1) begin
        pba_mem[i] = '0;
    end
end

always_comb begin
    state_next = STATE_IDLE;

    tbl_mem_rd_en = 1'b0;
    tbl_mem_addr = {irq_index_reg, 1'b0};

    pba_mem_rd_en = 1'b0;
    pba_mem_wr_en = 1'b0;
    pba_mem_addr = PBA_ADDR_W_INT'(irq_index_reg >> 6);
    pba_mem_wr_data = '0;

    irq_index_next = irq_index_reg;

    vec_addr_next = vec_addr_reg;
    vec_data_next = vec_data_reg;
    vec_mask_next = vec_mask_reg;

    irq_ready_next = 1'b0;

    tx_wr_req_tlp_data_next = tx_wr_req_tlp_data_reg;
    tx_wr_req_tlp_hdr_next = tx_wr_req_tlp_hdr_reg;
    tx_wr_req_tlp_valid_next = tx_wr_req_tlp_valid_reg && !tx_wr_req_tlp.ready;

    // TLP header
    // DW 0
    if (((vec_addr_reg[63:2] >> 30) != 0) || TLP_FORCE_64_BIT_ADDR) begin
        tlp_hdr[127:125] = TLP_FMT_4DW_DATA; // fmt - 4DW with data
    end else begin
        tlp_hdr[127:125] = TLP_FMT_3DW_DATA; // fmt - 3DW with data
    end
    tlp_hdr[124:120] = 5'b00000; // type - write
    tlp_hdr[119] = 1'b0; // T9
    tlp_hdr[118:116] = 3'b000; // TC
    tlp_hdr[115] = 1'b0; // T8
    tlp_hdr[114] = 1'b0; // attr
    tlp_hdr[113] = 1'b0; // LN
    tlp_hdr[112] = 1'b0; // TH
    tlp_hdr[111] = 1'b0; // TD
    tlp_hdr[110] = 1'b0; // EP
    tlp_hdr[109:108] = 2'b00; // attr
    tlp_hdr[107:106] = 2'b00; // AT
    tlp_hdr[105:96] = 10'd1; // length
    // DW 1
    tlp_hdr[95:88] = bus_num; // requester ID (bus number)
    tlp_hdr[87:80] = func_num; // requester ID (device/function number)
    tlp_hdr[79:72] = 8'd0; // tag
    tlp_hdr[71:68] = 4'b0000; // last BE
    tlp_hdr[67:64] = 4'b1111; // first BE
    if ((vec_addr_reg[63:32] != 0) || TLP_FORCE_64_BIT_ADDR) begin
        // DW 2+3
        tlp_hdr[63:2] = vec_addr_reg[63:2]; // address
        tlp_hdr[1:0] = 2'b00; // PH
    end else begin
        // DW 2
        tlp_hdr[63:34] = vec_addr_reg[31:2]; // address
        tlp_hdr[33:32] = 2'b00; // PH
        // DW 3
        tlp_hdr[31:0] = 32'd0;
    end

    case (state_reg)
        STATE_IDLE: begin
            irq_ready_next = 1'b1;

            if (s_axis_irq.tvalid && s_axis_irq.tready) begin
                // new request
                irq_ready_next = 1'b0;
                irq_index_next = s_axis_irq.tdata;

                tbl_mem_rd_en = 1'b1;
                tbl_mem_addr = {irq_index_next, 1'b0};

                pba_mem_rd_en = 1'b1;
                pba_mem_addr = PBA_ADDR_W_INT'(irq_index_next >> 6);

                state_next = STATE_READ_TBL_1;
            end else if (!s_axis_irq.tvalid && msix_enable_reg && !msix_mask_reg) begin
                // no new request waiting, scan PBA for masked requests

                if (pba_mem_rd_data_reg[6'(irq_index_reg)] != 0) begin
                    // PBA bit for current index is set, try issuing it
                    irq_ready_next = 1'b0;

                    tbl_mem_rd_en = 1'b1;
                    tbl_mem_addr = {irq_index_next, 1'b0};

                    pba_mem_rd_en = 1'b1;
                    pba_mem_addr = PBA_ADDR_W_INT'(irq_index_next >> 6);

                    state_next = STATE_READ_TBL_1;
                end else begin
                    // PBA bit for current index is not set
                    if (pba_mem_rd_data_reg != 0) begin
                        // at least one bit set in current group, move to next index
                        irq_index_next = irq_index_reg + 1;
                    end else begin
                        // no bits set in current group, move to next group
                        irq_index_next = (irq_index_reg & ({IRQ_INDEX_W{1'b1}} << 6)) + 'd64;
                    end

                    pba_mem_rd_en = 1'b1;
                    pba_mem_addr = PBA_ADDR_W_INT'(irq_index_next >> 6);

                    state_next = STATE_IDLE;
                end
            end else begin
                state_next = STATE_IDLE;
            end
        end
        STATE_READ_TBL_1: begin
            // handle first table read
            tbl_mem_rd_en = 1'b1;
            tbl_mem_addr = {irq_index_reg, 1'b1};

            vec_addr_next = {tbl_mem_rd_data_reg[63:2], 2'b00};

            state_next = STATE_READ_TBL_2;
        end
        STATE_READ_TBL_2: begin
            // handle second table read
            vec_data_next = tbl_mem_rd_data_reg[31:0];
            vec_mask_next = tbl_mem_rd_data_reg[32];

            if (msix_enable_reg && !msix_mask_reg && !vec_mask_next) begin
                // send TLP
                state_next = STATE_SEND_TLP;
            end else begin
                // set PBA bit
                pba_mem_wr_en = 1'b1;
                pba_mem_wr_data = pba_mem_rd_data_reg | (1 << 6'(irq_index_reg));
                irq_ready_next = 1'b1;
                state_next = STATE_IDLE;
            end
        end
        STATE_SEND_TLP: begin
            if (!tx_wr_req_tlp.valid || tx_wr_req_tlp.ready) begin
                // send TLP
                tx_wr_req_tlp_data_next = vec_data_reg;
                tx_wr_req_tlp_hdr_next = tlp_hdr;
                tx_wr_req_tlp_valid_next = 1'b1;

                // clear PBA bit
                pba_mem_wr_en = 1'b1;
                pba_mem_wr_data = pba_mem_rd_data_reg & ~(1 << 6'(irq_index_reg));

                // increment index so we don't check the same PBA bit immediately
                irq_index_next = irq_index_reg + 1;

                irq_ready_next = 1'b1;
                state_next = STATE_IDLE;
            end else begin
                state_next = STATE_SEND_TLP;
            end
        end
    endcase
end

always_ff @(posedge clk) begin
    state_reg <= state_next;

    irq_index_reg <= irq_index_next;

    vec_addr_reg <= vec_addr_next;
    vec_data_reg <= vec_data_next;
    vec_mask_reg <= vec_mask_next;

    irq_ready_reg <= irq_ready_next;

    tx_wr_req_tlp_data_reg <= tx_wr_req_tlp_data_next;
    tx_wr_req_tlp_hdr_reg <= tx_wr_req_tlp_hdr_next;
    tx_wr_req_tlp_valid_reg <= tx_wr_req_tlp_valid_next;

    msix_enable_reg <= msix_enable;
    msix_mask_reg <= msix_mask;

    if (tbl_mem_rd_en) begin
        tbl_mem_rd_data_reg <= tbl_mem[tbl_mem_addr];
    end

    if (pba_mem_wr_en) begin
        pba_mem[pba_mem_addr] <= pba_mem_wr_data;
    end else if (pba_mem_rd_en) begin
        pba_mem_rd_data_reg <= pba_mem[pba_mem_addr];
    end

    if (rst) begin
        state_reg <= STATE_IDLE;

        irq_ready_reg <= 1'b0;

        tx_wr_req_tlp_valid_reg <= 1'b0;
    end
end

// APB interface
always_comb begin
    tbl_apb_mem_rd_en = 1'b0;
    tbl_apb_mem_wr_en = 1'b0;
    tbl_apb_mem_wr_be = 8'(s_apb.pstrb << (s_apb_paddr_word * APB_STRB_W));
    tbl_apb_mem_wr_data = {2**WORD_SELECT_W{s_apb.pwdata}};
    pba_apb_mem_rd_en = 1'b0;

    tbl_rd_data_valid_next = 1'b0;
    pba_rd_data_valid_next = 1'b0;
    rd_data_shift_next = rd_data_shift_reg;

    s_apb_pready_next = 1'b0;
    s_apb_prdata_next = s_apb_prdata_reg;

    if (tbl_rd_data_valid_reg || pba_rd_data_valid_reg) begin
        s_apb_pready_next = !s_apb_pready_reg;
        tbl_rd_data_valid_next = 1'b0;
        pba_rd_data_valid_next = 1'b0;

        if (tbl_rd_data_valid_reg) begin
            if (APB_DATA_W < 64) begin
                s_apb_prdata_next = APB_DATA_W'(tbl_apb_mem_rd_data_reg >> rd_data_shift_reg*APB_DATA_W);
            end else begin
                s_apb_prdata_next = APB_DATA_W'(tbl_apb_mem_rd_data_reg);
            end
        end else begin
            if (APB_DATA_W < 64) begin
                s_apb_prdata_next = APB_DATA_W'(pba_apb_mem_rd_data_reg >> rd_data_shift_reg*APB_DATA_W);
            end else begin
                s_apb_prdata_next = APB_DATA_W'(pba_apb_mem_rd_data_reg);
            end
        end
    end

    if (s_apb.psel && s_apb.penable) begin
        rd_data_shift_next = s_apb_paddr_word;

        if (s_apb.pwrite) begin
            s_apb_pready_next = !s_apb_pready_reg;
            if (s_apb.paddr[IRQ_INDEX_W+5-1] == 0) begin
                tbl_apb_mem_wr_en = !s_apb_pready_reg;
            end
        end else begin
            if (s_apb.paddr[IRQ_INDEX_W+5-1] == 0) begin
                tbl_apb_mem_rd_en = 1'b1;
                tbl_rd_data_valid_next = !s_apb_pready_reg;
            end else begin
                pba_apb_mem_rd_en = 1'b1;
                pba_rd_data_valid_next = !s_apb_pready_reg;
            end
        end
    end
end

always_ff @(posedge clk) begin
    tbl_rd_data_valid_reg <= tbl_rd_data_valid_next;
    pba_rd_data_valid_reg <= pba_rd_data_valid_next;
    rd_data_shift_reg <= rd_data_shift_next;

    s_apb_pready_reg <= s_apb_pready_next;
    s_apb_prdata_reg <= s_apb_prdata_next;

    if (tbl_apb_mem_rd_en) begin
        tbl_apb_mem_rd_data_reg <= tbl_mem[s_apb_paddr_index];
    end else begin
        for (integer i = 0; i < 8; i = i + 1) begin
            if (tbl_apb_mem_wr_en && tbl_apb_mem_wr_be[i]) begin
                tbl_mem[s_apb_paddr_index][8*i +: 8] <= tbl_apb_mem_wr_data[8*i +: 8];
            end
        end
    end

    if (pba_apb_mem_rd_en) begin
        pba_apb_mem_rd_data_reg <= pba_mem[s_apb_paddr_index[PBA_ADDR_W-1:0]];
    end

    if (rst) begin
        tbl_rd_data_valid_reg <= 1'b0;
        pba_rd_data_valid_reg <= 1'b0;

        s_apb_pready_reg <= 1'b0;
    end
end

endmodule

`resetall
