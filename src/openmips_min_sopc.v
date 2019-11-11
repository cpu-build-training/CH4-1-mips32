// 最小 SOPC 实现
`include "defines.v"
module openmips_min_spoc(
    input wire clk,
    wire rst
);

// 连接指令存储器
wire [`InstAddrBus] inst_addr;
wire [`InstBus] inst;
wire rom_ce;

// 实例化 OpenMIPS
openmips openmips0(
    .clk(clk), .rst(rst),
    .rom_addr_o(inst_addr), .rom_data_i(inst),
    .rom_ce_o(rom_ce)
);

// 实例化 ROM
inst_rom inst_rom0(
    .ce(rom_ce),
    .addr(inst_addr),
    .inst(inst)
);

endmodule // openmips_min_sopc