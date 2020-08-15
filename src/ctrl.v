`include "defines.v"
module ctrl(
         input  wire    rst,
         input  wire    stallreq_from_id,
         input  wire    stallreq_from_ex,
         input  wire    stallreq_from_mem,
        //  wire stallreq_from_if,
        //  wire[1:0] axi_read_state,
         input  wire     mem_we,
         // 来自 MEM
         input  wire[31:0]      excepttype_i,
         input  wire[`RegBus]   cp0_epc_i,

         output
         reg[`RegBus]     new_pc,
         reg              flush,
         reg[5:0]         stall
       );
always @(*)
  begin
    if(rst == `RstEnable)
      begin
        stall = 6'b000000;
        flush = 1'b0;
        new_pc = `ZeroWord;
      end
    else if(excepttype_i != `ZeroWord)
      begin
        // 发生异常
        flush = 1'b1;
        new_pc = `ZeroWord;
        stall = 6'b000000;
        case (excepttype_i)
          32'h0000_0001:
            begin
              // 中断
              new_pc = 32'hBFC0_0380;
            end
          32'h000_0008:
            begin
              // 系统调用异常 syscall
              new_pc = 32'hBFC0_0380;
            end
          32'h0000_0009:
            begin
              // 断点异常 break
              new_pc = 32'hBFC0_0380;
            end
          32'h0000_000a:
            begin
              // 无效指令异常
              new_pc = 32'hBFC0_0380;
            end
          32'h0000_000d:
            begin
              // 自陷异常
              new_pc = 32'hBFC0_0380;
            end
          32'h0000_000c:
            begin
              // 溢出异常
              new_pc = 32'hBFC0_0380;
            end
          `ADEL_FINAL:
            begin
              new_pc = 32'hBFC0_0380;
            end
          `ADES_FINAL:
            begin
              new_pc = 32'hBFC0_0380;
            end
          `TLBRL_CODE_FINAL: 
            begin
              new_pc = 32'hBFC0_0200;
            end
          `TLBRL_DATA_FINAL: 
            new_pc = 32'hBFC0_0200;
          `TLBRS_FINAL:
            begin
              new_pc = 32'hBFC0_0200;
            end
          `TLBIL_CODE_FINAL:
            begin
              new_pc = 32'hBFC0_0380;
            end
          `TLBIL_DATA_FINAL:
            new_pc = 32'hBFC0_0380;
          `TLBIS_FINAL:
            begin
              new_pc = 32'hBFC0_0380;
            end
          `TLBM_FINAL:
            begin
              new_pc = 32'hBFC0_0380;
            end
          32'h0000_000e:
            begin
              // 异常返回指令 eret
              new_pc = cp0_epc_i;
            end
          default:
            begin
            end
        endcase
      end
    else if(stallreq_from_mem == `Stop)
      begin
        flush = 1'b0;
        // if (axi_read_state == `BusyForMEM || mem_we) begin
          stall = 6'b011111;
        // end else begin
        //   stall = 6'b011000;
        // end
        new_pc = `ZeroWord;
      end
    else if(stallreq_from_ex == `Stop)
      begin
        stall = 6'b001111;
        flush = 1'b0;
        new_pc = `ZeroWord;
      end
    else if(stallreq_from_id == `Stop)
      begin
        stall = 6'b000111;
        flush = 1'b0;
        new_pc = `ZeroWord;
      end
    // else if (stallreq_from_if == `Stop)
    //   begin
    //     stall = 6'b000010;
    //     flush = 1'b0;
    //     new_pc = `ZeroWord;
    //   end
    else
      begin
        stall = 6'b000000;
        flush = 1'b0;
        new_pc = `ZeroWord;
      end
  end




endmodule // ctrl
