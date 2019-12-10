`include "defines.v"
module ctrl(
           input wire rst,
           wire stallreq_from_id,
           wire stallreq_from_ex,
           output
           reg[5:0] stall
       );
always @(*) begin
    if(rst == `RstEnable)begin
        stall <= 6'b0;
    end else if (stallreq_from_ex == `Stop) begin
        stall <= 6'b001111;
    end else if (stallreq_from_id == `Stop) begin
        stall <= 6'b000111;
    end else begin
        stall <= 6'b0;
    end
end
endmodule // ctrl
