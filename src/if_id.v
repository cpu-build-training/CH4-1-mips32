// 暂时保存取指阶段取得的指令，以及对应的指令地址
`include "defines.v"
module if_id(
    input wire clk,
    wire rst,
    wire[`InstAddrBus] if_pc,
    wire[`InstBus] if_inst,

    // CTRL
    input wire flush,
    input wire[5:0] stall, // From CTRL module.

    // if inst is a valid signal
    input wire inst_valid,

    output reg[`InstAddrBus] id_pc,
    reg[`InstBus] id_inst,
    // if we need to stall due to axi wait
    output reg             stallreq_for_if,
    // if ready to receive inst
    output reg             inst_ready
);


// to adapt axi_read_adaptor
// always @(*) begin
//     inst
// end


// if_pc 取指阶段取得的指令对应的地址
// if_inst 取指阶段取得的指令
// id_pc 译码阶段的指令对应的地址
// id_inst 译码阶段的指令

always @(*) begin
    // 只是对数据做了简单的带使能的保存\传递功能
    if (rst == `RstEnable) begin
        id_pc <= `ZeroWord;
        id_inst <= `ZeroWord;
        inst_ready <= `NotReady;
    end else if(flush == 1'b1) begin
        // flush 为 1 表示异常发生，要清楚流水线
        // 所以复位 id_pc, id_inst 寄存器的值
        id_pc <= `ZeroWord;
        id_inst <= `ZeroWord;
        inst_ready <= `NotReady;
    end else if(stall[1] == `Stop && stall[2] == `NoStop && inst_valid == `InValid) begin
    // 表示取指阶段暂停，而译码阶段继续，所以使用空指令为下一个周期进入译码阶段的指令
    // 如果 inst_valid == `Valid 的话，说明已经从 mem 读取了数据，这时应当往下传输
        // $display("if_inst = %x, valid = %d, stall!", if_inst, inst_valid);
        id_pc <= `ZeroWord;
        id_inst <= `ZeroWord;
        inst_ready <= `Ready;
    end else if(stall[1] == `NoStop) begin
    // 这时两个阶段都为继续，正常工作
        id_pc <= if_pc;
        id_inst <= if_inst;
        inst_ready <= `Ready;
    end
    // 其余情况下，保持输出不变

    if(rst == `RstEnable)
        stallreq_for_if <= `NoStop;
    else if (inst_valid)
        stallreq_for_if <= `NoStop;
    else
        stallreq_for_if <= `Stop;


end

endmodule // if_id