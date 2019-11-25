`timescale 1ns/1ps
`include "defines.v"
module openmips_min_sopc_tb();
reg CLOCK_50;
reg rst;

// 每间隔 10ns，CLOCK_50 信号翻转一次, 所以一个周期是 20ns，对应 50MHz
initial begin
    CLOCK_50 = 1'b0;
    forever #10 CLOCK_50 = ~CLOCK_50;
end


// 最初时刻，复位信号有效，在 195ns，开始运行
initial begin
    rst = `RstEnable;
    #195 rst = `RstDisable;
    #4000 $stop;
end

// 实例化
openmips_min_spoc openmips_min_sopc0(
    .clk(CLOCK_50),
    .rst(rst)
);
endmodule // openmips_min_sopc_tb