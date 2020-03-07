// 将访存阶段的运算结果，在下一个时钟周期传递到回写阶段
`include "defines.v"
module mem_wb(
         input wire clk, wire rst,
         //  访存阶段结果
         input
         wire[`RegAddrBus]       mem_wd,
         input wire              mem_wreg,
         wire[`RegBus]           mem_wdata,

         wire[`RegBus]         mem_hi,
         wire[`RegBus]         mem_lo,
         input wire mem_whilo,
         wire[`RegBus]        mem_current_address,

         // LLbit
         input wire    mem_LLbit_we,
         wire mem_LLbit_value,

         // cp0
         wire mem_cp0_reg_we,
         wire[4:0] mem_cp0_reg_write_addr,
         wire[`RegBus] mem_cp0_reg_data,

         // 异常
         input  wire flush,

         // 送到回写阶段的信息
         output
         reg[`RegAddrBus]        wb_wd,
         output reg                     wb_wreg,
         reg[`RegBus]           wb_wdata,
         reg[`RegBus]        wb_hi,
         reg[`RegBus]        wb_lo,
         output reg                 wb_whilo,

         // LLbit
         reg wb_LLbit_we,
         reg wb_LLbit_value,

         // cp0
         output reg              wb_cp0_reg_we,
         reg[4:0]         wb_cp0_reg_write_addr,
         reg[`RegBus]     wb_cp0_reg_data,

         // DEBUG
         reg[`RegBus]   wb_current_address,

         // From CTRL module.
         input wire[5:0]     stall
       );

always @(posedge clk)
  begin
    if (rst == `RstEnable || flush == 1'b1)
      begin
        wb_wd <= `NOPRegAddr;
        wb_wreg <= `WriteDisable;
        wb_wdata <= `ZeroWord;
        wb_hi <= `ZeroWord;
        wb_lo <= `ZeroWord;
        wb_whilo <= `WriteDisable;
        wb_LLbit_we <= 1'b0;
        wb_LLbit_value <= 1'b0;
        wb_cp0_reg_we <= `WriteDisable;
        wb_cp0_reg_write_addr <= 5'b00000;
        wb_cp0_reg_data <= `ZeroWord;
        wb_current_address <= `ZeroWord;
      end
    else if(stall[4] == `Stop && stall[5] == `NoStop)
      begin
        wb_wd <= `NOPRegAddr;
        wb_wreg <= `WriteDisable;
        wb_wdata <= `ZeroWord;
        wb_hi <= `ZeroWord;
        wb_lo <= `ZeroWord;
        wb_whilo <= `WriteDisable;
        wb_LLbit_we <= 1'b0;
        wb_LLbit_value <= 1'b0;
        wb_cp0_reg_we <= `WriteDisable;
        wb_cp0_reg_write_addr <= 5'b00000;
        wb_cp0_reg_data <= `ZeroWord;
        // wb_current_address <= `ZeroWord;
      end
    else if(stall[4] == `NoStop )
      begin
        wb_wd <=  mem_wd;
        wb_wreg <=  mem_wreg;
        wb_wdata <=  mem_wdata;
        wb_hi <= mem_hi;
        wb_lo <= mem_lo;
        wb_whilo <= mem_whilo;
        wb_LLbit_we <= mem_LLbit_we;
        wb_LLbit_value <= mem_LLbit_value;
        wb_cp0_reg_we <= mem_cp0_reg_we;
        wb_cp0_reg_write_addr <= mem_cp0_reg_write_addr;
        wb_cp0_reg_data <= mem_cp0_reg_data;
        wb_current_address <= mem_current_address;
      end
  end
endmodule // mem_wb
