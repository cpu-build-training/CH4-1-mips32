`include "defines.v"


module pc_reg(
    input wire clk, wire rst,
    output reg[`InstAddrBus] pc, reg ce
);

always @ (posedge clk) begin
    // about ce
    if (rst == `RstEnable) begin
        // 复位的时候指令存储器禁用
        ce <= `ChipDisable; // 非阻塞赋值会在整个语句结束时才会完成赋值操作，不是立刻改变
    end else begin
        // 复位结束后，指令存储器使能
        ce <= `ChipEnable;
    end
end

always @(posedge clk) begin
    // about pc
    // FIXED: 如果使用 (rst == `Disable)，
    // 会导致 pc 与 ir 总是表示同一个地址
    // 而在这里使用 ce 和 非阻塞复制，就是为了产生一个周期的延迟效果。
    // 因为这一个 always 的判断条件，依赖于上一个时钟周期结束时的赋值结果
    if (ce == `RstDisable) begin
        pc <= 32'h0;
    end else begin
        //  按照字节寻址
        pc <= pc + `InstAddrIncrement; // 3'h4?
    end
end

endmodule // pc_reg