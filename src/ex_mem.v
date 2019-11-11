// 将执行阶段取得的运算结果，在下一个时钟周期传递到流水线访村阶段
`include "defines.v"
module ex_mem(
           input wire clk, wire rst,
           // 来自执行阶段的信息
           input
           wire[`RegAddrBus] ex_wd,
           wire                ex_wreg,
           wire[`RegBus]       ex_wdata,

           // 送到访存阶段的信息
           output
           reg[`RegAddrBus]        mem_wd,
           reg                     mem_wreg,
           reg[`RegBus]            mem_wdata
       );

always @(posedge clk) begin
    if(rst == `RstEnable) begin
        mem_wd <= `NOPRegAddr;
        mem_wreg<= `WriteDisable;
        mem_wdata <= `ZeroWord;
    end
    else begin
        mem_wd <= ex_wd;
        mem_wreg<= ex_wreg;
        mem_wdata<=ex_wdata;
    end
end

endmodule // ex_mem
