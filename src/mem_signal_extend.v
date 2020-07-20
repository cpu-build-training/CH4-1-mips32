`include "defines.v"
module mem_signal_extend (
         input wire clk, rst, flush,

         /// 与 mem 交互

         // 使能，类似于 ce
         input wire enable,
         // 是否是写内存
         input wire we,
         // 地址
         input wire[`RegBus] mem_addr_i,
         // 数据（当然只会在写地址时有意义）
         input wire[`RegBus] mem_data_i,
         // select 信号，不需要处理，直接使用即可
         input wire[3:0]   mem_sel_i,

         // 完成写操作
         output wire mem_write_finish,
         // 完成读操作
         output wire mem_read_finish,
         output wire[`RegBus] mem_data_o,

         /// 与外部模块交互

         // 整体设计类似于 SRAM 接口
         output wire req,
         output wire wr,
         output wire[3:0] select,
         output wire[`RegBus] addr,
         output wire[`RegBus] wdata,
         input wire addr_ok,
         input wire data_ok,
         input wire[`RegBus] rdata
       );


// 在一次数据交换内，一旦 addr 上升， addr_ok_last_long 将一直保持高电位。
// 一次数据交换是指 enable 使能的这段范围
reg addr_ok_last_long;

always @(posedge clk)
  begin
    if (rst == `RstEnable)
      begin
        addr_ok_last_long <= 1'b0;
      end
    else if (addr_ok == 1'b1)
      begin
        addr_ok_last_long <= 1'b1;
      end
    else if (addr_ok_last_long == 1'b1 && enable == 1'b0)
      begin
        addr_ok_last_long <= 1'b0;
      end
    else
      begin

      end
  end

// TODO
// wire testb;
// assign testb = (addr_ok == 1'b1 || addr_ok_last_long == 1'b1)? 1'b0: enable;
assign req = (addr_ok == 1'b1 || addr_ok_last_long == 1'b1)? 1'b0: enable;
assign wr = we;
assign select = mem_sel_i;
assign addr = mem_addr_i;
assign wdata = mem_data_i;
assign mem_write_finish = (enable == 1'b1 && we == 1'b1)? data_ok:1'b0;
assign mem_read_finish = (enable == 1'b1 && we == 1'b0)? data_ok:1'b0;
assign mem_data_o = rdata;

// always @(posedge clk)
//   begin
//     if (rst == `RstEnable)
//       begin
//         busy <= 1'b0;
//       end
//   end

endmodule
