`include "defines.v"
module div(
         input wire clk, wire rst,
         input
         wire         signed_div_i,
         wire[31:0]   opdata1_i,
         wire[31:0]   opdata2_i,
         input
         wire         start_i,
         wire         annul_i,

         output
         reg[63:0]    result_o,
         reg          ready_o
       );

wire[32:0]      div_temp;
reg[5:0]        cnt;    // 记录试商法进行了几轮，当等于 32 时，表示试商法结束
reg[64:0]       dividend;
reg[1:0]        state;
reg[31:0]       divisor;
// reg[31:0]       temp_op1;
// reg[31:0]       temp_op2;

// dividend 的低 32 位保存的是被除数、中间结果，第 k 次迭代结束的时候 dividend[k:0]
// 保存的就是当前得到的中间结果，dividend[31:k+1] 保存的就是被除数中还没有参与运算
// 的数据，diviedend 高 32 位 是每次迭代时的被减数，所以 dividend[63:32] 就是 minuend（见具体的图）
// divisor 就是图中的 n，此处进行的就是 minuend-n 运算，结果保存在 div_temp 中

assign div_temp = {1'b0, dividend[63:32]} - {1'b0, divisor};

always @(posedge clk)
  begin
    if(rst == `RstEnable)
      begin
        state <= `DivFree;
        ready_o <= `DivResultNotReady;
        result_o <= {`ZeroWord,`ZeroWord};
        dividend <= {1'b1, `ZeroWord, `ZeroWord};
      end
    else
      begin
        case (state)
          `DivFree:
            begin
              // DivFree 状态
              if(start_i == `DivStart && annul_i == 1'b0)
                begin
                  if(opdata2_i == `ZeroWord)
                    begin
                      // 开始除法运算，但是除数为 0
                      state <= `DivByZero;
                    end
                  else
                    begin
                      // 开始除法运算，且除数不为 0，那么进入 DivOn 状态，
                      // 初始化 cnt 为 0，如果是有符号除法，且被除数或者除数为负，那么对被除数或者除数取补码。
                      // 出书保存到 divisor 中，将被除数的最高位保存到 dividend 的第 32 位，
                      // 准备进行第一次迭代
                      state <= `DivOn;
                      cnt <= 6'b0;
                      dividend <= {`ZeroWord, `ZeroWord, 1'b0};
                      if(signed_div_i == 1'b1 && opdata1_i[31] == 1'b1)
                        begin
                          dividend[32:1] <= ~opdata1_i + 1;
                        end
                      else
                        begin
                          dividend[32:1]  <= opdata1_i;
                        end
                      if(signed_div_i == 1'b1 && opdata2_i[31] == 1'b1)
                        begin
                          divisor <= ~opdata2_i + 1;
                        end
                      else
                        begin
                          divisor <= opdata2_i;
                        end

                    end


                end
              else
                begin
                  ready_o <= `DivResultNotReady;
                  result_o <= {`ZeroWord,`ZeroWord};
                end
            end
          `DivByZero:
            begin
              // 如果进入 DivByZero 状态，那么直接进入 DivEnd 状态，除法结束，且结果为 0
              dividend <= {`ZeroWord, `ZeroWord, 1'b0};
              state <= `DivEnd;
            end
          `DivOn:
            begin
              // 1. 如果输入信号 annul_i 为 1， 表示处理器取消除法运算，那么 DIV 模块直接回到 DivFree 状态
              // 2. 如果 annul_i 为 0，且 cnt 不为 32，那么表示试商法还没有结束，此时如果减法结果 div_temp 为负，那么此次迭代结果是 0
              //   如果减法结果 div_temp 为正，那么此次迭代结果是 1
              //    dividend 的最低位保存每次的迭代结果，同时保持 DivOn 状态，cnt 加 1
              // 3. 如果 annul_i 为 0，且 cnt 为 32，那么表示试商法结束，如果是有符号除法，且被除数、除数一正一副，那么结果取补码 此处的商、余数都要取补码
              //     商保存在 dividend 的低 32 位，余数保存在 dividend 的高 32 位，同时进入 DivEnd 状态
              if(annul_i == 1'b0)
                begin
                  if(cnt != 6'b100000)
                    begin
                      // still on
                      if(div_temp[32] == 1'b1)
                        begin
                          // 如果 div_temp[32] 为 1，表示 minuend-n 结果小于 0，将 dividend 想做移一位
                          // 这样就将被除数还没有参与运算的最高位加入到下一次迭代的被减数中，同事将 0 追加到中间结果
                          dividend <= {dividend[63:0], 1'b0};
                        end
                      else
                        begin
                          // 如果 div_temp[32] 为 0， 表示 minuend-n >= 0
                          // 将减法的结果与被除数还没有参与运算的最高位加入到下一次迭代的被减数中，同时将 1 追加到中间结果
                          dividend <= {div_temp[31:0], dividend[31:0], 1'b1};
                        end
                      cnt <= cnt +1;
                    end
                  else
                    begin
                      // 试商法结束
                      if((signed_div_i == 1'b1) && ((opdata1_i[31] ^ opdata2_i[31]) == 1'b1))
                        begin
                          dividend[31:0] <= (~dividend[31:0] + 1);
                        end
                      if((signed_div_i == 1'b1) && ((opdata1_i[31] ^ dividend[64]) == 1'b1))
                        begin
                          dividend[64:33] <= (~dividend[64:33] + 1);
                        end
                      // Switch to `DivEnd
                      state <= `DivEnd;
                      // clear cnt
                      cnt <= 6'b0;
                    end
                end
              else
                begin
                  // 如果 annul_i 为 1，那么直接回到 DivFree 状态
                  state <= `DivFree;
                end
            end
          `DivEnd:
            begin
              // 除法运算结束， result_o 的宽度是 64 位，其高 32 位存储余数，低 32 位存储商
              // 设置输出信号 ready_o 为 DivResultReady，表示除法结束，然后等待 EX 模块
              // 送来 DivStop 信号，当 EX 模块送来 DivStop 信号时，Div 模块回到 DivFree 状态
              result_o <= {dividend[64:33], dividend[31:0]};
              ready_o <= `DivResultReady;
              if(start_i == `DivStop)
                begin
                  state <= `DivFree;
                  ready_o <= `DivResultNotReady;
                  result_o <= {`ZeroWord, `ZeroWord};
                end
            end
          default:
            begin
            end
        endcase
      end
  end

endmodule // div
