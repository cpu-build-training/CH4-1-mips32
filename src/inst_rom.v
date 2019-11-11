// 指令存储器
`include "defines.v"

module inst_rom(
    input wire  ce,
    wire[`InstBus]  addr,
    output reg[`InstBus]    inst
);
// 定义一个数组，大小是 InstMemNum，元素宽度是 InstBus
reg[`InstBus] inst_mem[0:`InstMemNum-1];

// 使用文件 inst_rom.data 初始化指令寄存器
initial $readmemh ("inst_rom.data", inst_mem);

// 当复位信号无效时，依据输入的地址，给出指令存储器 ROM 中对应的元素
always @(*) begin
    if (ce == `ChipDisable) begin
        inst <= `ZeroWord;
    end else begin
        // openMips 是按照字节寻址，而定义的存储器是一个字长（32bits），
        // 因此寻址的时候，要除以4
        inst <= inst_mem[addr[`InstMemNumLog2+1:2]];
        // 另外可以检查一下对地址的合法性检测？
    end
end

endmodule // inst_rom