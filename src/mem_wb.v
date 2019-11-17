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
           // 送到回写阶段的信息
           output
           reg[`RegAddrBus]        wb_wd,
           reg                     wb_wreg,
           reg[`RegBus]           wb_wdata,
           reg[`RegBus]        wb_hi,
           reg[`RegBus]        wb_lo,
           reg                 wb_whilo
       );

always @(posedge clk) begin
    if (rst == `RstEnable) begin
        wb_wd <= `NOPRegAddr;
        wb_wreg <= `WriteDisable;
        wb_wdata <= `ZeroWord;
        wb_hi <= `ZeroWord;
        wb_lo <= `ZeroWord;
        wb_whilo <= `WriteDisable;
    end
    else begin
        wb_wd <=  mem_wd;
        wb_wreg <=  mem_wreg;
        wb_wdata <=  mem_wdata;
        wb_hi <= mem_hi;
        wb_lo <= mem_lo;
        wb_whilo <= mem_whilo;
    end
end
endmodule // mem_wb
