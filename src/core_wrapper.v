//
module core_wrapper (
         input wire clock,
         input wire resetn,
         input wire int_req0,
         input wire int_req1,
         input wire int_req2,
         input wire int_req3,
         input wire int_req4,
         input wire int_req5,

         output
         wire[3:0]   m_axi_awid,
         wire[31:0]  m_axi_awaddr,
         wire[3:0]   m_axi_awlen,
         wire[2:0]   m_axi_awsize,
         wire[1:0]   m_axi_awburst,
         wire[1:0]   m_axi_awlock,
         wire[3:0]   m_axi_awcache,
         wire[2:0]   m_axi_awprot,
         output wire m_axi_awvalid,
         input
         wire    m_axi_awready,

         // write data channel signals
         output
         wire[3:0]    m_axi_wid,
         wire[31:0]   m_axi_wdata,
         wire[3:0]   m_axi_wstrb,
         output wire        m_axi_wlast,
         wire        m_axi_wvalid,
         input       m_axi_wready,

         // write response channel signals
         input
         wire[3:0]   m_axi_bid,
         wire[1:0]   m_axi_bresp,
         input wire  m_axi_bvalid,
         output
         wire        m_axi_bready,


         // read address channel signals
         output
         wire[3:0]   m_axi_arid,
         wire[31:0]  m_axi_araddr,
         wire[3:0]   m_axi_arlen,
         wire[2:0]   m_axi_arsize,
         wire[1:0]   m_axi_arburst,
         wire[1:0]   m_axi_arlock,
         wire[3:0]   m_axi_arcache,
         wire[2:0]   m_axi_arprot,
         output wire m_axi_arvalid,
         input
         wire        m_axi_arready,

         // read data channel signals
         input
         wire[3:0]   m_axi_rid,
         wire[31:0]  m_axi_rdata,
         wire[1:0]   m_axi_rresp,
         input wire  m_axi_rlast,
         wire        m_axi_rvalid,
         output
         wire        m_axi_rready

       );

mycpu_top mycpu_top0(
            .aclk(clock),
            .aresetn(resetn),
            .ext_int({int_req5,int_req4,int_req3,int_req2,int_req1,int_req0}),
            .awid(m_axi_awid),
            .awaddr(m_axi_awaddr),
            .awlen(m_axi_awlen),
            .awsize(m_axi_awsize),
            .awburst(m_axi_awburst),
            .awlock(m_axi_awlock),
            .awcache(m_axi_awcache),
            .awprot(m_axi_awprot),
            .awvalid(m_axi_awvalid),
            .awready(m_axi_awready),
            .wid(m_axi_wid),
            .wdata(m_axi_wdata),
            .wstrb(m_axi_wstrb),
            .wlast(m_axi_wlast),
            .wvalid(m_axi_wvalid),
            .wready(m_axi_wready),
            .bid(m_axi_bid),
            .bresp(m_axi_bresp),
            .bvalid(m_axi_bvalid),
            .bready(m_axi_bready),
            .arid(m_axi_arid),
            .araddr(m_axi_araddr),
            .arlen(m_axi_arlen),
            .arsize(m_axi_arsize),
            .arburst(m_axi_arburst),
            .arlock(m_axi_arlock),
            .arcache(m_axi_arcache),
            .arprot(m_axi_arprot),
            .arvalid(m_axi_arvalid),
            .arready(m_axi_arready),
            .rid(m_axi_rid),
            .rdata(m_axi_rdata),
            .rresp(m_axi_rresp),
            .rlast(m_axi_rlast),
            .rvalid(m_axi_rvalid),
            .rready(m_axi_rready),
            .debug_wb_pc(),
            .debug_wb_rf_wen(),
            .debug_wb_rf_wnum(),
            .debug_wb_rf_wdata()
         );

endmodule
