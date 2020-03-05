`include "defines.v"
module axi_adapter(

         input
         wire clk,
         wire reset,
         wire[5:0] int_i,
         // write address channel signals
         output
         wire[3:0]   awid,
         wire[31:0]  awaddr,
         wire[3:0]   awlen,
         wire[2:0]   awsize,
         wire[1:0]   awburst,
         wire[1:0]   awlock,
         wire[3:0]   awcache,
         wire[2:0]   awprot,
         output wire         awvalid,
         input
         wire    awready,

         // write data channel signals
         output
         wire[3:0]    wid,
         wire[31:0]   wdata,
         wire[3:0]   wstrb,
         output wire        wlast,
         wire        wvalid,
         input       wready,

         // write response channel signals
         input
         wire[3:0]   bid,
         wire[1:0]   bresp,
         input wire        bvalid,
         output
         wire        bready,


         // read address channel signals
         output
         wire[3:0]   arid,
         wire[31:0]  araddr,
         wire[3:0]  arlen,
         wire[2:0]   arsize,
         wire[1:0]   arburst,
         wire[1:0]   arlock,
         wire[3:0]   arcache,
         wire[2:0]   arprot,
         output wire        arvalid,
         input
         wire        arready,

         // read data channel signals
         input
         wire[3:0]    rid,
         wire[31:0]   rdata,
         wire[1:0]    rresp,
         input wire         rlast,
         wire         rvalid,
         output
         wire         rready,


         // port for debug
         output
         wire[`RegBus]     debug_wb_pc,
         wire[3:0]         debug_wb_rf_wen,
         wire[4:0]         debug_wb_rf_wnum,
         wire[`RegBus]     debug_wb_rf_wdata
       );

wire[`RegBus] rom_data;
wire          inst_valid;
wire[`RegBus] rom_addr;
wire          rom_re;
wire[`RegBus] ram_data_i;
wire[`RegBus] ram_addr;
wire[`RegBus] ram_data_o;
wire          ram_we;
wire          ram_re;
wire[3:0]          ram_sel;
wire          ram_write_valid;
wire          inst_ready;
wire          mem_data_ready;

axi_write_adapter axi_write_adapter0(
                    .clk(clk), .reset(reset),

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
                    .bready(bready),
                    .data(ram_data_o),
                    .we(ram_we),
                    .address(ram_addr),
                    .select(ram_sel),
                    .mem_write_valid(ram_write_valid)
                  );



axi_read_adapter axi_read_adapter0(
                   .clk(clk),
                   .reset(reset),
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
                   .rlast(rlast),
                   .rvalid(rvalid),
                   .rready(rready),

                   .pc(rom_addr),
                   .pc_re(rom_re),
                   .inst_read_ready(inst_ready),
                   .inst(rom_data),
                   .inst_valid(inst_valid),

                   .mem_re(ram_re),
                   .mem_addr(ram_addr),
                   .mem_data_read_ready(mem_data_ready),
                   .mem_data_valid(ram_write_valid),
                   .mem_data(ram_data_i)
                 );


openmips openmips0(
           .clk(clk),.rst(reset),

           .rom_data_i_le(rom_data),
           .rom_data_valid(inst_valid),
           .rom_addr_o(rom_addr),
           .rom_ce_o(rom_re),
           .inst_ready(inst_ready),
           .mem_data_ready(mem_data_ready),

           .ram_data_i(ram_data_i),
           .ram_addr_o(ram_addr),
           .ram_data_o(ram_data_o),
           .ram_we_o(ram_we),
           .ram_sel_o(ram_sel),
           .ram_re_o(ram_re),
           .ram_write_valid(ram_write_valid),

           .int_i(int_i),

           .debug_wb_pc(debug_wb_pc),
           .debug_wb_rf_wen(debug_wb_rf_wen),
           .debug_wb_rf_wnum(debug_wb_rf_wnum),
           .debug_wb_rf_wdata(debug_wb_rf_wdata)
         );

endmodule // axi_adapter
