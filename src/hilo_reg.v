// HI LO
`include "defines.v"
module hilo_reg(
           input wire clk, wire rst,

           input
           wire we,
           wire[`RegBus]   hi_i,
           wire[`RegBus]   lo_i,

           output
           reg[`RegBus]    hi_o,
           reg[`RegBus]    lo_o
       );

always @(posedge clk) begin
    if (rst == `RstEnable) begin
        hi_o <= `ZeroWord;
        lo_o <= `ZeroWord;
    end
    else if((we == `WriteEnable)) begin
        hi_o <= hi_i;
        lo_o <= lo_i;
    end
end

endmodule // hilo_reg
