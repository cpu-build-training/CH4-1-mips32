// 暂时保存取指阶段取得的指令，以及对应的指令地址
`include "defines.v"
module if_id(
    input wire clk, wire rst, wire[`InstAddrBus] if_pc, wire[`InstBus] if_inst,
    wire[5:0] stall, // From CTRL module.
    output reg[`InstAddrBus] id_pc, reg[`InstBus] id_inst
);
// if_pc 取指阶段取得的指令对应的地址
// if_inst 取指阶段取得的指令
// id_pc 译码阶段的指令对应的地址
// id_inst 译码阶段的指令

always @(posedge clk) begin
    // 只是对数据做了简单的带使能的保存\传递功能
    if (rst == `RstEnable) begin
        id_pc <= `ZeroWord;
        id_inst <= `ZeroWord;
    end else if(stall[1] == `Stop && stall[2] == `NoStop) begin
    // 表示取指阶段暂停，而译码阶段继续，所以使用空指令为下一个周期进入译码阶段的指令
        id_pc <= `ZeroWord;
        id_inst <= `ZeroWord;
    end else if(stall[1] == `NoStop) begin
    // 这时两个阶段都为继续，正常工作
        id_pc <= if_pc;
        id_inst <= if_inst;
    end
    // 其余情况下，保持输出不变
  
end

endmodule // if_id