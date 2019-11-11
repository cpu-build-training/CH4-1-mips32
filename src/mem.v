// 访存阶段
`include "defines.v"

module mem(
           input wire rst,
           // 来自执行阶段的信息
           input
           wire[`RegAddrBus]       wd_i,
           wire                    wreg_i,
           wire[`RegBus]           wdata_i,
           // 访存阶段的结果
           output
           reg[`RegAddrBus]        wd_o,
           reg                     wreg_o,
           reg[`RegBus]            wdata_o
       );

// 目前是组合逻辑电路

always @(*) begin
    if(rst==`RstEnable) begin
        wd_o <= `NOPRegAddr;
        wreg_o <= `WriteDisable;
        wdata_o <= `ZeroWord;
    end
    else begin
        wd_o <= wd_i;
        wreg_o <= wreg_i;
        wdata_o <= wdata_i;
    end
end

endmodule // mem
