// 访存阶段
`include "defines.v"

module mem(
           input wire rst,
           // 来自执行阶段的信息
           input
           wire[`RegAddrBus]       wd_i,
           wire                    wreg_i,
           wire[`RegBus]           wdata_i,


           wire whilo_i,
           wire[`RegBus]    hi_i,
           wire[`RegBus]    lo_i,

           // 访存阶段的结果
           output
           reg[`RegAddrBus]        wd_o,
           reg                     wreg_o,
           reg[`RegBus]            wdata_o,

           reg[`RegBus]         hi_o,
           reg[`RegBus]         lo_o,
           reg whilo_o
       );

// 目前是组合逻辑电路

always @(*) begin
    if(rst==`RstEnable) begin
        wd_o <= `NOPRegAddr;
        wreg_o <= `WriteDisable;
        wdata_o <= `ZeroWord;
        hi_o <= `ZeroWord;
        lo_o <= `ZeroWord;
        whilo_o <= `WriteDisable;
    end
    else begin
        wd_o <= wd_i;
        wreg_o <= wreg_i;
        wdata_o <= wdata_i;
        hi_o <= hi_i;
        lo_o <= lo_i;
        whilo_o <= whilo_i;
    end
end

endmodule // mem
