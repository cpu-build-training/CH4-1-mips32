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
           
           wire[`RegBus]    id_link_address,
           wire             id_is_in_delayslot,
           wire             next_inst_in_delayslot_i,
           // 当前处于译码阶段的指令
           wire[`RegBus]    id_inst,

           // 异常
           wire             flush,
           wire[`RegBus]    id_current_inst_address,
           wire[31:0]       id_excepttype,

           // 传到执行阶段的信息
           output
           reg[`AluOpBus]      ex_aluop,
           reg[`AluSelBus]     ex_alusel,
           reg[`RegBus]        ex_reg1,
           reg[`RegBus]        ex_reg2,
           reg[`RegAddrBus]    ex_wd,
           reg                 ex_wreg,

           reg[`RegBus]         ex_link_address,
           reg                  ex_is_in_delayslot,
           reg                  is_in_delayslot_o,
           // 当前处于执行阶段的指令
           reg[`RegBus]         ex_inst,

           // 异常
           reg[`RegBus]         ex_current_inst_address,
           reg[31:0]            ex_excepttype,

           // From CTRL module.
           input wire[5:0]     stall

       );

always @(posedge clk) begin
    if(rst == `RstEnable) begin
        ex_aluop <= `EXE_NOP_OP;
        ex_alusel <= `EXE_RES_NOP;
        ex_reg1 <= `ZeroWord;
        ex_reg2 <= `ZeroWord;
        ex_wd   <= `NOPRegAddr;
        ex_wreg <= `WriteDisable;
        ex_link_address <= `ZeroWord;
        ex_is_in_delayslot <= `NotInDelaySlot;
        is_in_delayslot_o <= `NotInDelaySlot;
        ex_inst <= `ZeroWord;
        ex_excepttype <= `ZeroWord;
        ex_current_inst_address <= `ZeroWord;
    end else if(flush == 1'b1 ) begin
        ex_aluop <= `EXE_NOP_OP;
        ex_alusel <= `EXE_RES_NOP;
        ex_reg1 <= `ZeroWord;
        ex_reg2 <= `ZeroWord;
        ex_wd <= `NOPRegAddr;
        ex_wreg <= `WriteDisable;
        ex_excepttype <= `ZeroWord;
        ex_link_address <= `ZeroWord;
        ex_inst <= `ZeroWord;
        ex_is_in_delayslot <= `NotInDelaySlot;
        is_in_delayslot_o <= `NotInDelaySlot;
        ex_current_inst_address <= `ZeroWord;
    end else if(stall[2] == `Stop && stall[3] == `NoStop) begin
        // 下一个环节继续，本环节暂停，则输出 NOP
        ex_aluop <= `EXE_NOP_OP;
        ex_alusel <= `EXE_RES_NOP;
        ex_reg1 <= `ZeroWord;
        ex_reg2 <= `ZeroWord;
        ex_wd   <= `NOPRegAddr;
        ex_wreg <= `WriteDisable;
        ex_link_address <= `ZeroWord;
        ex_is_in_delayslot <= `NotInDelaySlot;
        ex_inst <= `ZeroWord;
        ex_excepttype <= `ZeroWord;
        ex_current_inst_address <= `ZeroWord;
        // ??? 为什么少了一项
    end
    else if(stall[2] == `NoStop) begin
        ex_aluop <= id_aluop;
        ex_alusel <= id_alusel;
        ex_reg1 <= id_reg1;
        ex_reg2 <= id_reg2;
        ex_wd   <= id_wd;
        ex_wreg <= id_wreg;
        ex_link_address <= id_link_address;
        ex_is_in_delayslot <= id_is_in_delayslot;
        is_in_delayslot_o <= next_inst_in_delayslot_i;
        // 在译码阶段没有暂停的情况下，直接将 ID 模块的输入通过接口 ex_inst 输出
        ex_inst <= id_inst;
        ex_excepttype <= id_excepttype;
        ex_current_inst_address <= id_current_inst_address;
    end
    // 其他情况，保持不变
end

endmodule // id_ex
