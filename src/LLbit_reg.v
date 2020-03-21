// LLbit 当做寄存器处理，ll指令需要写该寄存器，sc指令需要读该寄存器
// 同时，与对通用寄存器的访问一样，对 LLbit 寄存器的写操作也放在回写阶段进行
`include "defines.v"
module LLbit_reg(
    input wire clk,
    wire rst,

    // 异常是否发生，1 表示异常发生，0 表示没有异常
    wire flush,

    // 写操作
    wire LLbit_i,
    wire    we,

    // LLbit 寄存器的值
    output reg  LLbit_o
);

always @(posedge clk) begin
    if(rst == `RstEnable) begin
        LLbit_o <= 1'b0;
    end else if((flush == 1'b1)) begin
        // 如果异常发生，那么设置 LLbit_o 为 0
        LLbit_o <= 1'b0;
    end else if((we == `WriteEnable))begin
        LLbit_o <= LLbit_i;
    end
end

endmodule // LLbit_reg