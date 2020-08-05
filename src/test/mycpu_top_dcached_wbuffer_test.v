module axi_test(
         input
         wire aclk,
         wire aresetn,
         wire[5:0] int_i,
         // write address channel signals
         output
         reg[3:0]          awid,
         reg[31:0]         awaddr,
         reg[3:0]          awlen,
         reg[2:0]          awsize,
         reg[1:0]          awburst,
         reg[1:0]          awlock,
         reg[3:0]          awcache,
         reg[2:0]          awprot,
         output reg        awvalid,
         input
         wire              awready,

         // write data channel signals
         output
         reg[3:0]          wid,
         reg[31:0]         wdata,
         reg[3:0]          wstrb,
         output reg        wlast,
         reg               wvalid,
         input             wready,

         // write response channel signals
         input
         wire[3:0]          bid,
         wire[1:0]          bresp,
         input wire         bvalid,
         output
         wire               bready,


         // read address channel signals
         output
         wire[3:0]          arid,
         wire[31:0]         araddr,
         wire[3:0]          arlen,
         wire[2:0]          arsize,
         wire[1:0]          arburst,
         wire[1:0]          arlock,
         wire[3:0]          arcache,
         wire[2:0]          arprot,
         reg                arvalid,
         input
         wire               arready,

         // read data channel signals
         input
         wire[3:0]          rid,
         wire[31:0]         rdata,
         wire[1:0]          rresp,
         input wire         rlast,
         wire               rvalid,
         output
         wire               rready,


         // port for debug
         output
         wire[31:0]         debug_wb_pc,
         wire[3:0]          debug_wb_rf_wen,
         wire[4:0]          debug_wb_rf_wnum,
         wire[31:0]         debug_wb_rf_wdata
);


wire dch_wbf_wreq;
wire dch_wbf_wreq_recvd;
wire dch_wbf_uched_wreq;
wire dch_wbf_wdone;

wire [31:0] dch_wbf_wdata_paddr;
wire [31:0] dch_wbf_wdata_bank0;
wire [31:0] dch_wbf_wdata_bank1;
wire [31:0] dch_wbf_wdata_bank2;
wire [31:0] dch_wbf_wdata_bank3;
wire [31:0] dch_wbf_wdata_bank4;
wire [31:0] dch_wbf_wdata_bank5;
wire [31:0] dch_wbf_wdata_bank6;
wire [31:0] dch_wbf_wdata_bank7;

wire dch_wbf_empty;
wire dch_wbf_clear_req;
wire dch_wbf_clear_done;

wire dch_wbf_lookup_req;
wire [31:0] dch_wbf_lookup_paddr;

wire dch_wbf_lookup_res_hit;
wire [31:0] dch_wbf_lookup_res_data_bank0;
wire [31:0] dch_wbf_lookup_res_data_bank1;
wire [31:0] dch_wbf_lookup_res_data_bank2;
wire [31:0] dch_wbf_lookup_res_data_bank3;
wire [31:0] dch_wbf_lookup_res_data_bank4;
wire [31:0] dch_wbf_lookup_res_data_bank5;
wire [31:0] dch_wbf_lookup_res_data_bank6;
wire [31:0] dch_wbf_lookup_res_data_bank7;

wire [31:0] dch_wbf_awaddr  ;
wire [3:0]  dch_wbf_awlen   ;
wire [1:0]  dch_wbf_awburst ;
wire        dch_wbf_awvalid ;
wire        dch_wbf_awready ;

wire [31:0] dch_wbf_wdata   ;
wire [3 :0] dch_wbf_wstrb   ;
wire        dch_wbf_wlast   ;
wire        dch_wbf_wvalid  ;
wire        dch_wbf_wready  ;

wire        dch_wbf_bvalid  ;

// data r/w
dcache_wbuffered dcache_wbuffered_0(
    .clk(aclk),
    .rstn(aresetn),
    .flush(flush),

    // AXI
    .arid(arid),
    .araddr(araddr),
    .arlen(arlen),
    .arsize(arsize),
    .arburst(arburst),
    .arlock(arlock),
    .arcache(arcache),
    .arprot(arprot),
    .arvalid(arvalid),
    .arready(arready),

    .rid(rid),
    .rdata(rdata),
    .rresp(rresp),
    .rvalid(rvalid),
    .rready(rready),
    .rlast(rlast),
    
    // wbuffer
    .wbuffer_wreq(dch_wbf_wreq),
    .wbuffer_wreq_recvd(dch_wbf_wreq_recvd),
    .wbuffer_uchd_wreq(dch_wbf_uched_wreq),
    .wbuffer_wdone(dch_wbf_wdone),

    .wbuffer_wdata_paddr(dch_wbf_wdata_paddr),
    .wbuffer_wdata_bank0(dch_wbf_wdata_bank0),
    .wbuffer_wdata_bank1(dch_wbf_wdata_bank1),
    .wbuffer_wdata_bank2(dch_wbf_wdata_bank2),
    .wbuffer_wdata_bank3(dch_wbf_wdata_bank3),
    .wbuffer_wdata_bank4(dch_wbf_wdata_bank4),
    .wbuffer_wdata_bank5(dch_wbf_wdata_bank5),
    .wbuffer_wdata_bank6(dch_wbf_wdata_bank6),
    .wbuffer_wdata_bank7(dch_wbf_wdata_bank7),

    .wbuffer_empty(dch_wbf_empty),
    .wbuffer_clear_req(dch_wbf_clear_req),
    .wbuffer_clear_done(dch_wbf_clear_done),

    .wbuffer_lookup_req(dch_wbf_lookup_req),
    .wbuffer_lookup_res_hit(dch_wbf_lookup_res_hit),
    
    .wbuffer_lookup_paddr(dch_wbf_lookup_paddr),
    .wbuffer_rdata_bank0(dch_wbf_lookup_res_data_bank0),
    .wbuffer_rdata_bank1(dch_wbf_lookup_res_data_bank1),
    .wbuffer_rdata_bank2(dch_wbf_lookup_res_data_bank2),
    .wbuffer_rdata_bank3(dch_wbf_lookup_res_data_bank3),
    .wbuffer_rdata_bank4(dch_wbf_lookup_res_data_bank4),
    .wbuffer_rdata_bank5(dch_wbf_lookup_res_data_bank5),
    .wbuffer_rdata_bank6(dch_wbf_lookup_res_data_bank6),
    .wbuffer_rdata_bank7(dch_wbf_lookup_res_data_bank7),

    // uncached write 通过wbuffer传给axi
    // .awid(awid),
    .awaddr(dch_wbf_awaddr),
    .awlen(dch_wbf_awlen),
    // .awsize(awsize),
    .awburst(dch_wbf_awburst),
    // .awlock(awlock),
    // .awcache(awcache),
    // .awprot(awprot),
    .awvalid(dch_wbf_awvalid),
    .awready(dch_wbf_awready),

    // .wid(wid),
    .wdata(dch_wbf_wdata),
    .wstrb(dch_wbf_wstrb),
    .wlast(dch_wbf_wlast),
    .wvalid(dch_wbf_wvalid),
    .wready(dch_wbf_wready),

    // .bid(bid),
    // .bresp(bresp),
    .bvalid(dch_wbf_bvalid),
    // .bready(bready),

    // CPU SRAM like
    .data_req(data_req),
    .data_wr(data_wr),

    .data_addr_ok(data_addr_ok),
    .data_addr(data_addr),

    .data_data_ok(data_data_ok),
    .data_rdata(data_rdata),

    .data_sel(data_select),
    .data_wdata(data_wdata)
);

wbuffer_new wbuffer_0(
    .clk(aclk),
    .rstn(aresetn),

    // 与dcache
    .wreq(dch_wbf_wreq),
    .wreq_recvd(dch_wbf_wreq_recvd),
    .uchd_wreq(dch_wbf_uched_wreq),
    .wdone(dch_wbf_wdone),

    .wdata_paddr(dch_wbf_wdata_paddr),
    .wdata_bank0(dch_wbf_wdata_bank0),
    .wdata_bank1(dch_wbf_wdata_bank1),
    .wdata_bank2(dch_wbf_wdata_bank2),
    .wdata_bank3(dch_wbf_wdata_bank3),
    .wdata_bank4(dch_wbf_wdata_bank4),
    .wdata_bank5(dch_wbf_wdata_bank5),
    .wdata_bank6(dch_wbf_wdata_bank6),
    .wdata_bank7(dch_wbf_wdata_bank7),

    .empty(dch_wbf_empty),
    .clear_req(dch_wbf_clear_req),
    .clear_done(dch_wbf_clear_done),

    .lookup_req(dch_wbf_lookup_req),
    .lookup_paddr(dch_wbf_lookup_paddr),

    .lookup_res_hit(dch_wbf_lookup_res_hit),
    .lookup_res_data_bank0(dch_wbf_lookup_res_data_bank0),
    .lookup_res_data_bank1(dch_wbf_lookup_res_data_bank1),
    .lookup_res_data_bank2(dch_wbf_lookup_res_data_bank2),
    .lookup_res_data_bank3(dch_wbf_lookup_res_data_bank3),
    .lookup_res_data_bank4(dch_wbf_lookup_res_data_bank4),
    .lookup_res_data_bank5(dch_wbf_lookup_res_data_bank5),
    .lookup_res_data_bank6(dch_wbf_lookup_res_data_bank6),
    .lookup_res_data_bank7(dch_wbf_lookup_res_data_bank7),

    .dch_awaddr(dch_wbf_awaddr),
    .dch_awlen(dch_wbf_awlen),
    .dch_awburst(dch_wbf_awburst),
    .dch_awvalid(dch_wbf_awvalid),
    .dch_awready(dch_wbf_awready),

    .dch_wdata(dch_wbf_wdata),
    .dch_wstrb(dch_wbf_wstrb),
    .dch_wlast(dch_wbf_wlast),
    .dch_wvalid(dch_wbf_wvalid),
    .dch_wready(dch_wbf_wready),

    .dch_bvalid(dch_wbf_bvalid),
    
    // 与axi
    .awid(awid),
    .awaddr(awaddr),
    .awlen(awlen),
    .awsize(awsize),
    .awburst(awburst),
    .awlock(awlock),
    .awcache(awcache),
    .awprot(awprot),
    .awvalid(awvalid),
    .awready(awready),

    .wid(wid),
    .wdata(wdata),
    .wstrb(wstrb),
    .wlast(wlast),
    .wvalid(wvalid),
    .wready(wready),

    .bid(bid),
    .bresp(bresp),
    .bvalid(bvalid),
    .bready(bready)
);

wire            data_req;
wire            data_wr;
wire[3:0]       data_select;
wire[`RegBus]   data_addr;
wire[`RegBus]   data_wdata;
wire            data_addr_ok;
wire            data_data_ok;
wire[`RegBus]   data_rdata;

