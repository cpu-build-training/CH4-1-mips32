// 将译码阶段取得的运算类型、源操作数、要写的目的寄存器地址等结果，
// 在下一个时钟周期传递到流水线执行阶段
`include "defines.v"
module id_ex(
           input wire clk, wire rst,

           // 从译码阶段传过来的信息
           input
           wire[`AluOpBus] id_aluop,
           wire[`AluSelBus] id_alusel,
           wire[`RegBus]   id_reg1,
           wire[`RegBus]   id_reg2,
           wire[`RegAddrBus] id_wd,
           wire            id_wreg,

           // 传到执行阶段的信息
           output
           reg[`AluOpBus]      ex_aluop,
           reg[`AluSelBus]     ex_alusel,
           reg[`RegBus]        ex_reg1,
           reg[`RegBus]        ex_reg2,
           reg[`RegAddrBus]    ex_wd,
           reg                 ex_wreg
       );

always @(posedge clk) begin
    if(rst == `RstEnable) begin
        ex_aluop <= `EXE_NOP_OP;
        ex_alusel <= `EXE_RES_NOP;
        ex_reg1 <= `ZeroWord;
        ex_reg2 <= `ZeroWord;
        ex_wd   <= `NOPRegAddr;
        ex_wreg <= `WriteDisable;
    end
    else begin
        ex_aluop <= id_aluop;
        ex_alusel <= id_alusel;
        ex_reg1 <= id_reg1;
        ex_reg2 <= id_reg2;
        ex_wd   <= id_wd;
        ex_wreg <= id_wreg;
    end
end

endmodule // id_ex
