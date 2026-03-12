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
 * Corundum-micro queue state manager module
 */
module cndm_micro_queue_state #(
    parameter QN_W = 5,
    parameter DQN_W = 5,
    parameter logic IS_CQ = 1'b0,
    parameter logic IS_EQ = 1'b0,
    parameter logic CQ_IRQ = IS_CQ,
    parameter logic QTYPE_EN = 1'b1,
    parameter QE_SIZE = 16,
    parameter DMA_ADDR_W = 64
)
(
    input  wire logic                   clk,
    input  wire logic                   rst,

    /*
     * Control register interface
     */
    taxi_axil_if.wr_slv                 s_axil_ctrl_wr,
    taxi_axil_if.rd_slv                 s_axil_ctrl_rd,

    /*
     * Datapath control register interface
     */
    taxi_apb_if.slv                     s_apb_dp_ctrl,

    /*
     * Queue management interface
     */
    input  wire logic [QN_W-1:0]        req_qn,
    input  wire logic [2:0]             req_qtype,
    input  wire logic                   req_valid,
    output wire logic                   req_ready,
    output wire logic [QN_W-1:0]        rsp_qn,
    output wire logic [DQN_W-1:0]       rsp_dqn,
    output wire logic [DMA_ADDR_W-1:0]  rsp_addr,
    output wire logic                   rsp_phase_tag,
    output wire logic                   rsp_error,
    output wire logic                   rsp_valid,
    input  wire logic                   rsp_ready,

    /*
     * Notification interface
     */
    input  wire logic [QN_W-1:0]        notify_req_qn,
    input  wire logic                   notify_req_valid,
    output wire logic                   notify_req_ready,

    /*
     * Interrupts
     */
    taxi_axis_if.src                    m_axis_irq,

    /*
     * Event output
     */
    taxi_axis_if.src                    m_axis_event
);

localparam PTR_W = 16;

localparam ADDR_W = QN_W+5;

localparam AXIL_ADDR_W = s_axil_ctrl_wr.ADDR_W;
localparam AXIL_DATA_W = s_axil_ctrl_wr.DATA_W;

localparam APB_ADDR_W = s_apb_dp_ctrl.ADDR_W;
localparam APB_DATA_W = s_apb_dp_ctrl.DATA_W;

localparam IRQN_W = m_axis_irq.DATA_W;

localparam EQN_W = m_axis_event.DEST_W;
localparam EVENT_DATA_W = 64;
localparam EVENT_DEST_W = m_axis_event.DEST_W;

// check configuration
if (s_axil_ctrl_rd.DATA_W != 32 || s_axil_ctrl_wr.DATA_W != 32)
    $fatal(0, "Error: AXI data width must be 32 (instance %m)");

if (s_axil_ctrl_rd.ADDR_W < ADDR_W || s_axil_ctrl_wr.ADDR_W < ADDR_W)
    $fatal(0, "Error: AXI address width is insufficient (instance %m)");

if (s_apb_dp_ctrl.DATA_W != 32)
    $fatal(0, "Error: APB data width must be 32 (instance %m)");

if (s_apb_dp_ctrl.ADDR_W < ADDR_W)
    $fatal(0, "Error: APB address width is insufficient (instance %m)");

typedef enum logic [2:0] {
    QTYPE_EQ,
    QTYPE_CQ,
    QTYPE_SQ,
    QTYPE_RQ
} qtype_t;

logic s_axil_ctrl_awready_reg = 1'b0, s_axil_ctrl_awready_next;
logic s_axil_ctrl_wready_reg = 1'b0, s_axil_ctrl_wready_next;
logic s_axil_ctrl_bvalid_reg = 1'b0, s_axil_ctrl_bvalid_next;

logic s_axil_ctrl_arready_reg = 1'b0, s_axil_ctrl_arready_next;
logic [AXIL_DATA_W-1:0] s_axil_ctrl_rdata_reg = '0, s_axil_ctrl_rdata_next;
logic s_axil_ctrl_rvalid_reg = 1'b0, s_axil_ctrl_rvalid_next;

assign s_axil_ctrl_wr.awready = s_axil_ctrl_awready_reg;
assign s_axil_ctrl_wr.wready = s_axil_ctrl_wready_reg;
assign s_axil_ctrl_wr.bresp = '0;
assign s_axil_ctrl_wr.buser = '0;
assign s_axil_ctrl_wr.bvalid = s_axil_ctrl_bvalid_reg;

assign s_axil_ctrl_rd.arready = s_axil_ctrl_arready_reg;
assign s_axil_ctrl_rd.rdata = s_axil_ctrl_rdata_reg;
assign s_axil_ctrl_rd.rresp = '0;
assign s_axil_ctrl_rd.ruser = '0;
assign s_axil_ctrl_rd.rvalid = s_axil_ctrl_rvalid_reg;

wire [QN_W-1:0] s_axil_ctrl_awaddr_queue_index = s_axil_ctrl_wr.awaddr[5 +: QN_W];
wire [2:0] s_axil_ctrl_awaddr_reg_index = s_axil_ctrl_wr.awaddr[4:2];
wire [QN_W-1:0] s_axil_ctrl_araddr_queue_index = s_axil_ctrl_rd.araddr[5 +: QN_W];
wire [2:0] s_axil_ctrl_araddr_reg_index = s_axil_ctrl_rd.araddr[4:2];

logic s_apb_dp_ctrl_pready_reg = 1'b0, s_apb_dp_ctrl_pready_next;
logic [AXIL_DATA_W-1:0] s_apb_dp_ctrl_prdata_reg = '0, s_apb_dp_ctrl_prdata_next;

assign s_apb_dp_ctrl.pready = s_apb_dp_ctrl_pready_reg;
assign s_apb_dp_ctrl.prdata = s_apb_dp_ctrl_prdata_reg;
assign s_apb_dp_ctrl.pslverr = 1'b0;
assign s_apb_dp_ctrl.pruser = '0;
assign s_apb_dp_ctrl.pbuser = '0;

wire [QN_W-1:0] s_apb_dp_ctrl_paddr_queue_index = s_apb_dp_ctrl.paddr[5 +: QN_W];
wire [2:0] s_apb_dp_ctrl_paddr_reg_index = s_apb_dp_ctrl.paddr[4:2];

logic req_ready_reg = 1'b0, req_ready_next;
logic [QN_W-1:0] rsp_qn_reg = '0, rsp_qn_next;
logic [DQN_W-1:0] rsp_dqn_reg = '0, rsp_dqn_next;
logic [DMA_ADDR_W-1:0] rsp_addr_reg = '0, rsp_addr_next;
logic rsp_phase_tag_reg = 1'b0, rsp_phase_tag_next;
logic rsp_error_reg = 1'b0, rsp_error_next;
logic rsp_valid_reg = 1'b0, rsp_valid_next;

assign req_ready = req_ready_reg;
assign rsp_qn = rsp_qn_reg;
assign rsp_dqn = rsp_dqn_reg;
assign rsp_addr = rsp_addr_reg;
assign rsp_phase_tag = rsp_phase_tag_reg;
assign rsp_error = rsp_error_reg;
assign rsp_valid = rsp_valid_reg;

logic notify_req_ready_reg = 1'b0, notify_req_ready_next;

assign notify_req_ready = notify_req_ready_reg;

logic [IRQN_W-1:0] m_axis_irq_irqn_reg = '0, m_axis_irq_irqn_next;
logic m_axis_irq_tvalid_reg = 1'b0, m_axis_irq_tvalid_next;

assign m_axis_irq.tdata  = m_axis_irq_irqn_reg;
assign m_axis_irq.tkeep  = '1;
assign m_axis_irq.tstrb  = m_axis_irq.tkeep;
assign m_axis_irq.tvalid = m_axis_irq_tvalid_reg;
assign m_axis_irq.tlast  = 1'b1;
assign m_axis_irq.tid    = '0;
assign m_axis_irq.tdest  = '0;
assign m_axis_irq.tuser  = '0;

logic [EVENT_DATA_W-1:0] m_axis_event_tdata_reg = '0, m_axis_event_tdata_next;
logic [EQN_W-1:0] m_axis_event_tdest_reg = '0, m_axis_event_tdest_next;
logic m_axis_event_tvalid_reg = 1'b0, m_axis_event_tvalid_next;

assign m_axis_event.tdata  = m_axis_event.DATA_W'(m_axis_event_tdata_reg);
assign m_axis_event.tkeep  = '1;
assign m_axis_event.tstrb  = m_axis_event.tkeep;
assign m_axis_event.tvalid = m_axis_event_tvalid_reg;
assign m_axis_event.tlast  = 1'b1;
assign m_axis_event.tid    = '0;
assign m_axis_event.tdest  = m_axis_event_tdest_reg;
assign m_axis_event.tuser  = '0;

(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic queue_mem_enable[2**QN_W] = '{default: '0};
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic queue_mem_arm[2**QN_W] = '{default: '0};
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic queue_mem_fire[2**QN_W] = '{default: '0};
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic queue_mem_cq_irq[2**QN_W] = '{default: '0};
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic [2:0] queue_mem_qtype[2**QN_W] = '{default: '0};
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic [DQN_W-1:0] queue_mem_dqn[2**QN_W] = '{default: '0};
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic [3:0] queue_mem_log_size[2**QN_W] = '{default: '0};
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic [DMA_ADDR_W-1:0] queue_mem_base_addr[2**QN_W] = '{default: '0};
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic [PTR_W-1:0] queue_mem_prod_ptr[2**QN_W] = '{default: '0};
(* ram_style = "distributed", ramstyle = "no_rw_check, mlab" *)
logic [PTR_W-1:0] queue_mem_cons_ptr[2**QN_W] = '{default: '0};

logic queue_mem_wr_en;
logic [QN_W-1:0] queue_mem_addr_reg = '0, queue_mem_addr_next;

wire queue_mem_rd_enable = queue_mem_enable[queue_mem_addr_reg];
wire queue_mem_rd_arm = queue_mem_arm[queue_mem_addr_reg];
wire queue_mem_rd_fire = queue_mem_fire[queue_mem_addr_reg];
wire queue_mem_rd_cq_irq = queue_mem_cq_irq[queue_mem_addr_reg];
wire [2:0] queue_mem_rd_qtype = queue_mem_qtype[queue_mem_addr_reg];
wire [DQN_W-1:0] queue_mem_rd_dqn = queue_mem_dqn[queue_mem_addr_reg];
wire [3:0] queue_mem_rd_log_size = queue_mem_log_size[queue_mem_addr_reg];
wire [DMA_ADDR_W-1:0] queue_mem_rd_base_addr = queue_mem_base_addr[queue_mem_addr_reg];
wire [PTR_W-1:0] queue_mem_rd_prod_ptr = queue_mem_prod_ptr[queue_mem_addr_reg];
wire [PTR_W-1:0] queue_mem_rd_cons_ptr = queue_mem_cons_ptr[queue_mem_addr_reg];

wire queue_mem_rd_status_empty = queue_mem_rd_prod_ptr == queue_mem_rd_cons_ptr;
wire queue_mem_rd_status_full = ($unsigned(queue_mem_rd_prod_ptr - queue_mem_rd_cons_ptr) & ({PTR_W{1'b1}} << queue_mem_rd_log_size)) != 0;

logic queue_mem_wr_enable;
logic queue_mem_wr_arm;
logic queue_mem_wr_fire;
logic queue_mem_wr_cq_irq;
logic [2:0] queue_mem_wr_qtype;
logic [DQN_W-1:0] queue_mem_wr_dqn;
logic [3:0] queue_mem_wr_log_size;
logic [DMA_ADDR_W-1:0] queue_mem_wr_base_addr;
logic [PTR_W-1:0] queue_mem_wr_prod_ptr;
logic [PTR_W-1:0] queue_mem_wr_cons_ptr;

logic [QN_W-1:0] scrub_ptr_reg = '0, scrub_ptr_next;

typedef enum logic [2:0] {
    STATE_INIT,
    STATE_IDLE,
    STATE_AXIL_WR,
    STATE_APB,
    STATE_NOTIFY,
    STATE_REQ,
    STATE_SCRUB
} state_t;

state_t state_reg = STATE_INIT, state_next;

always_comb begin
    state_next = STATE_INIT;

    s_axil_ctrl_awready_next = 1'b0;
    s_axil_ctrl_wready_next = 1'b0;
    s_axil_ctrl_bvalid_next = 1'b0;

    s_axil_ctrl_arready_next = 1'b0;
    s_axil_ctrl_rdata_next = s_axil_ctrl_rdata_reg;
    s_axil_ctrl_rvalid_next = 1'b0;

    s_apb_dp_ctrl_pready_next = 1'b0;
    s_apb_dp_ctrl_prdata_next = s_apb_dp_ctrl_prdata_reg;

    req_ready_next = 1'b0;
    rsp_qn_next = rsp_qn_reg;
    rsp_dqn_next = rsp_dqn_reg;
    rsp_addr_next = rsp_addr_reg;
    rsp_phase_tag_next = rsp_phase_tag_reg;
    rsp_error_next = rsp_error_reg;
    rsp_valid_next = rsp_valid_reg && !rsp_ready;

    notify_req_ready_next = 1'b0;

    m_axis_irq_irqn_next = m_axis_irq_irqn_reg;
    m_axis_irq_tvalid_next = m_axis_irq_tvalid_reg && !m_axis_irq.tready;

    m_axis_event_tdata_next = m_axis_event_tdata_reg;
    m_axis_event_tdest_next = m_axis_event_tdest_reg;
    m_axis_event_tvalid_next = m_axis_event_tvalid_reg && !m_axis_event.tready;

    queue_mem_wr_en = 1'b0;
    queue_mem_addr_next = queue_mem_addr_reg;

    queue_mem_wr_enable = queue_mem_rd_enable;
    queue_mem_wr_arm = queue_mem_rd_arm;
    queue_mem_wr_fire = queue_mem_rd_fire;
    queue_mem_wr_cq_irq = queue_mem_rd_cq_irq;
    queue_mem_wr_qtype = queue_mem_rd_qtype;
    queue_mem_wr_dqn = queue_mem_rd_dqn;
    queue_mem_wr_log_size = queue_mem_rd_log_size;
    queue_mem_wr_base_addr = queue_mem_rd_base_addr;
    queue_mem_wr_prod_ptr = queue_mem_rd_prod_ptr;
    queue_mem_wr_cons_ptr = queue_mem_rd_cons_ptr;

    scrub_ptr_next = scrub_ptr_reg;

    // terminate AXI lite reads
    if (s_axil_ctrl_rd.arvalid && !s_axil_ctrl_rvalid_reg) begin
        s_axil_ctrl_rdata_next = '0;

        s_axil_ctrl_arready_next = 1'b1;
        s_axil_ctrl_rvalid_next = 1'b1;
    end

    case (state_reg)
        STATE_INIT: begin
            // initialize queue RAM

            queue_mem_wr_en = 1'b1;

            queue_mem_wr_enable = 1'b0;
            queue_mem_wr_arm = 1'b0;
            queue_mem_wr_fire = 1'b0;
            queue_mem_wr_cq_irq = 1'b0;
            queue_mem_wr_qtype = '0;
            queue_mem_wr_dqn = '0;
            queue_mem_wr_log_size = '0;
            queue_mem_wr_base_addr = '0;
            queue_mem_wr_prod_ptr = '0;
            queue_mem_wr_cons_ptr = '0;

            queue_mem_addr_next = queue_mem_addr_reg + 1;

            if (&queue_mem_addr_reg) begin
                state_next = STATE_IDLE;
            end else begin
                state_next = STATE_INIT;
            end
        end
        STATE_IDLE: begin
            // Start new operation

            if (s_axil_ctrl_wr.awvalid && s_axil_ctrl_wr.wvalid && !s_axil_ctrl_bvalid_reg) begin
                // AXIL write

                queue_mem_addr_next = s_axil_ctrl_awaddr_queue_index;
                // s_axil_ctrl_awaddr_reg_index

                state_next = STATE_AXIL_WR;
            end else if (s_apb_dp_ctrl.psel && !s_apb_dp_ctrl_pready_reg) begin
                // APB read/write

                queue_mem_addr_next = s_apb_dp_ctrl_paddr_queue_index;
                // s_apb_dp_ctrl.pwrite
                // s_apb_dp_ctrl_paddr_reg_index

                state_next = STATE_APB;
            end else if (notify_req_valid && !notify_req_ready) begin
                // Notify request
                notify_req_ready_next = 1'b1;

                queue_mem_addr_next = notify_req_qn;

                state_next = STATE_NOTIFY;
            end else if (req_valid && !req_ready && (!rsp_valid || rsp_ready)) begin
                // Queue op request

                queue_mem_addr_next = req_qn;
                // req_qtype

                state_next = STATE_REQ;
            end else begin
                // Scrub

                queue_mem_addr_next = scrub_ptr_reg;

                state_next = STATE_SCRUB;
            end
        end
        STATE_AXIL_WR: begin
            // AXIL write
            s_axil_ctrl_awready_next = 1'b1;
            s_axil_ctrl_wready_next = 1'b1;
            s_axil_ctrl_bvalid_next = 1'b1;

            queue_mem_wr_en = 1'b1;

            case (s_axil_ctrl_awaddr_reg_index)
                3'd2: begin
                    if (!IS_CQ && !IS_EQ) begin
                        queue_mem_wr_prod_ptr = s_axil_ctrl_wr.wdata[15:0];
                    end
                end
                3'd3: begin
                    if (IS_CQ || IS_EQ) begin
                        queue_mem_wr_cons_ptr = s_axil_ctrl_wr.wdata[15:0];
                        if (s_axil_ctrl_wr.wdata[31]) begin
                            queue_mem_wr_arm = 1'b1;
                        end
                    end
                end
                default: begin end
            endcase

            // go to scrub state to attempt generating event/IRQ immediately
            state_next = STATE_SCRUB;
        end
        STATE_APB: begin
            // APB read/write
            s_apb_dp_ctrl_pready_next = 1'b1;
            s_apb_dp_ctrl_prdata_next = '0;

            if (s_apb_dp_ctrl.pwrite) begin
                queue_mem_wr_en = 1'b1;

                case (s_apb_dp_ctrl_paddr_reg_index)
                    3'd0: begin
                        queue_mem_wr_enable = s_apb_dp_ctrl.pwdata[0];
                        queue_mem_wr_arm = s_apb_dp_ctrl.pwdata[1];
                        queue_mem_wr_log_size = s_apb_dp_ctrl.pwdata[19:16];
                        queue_mem_wr_qtype = 3'(s_apb_dp_ctrl.pwdata[23:20]);

                        queue_mem_wr_fire = 1'b0;
                    end
                    3'd1: begin
                        queue_mem_wr_dqn = s_apb_dp_ctrl.pwdata[DQN_W-1:0];
                        queue_mem_wr_cq_irq = s_apb_dp_ctrl.pwdata[31];
                    end
                    3'd2: queue_mem_wr_prod_ptr = s_apb_dp_ctrl.pwdata[15:0];
                    3'd3: begin
                        queue_mem_wr_cons_ptr = s_apb_dp_ctrl.pwdata[15:0];
                        if (s_apb_dp_ctrl.pwdata[31]) begin
                            // rearm
                            queue_mem_wr_arm = 1'b1;
                        end
                    end
                    3'd6: queue_mem_wr_base_addr[31:0] = s_apb_dp_ctrl.pwdata;
                    3'd7: queue_mem_wr_base_addr[63:32] = s_apb_dp_ctrl.pwdata;
                    default: begin end
                endcase
            end

            case (s_apb_dp_ctrl_paddr_reg_index)
                3'd0: begin
                    s_apb_dp_ctrl_prdata_next[0] = queue_mem_rd_enable;
                    s_apb_dp_ctrl_prdata_next[1] = (IS_CQ || IS_EQ) ? queue_mem_rd_arm : 1'b0;
                    s_apb_dp_ctrl_prdata_next[19:16] = queue_mem_rd_log_size;
                    s_apb_dp_ctrl_prdata_next[23:20] = QTYPE_EN ? 4'(queue_mem_rd_qtype) : '0;
                end
                3'd1: begin
                    s_apb_dp_ctrl_prdata_next[30:0] = 31'(queue_mem_rd_dqn);
                    s_apb_dp_ctrl_prdata_next[31] = (IS_CQ && CQ_IRQ) ? queue_mem_rd_cq_irq : 1'b0;
                end
                3'd2: s_apb_dp_ctrl_prdata_next = 32'(queue_mem_rd_prod_ptr);
                3'd3: s_apb_dp_ctrl_prdata_next = 32'(queue_mem_rd_cons_ptr);
                3'd6: s_apb_dp_ctrl_prdata_next = queue_mem_rd_base_addr[31:0];
                3'd7: s_apb_dp_ctrl_prdata_next = queue_mem_rd_base_addr[63:32];
                default: begin end
            endcase

            state_next = STATE_IDLE;
        end
        STATE_NOTIFY: begin
            // Notify request

            queue_mem_wr_fire = 1'b1;
            queue_mem_wr_en = 1'b1;

            // go to scrub state to attempt generating event/IRQ immediately
            state_next = STATE_SCRUB;
        end
        STATE_REQ: begin
            // Queue op request
            req_ready_next = 1'b1;

            rsp_qn_next = queue_mem_addr_reg;
            rsp_dqn_next = queue_mem_rd_dqn;
            rsp_error_next = !queue_mem_rd_enable || (QTYPE_EN && req_qtype != queue_mem_rd_qtype);
            if (IS_CQ || IS_EQ) begin
                rsp_addr_next = queue_mem_rd_base_addr + DMA_ADDR_W'(16'(queue_mem_rd_prod_ptr & ({16{1'b1}} >> (16 - queue_mem_rd_log_size))) * QE_SIZE);
                rsp_phase_tag_next = !queue_mem_rd_prod_ptr[queue_mem_rd_log_size];
                if (queue_mem_rd_status_full)
                    rsp_error_next = 1'b1;
                queue_mem_wr_prod_ptr = queue_mem_rd_prod_ptr + 1;
            end else begin
                rsp_addr_next = queue_mem_rd_base_addr + DMA_ADDR_W'(16'(queue_mem_rd_cons_ptr & ({16{1'b1}} >> (16 - queue_mem_rd_log_size))) * QE_SIZE);
                if (queue_mem_rd_status_empty)
                    rsp_error_next = 1'b1;
                queue_mem_wr_cons_ptr = queue_mem_rd_cons_ptr + 1;
            end
            rsp_valid_next = 1'b1;

            if (!rsp_error_next) begin
                queue_mem_wr_en = 1'b1;
            end

            state_next = STATE_IDLE;
        end
        STATE_SCRUB: begin
            // Scrub

            if ((IS_CQ || IS_EQ) && queue_mem_rd_enable && queue_mem_rd_arm && queue_mem_rd_fire) begin
                if ((IS_CQ && !IS_EQ && (!CQ_IRQ || !queue_mem_rd_cq_irq)) || (QTYPE_EN && queue_mem_rd_qtype == QTYPE_CQ && (!CQ_IRQ || !queue_mem_rd_cq_irq))) begin
                    // event - only for CQ
                    if (!m_axis_event_tvalid_reg || m_axis_event.tready) begin
                        // fire in the hole

                        m_axis_event_tdata_next = '0;
                        m_axis_event_tdata_next[15:0] = '0; // rsvd
                        m_axis_event_tdata_next[31:16] = '0; // CPL
                        m_axis_event_tdata_next[63:32] = 32'(queue_mem_addr_reg); // CQN
                        m_axis_event_tdest_next = EQN_W'(queue_mem_rd_dqn);
                        m_axis_event_tvalid_next = 1'b1;

                        queue_mem_wr_arm = 1'b0;
                        queue_mem_wr_fire = 1'b0;
                        queue_mem_wr_en = 1'b1;
                    end
                end else if ((!IS_CQ && IS_EQ) || (IS_CQ && !IS_EQ && (CQ_IRQ && queue_mem_rd_cq_irq)) || (QTYPE_EN && (queue_mem_rd_qtype == QTYPE_EQ || (queue_mem_rd_qtype == QTYPE_CQ && (CQ_IRQ && queue_mem_rd_cq_irq))))) begin
                    // interrupt - EQ or CQ, but CQ requires config bit set to select interrupts
                    if (!m_axis_irq_tvalid_reg || m_axis_irq.tready) begin
                        // fire in the hole

                        m_axis_irq_irqn_next = IRQN_W'(queue_mem_rd_dqn);
                        m_axis_irq_tvalid_next = 1'b1;

                        queue_mem_wr_arm = 1'b0;
                        queue_mem_wr_fire = 1'b0;
                        queue_mem_wr_en = 1'b1;
                    end
                end
            end

            if (scrub_ptr_reg == queue_mem_addr_reg) begin
                scrub_ptr_next = scrub_ptr_reg + 1;
            end

            state_next = STATE_IDLE;
        end
        default: begin
            // invalid state
            state_next = STATE_INIT;
        end
    endcase
end

always @(posedge clk) begin
    state_reg <= state_next;

    s_axil_ctrl_awready_reg <= s_axil_ctrl_awready_next;
    s_axil_ctrl_wready_reg <= s_axil_ctrl_wready_next;
    s_axil_ctrl_bvalid_reg <= s_axil_ctrl_bvalid_next;

    s_axil_ctrl_arready_reg <= s_axil_ctrl_arready_next;
    s_axil_ctrl_rdata_reg <= s_axil_ctrl_rdata_next;
    s_axil_ctrl_rvalid_reg <= s_axil_ctrl_rvalid_next;

    s_apb_dp_ctrl_pready_reg <= s_apb_dp_ctrl_pready_next;
    s_apb_dp_ctrl_prdata_reg <= s_apb_dp_ctrl_prdata_next;

    req_ready_reg <= req_ready_next;
    rsp_qn_reg <= rsp_qn_next;
    rsp_dqn_reg <= rsp_dqn_next;
    rsp_addr_reg <= rsp_addr_next;
    rsp_phase_tag_reg <= rsp_phase_tag_next;
    rsp_error_reg <= rsp_error_next;
    rsp_valid_reg <= rsp_valid_next;

    notify_req_ready_reg <= notify_req_ready_next;

    m_axis_irq_irqn_reg <= m_axis_irq_irqn_next;
    m_axis_irq_tvalid_reg <= m_axis_irq_tvalid_next;

    m_axis_event_tdata_reg <= m_axis_event_tdata_next;
    m_axis_event_tdest_reg <= m_axis_event_tdest_next;
    m_axis_event_tvalid_reg <= m_axis_event_tvalid_next;

    scrub_ptr_reg <= scrub_ptr_next;

    queue_mem_addr_reg <= queue_mem_addr_next;
    if (queue_mem_wr_en) begin
        queue_mem_enable[queue_mem_addr_reg] <= queue_mem_wr_enable;
        queue_mem_arm[queue_mem_addr_reg] <= queue_mem_wr_arm;
        queue_mem_fire[queue_mem_addr_reg] <= queue_mem_wr_fire;
        queue_mem_cq_irq[queue_mem_addr_reg] <= queue_mem_wr_cq_irq;
        queue_mem_qtype[queue_mem_addr_reg] <= queue_mem_wr_qtype;
        queue_mem_dqn[queue_mem_addr_reg] <= queue_mem_wr_dqn;
        queue_mem_log_size[queue_mem_addr_reg] <= queue_mem_wr_log_size;
        queue_mem_base_addr[queue_mem_addr_reg] <= queue_mem_wr_base_addr;
        queue_mem_prod_ptr[queue_mem_addr_reg] <= queue_mem_wr_prod_ptr;
        queue_mem_cons_ptr[queue_mem_addr_reg] <= queue_mem_wr_cons_ptr;
    end

    if (rst) begin
        state_reg <= STATE_INIT;

        s_axil_ctrl_awready_reg <= 1'b0;
        s_axil_ctrl_wready_reg <= 1'b0;
        s_axil_ctrl_bvalid_reg <= 1'b0;

        s_axil_ctrl_arready_reg <= 1'b0;
        s_axil_ctrl_rvalid_reg <= 1'b0;

        s_apb_dp_ctrl_pready_reg <= 1'b0;

        req_ready_reg <= 1'b0;
        rsp_valid_reg <= 1'b0;

        notify_req_ready_reg <= 1'b0;

        m_axis_irq_tvalid_reg <= 1'b0;

        m_axis_event_tvalid_reg <= 1'b0;

        scrub_ptr_reg <= '0;

        queue_mem_addr_reg <= '0;
    end
end

endmodule

`resetall
