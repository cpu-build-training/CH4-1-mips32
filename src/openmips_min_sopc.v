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

// 连接数据存储器
wire [`DataAddrBus]     ram_addr_o;
wire [3:0]              ram_sel_o;
wire[`DataBus]          ram_data_o;
wire[`DataBus]          ram_data_i;          
wire                    ram_we_o;
wire                    ram_ce_o;


// 实例化 OpenMIPS
openmips openmips0(
    .clk(clk), .rst(rst),
    .rom_addr_o(inst_addr), .rom_data_i(inst),
    .rom_ce_o(rom_ce),

    .ram_data_i(ram_data_i),
    .ram_data_o(ram_data_o),
    .ram_addr_o(ram_addr_o),
    .ram_sel_o(ram_sel_o),
    .ram_we_o(ram_we_o),
    .ram_ce_o(ram_ce_o)
);

// 实例化 ROM
inst_rom inst_rom0(
    .ce(rom_ce),
    .addr(inst_addr),
    .inst(inst)
);

// 实例化 RAM
data_ram data_ram0(
    .addr(ram_addr_o),
    .data_i(ram_data_o),
    .sel(ram_sel_o),
    .we(ram_we_o),
    .ce(ram_ce_o),
    .clk(clk),
    .data_o(ram_data_i)

);

endmodule // openmips_min_sopc