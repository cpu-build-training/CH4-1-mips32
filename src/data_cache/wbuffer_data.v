`timescale 1ns / 1ps

module wbuffer_data(
    input   wire        clk,

    input   wire[3:0]   addr,
    output  wire[31:0]  rdata,
    input   wire        wen,
    input   wire[31:0]  wdata
    );
    
    wbuffer_data_ram wbuffer_data_ram_0(
        .clka(clk),         // input wire clka

        .addra(addr),       // input wire [3 : 0] addra
        .douta(rdata),      // output wire [31 : 0] douta
        .wea(wen),          // input wire [0 : 0] wea
        .dina(wdata)        // input wire [31 : 0] dina
    );
endmodule