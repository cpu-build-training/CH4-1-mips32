// 将访存阶段的运算结果，在下一个时钟周期传递到回写阶段
`include "defines.v"
module mem_wb(
           input wire clk, wire rst,
           //  访存阶段结果
           input
           wire[`RegAddrBus]       mem_wd,
           wire                    mem_wreg,
           wire[`RegBus]           mem_wdata,

           wire[`RegBus]         mem_hi,
           wire[`RegBus]         mem_lo,
           wire mem_whilo,

           // LLbit
           wire    mem_LLbit_we,
           wire mem_LLbit_value,

           // 送到回写阶段的信息
           output
           reg[`RegAddrBus]        wb_wd,
           reg                     wb_wreg,
           reg[`RegBus]           wb_wdata,
           reg[`RegBus]        wb_hi,
           reg[`RegBus]        wb_lo,
           reg                 wb_whilo,

           // LLbit
           reg wb_LLbit_we,
           reg wb_LLbit_value,

           // From CTRL module.
           input wire[5:0]     stall
       );

always @(posedge clk) begin
    if (rst == `RstEnable) begin
        wb_wd <= `NOPRegAddr;
        wb_wreg <= `WriteDisable;
        wb_wdata <= `ZeroWord;
        wb_hi <= `ZeroWord;
        wb_lo <= `ZeroWord;
        wb_whilo <= `WriteDisable;
        wb_LLbit_we <= 1'b0;
        wb_LLbit_value <= 1'b0;
    end
    else if(stall[4] == `Stop && stall[5] == `NoStop) begin
        wb_wd <= `NOPRegAddr;
        wb_wreg <= `WriteDisable;
        wb_wdata <= `ZeroWord;
        wb_hi <= `ZeroWord;
        wb_lo <= `ZeroWord;
        wb_whilo <= `WriteDisable;
        wb_LLbit_we <= 1'b0;
        wb_LLbit_value <= 1'b0;
    end
    else if(stall[4] == `NoStop ) begin
        wb_wd <=  mem_wd;
        wb_wreg <=  mem_wreg;
        wb_wdata <=  mem_wdata;
        wb_hi <= mem_hi;
        wb_lo <= mem_lo;
        wb_whilo <= mem_whilo;
        wb_LLbit_we <= mem_LLbit_we;
        wb_LLbit_value <= mem_LLbit_value;
    end
end
endmodule // mem_wb
