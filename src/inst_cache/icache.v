`timescale 1ns / 1ps

module inst_cache(
    input         clk,
    input         rstn,
    input         flush,

    // axi
    // ar
    output [3 :0] arid   ,
    output [31:0] araddr ,
    output [7 :0] arlen  ,
    output [2 :0] arsize ,
    output [1 :0] arburst,
    output [1 :0] arlock ,
    output [3 :0] arcache,
    output [2 :0] arprot ,
    output        arvalid,
    input         arready,
    //r
    input  [3 :0] rid    ,
    input  [31:0] rdata  ,
    input  [1 :0] rresp ,
    input         rlast ,
    input         rvalid ,
    output        rready ,

    // from cpu, sram like
    input         inst_req,
    input  [31:0] inst_addr,
    output        inst_addr_ready,
    output [31:0] inst_addr_out,
    output        inst_data_ok,
    output [31:0] inst_rdata,

    input         inst_cache
    );

    wire rst;
    assign rst = ~rstn;

    reg[127:0] lru1;
    reg[127:0] lru2[1:0];

    wire work0, work1, work2, work3;
    wire hit0, hit1, hit2, hit3, hit;
    wire valid0, valid1, valid2, valid3, valid;
    wire[31:0] access_cache_addr;
    wire tag0_wen, tag1_wen, tag2_wen, tag3_wen;
    wire[20:0] tag_wdata;
    wire op0, op1, op2, op3;

    reg[31:0] inst_addr_r;
    always @ (posedge clk) begin
        if (inst_req == 1'b1 || flush) begin
            inst_addr_r <= inst_addr;
        end
    end
    assign inst_addr_out = (flushed ? 32'b0 : inst_addr_r);
    wire[31:0] inst_addr_mapped;
    assign inst_addr_mapped  =  (inst_addr_r[31:29] == 3'b100 ||
                                inst_addr_r[31:29] == 3'b101) ?
                                { 3'b0, inst_addr_r[28:0]} : inst_addr_r;

    // wire inst_cache = inst_addr[31:29] == 3'b101 ? 1'b0 : 1'b1;
    // assign inst_cache = inst_addr_r[31:29] == 3'b101 ? 1'b0 : 1'b1;
    reg inst_cache_r;
    always @ (posedge clk) begin
        if (inst_req == 1'b1) begin
            inst_cache_r <= inst_cache;
        end
    end

    wire flushed;
    // assign flushed = flush ? 1'b1 :
    //                  (rst || work_state == state_reset || work_state == state_lookup) ? 1'b0 : flushed;
    reg flushed_r;
    always @ (posedge clk) begin
        if (rst || work_state == state_reset || work_state == state_lookup || inst_data_ok == 1'b1) begin
            flushed_r <= 1'b0;
        end else if (flush)
            flushed_r <= 1'b1;
    end
    assign flushed = flush || flushed_r;

    icache_tag icache_tag_0(rst, clk, tag0_wen, tag_wdata, access_cache_addr, hit0, valid0, work0, op0);
    icache_tag icache_tag_1(rst, clk, tag1_wen, tag_wdata, access_cache_addr, hit1, valid1, work1, op1);
    icache_tag icache_tag_2(rst, clk, tag2_wen, tag_wdata, access_cache_addr, hit2, valid2, work2, op2);
    icache_tag icache_tag_3(rst, clk, tag3_wen, tag_wdata, access_cache_addr, hit3, valid3, work3, op3);

    wire[31:0] icache_way0_0_rdata;
    wire[31:0] icache_way0_1_rdata;
    wire[31:0] icache_way0_2_rdata;
    wire[31:0] icache_way0_3_rdata;
    wire[31:0] icache_way0_4_rdata;
    wire[31:0] icache_way0_5_rdata;
    wire[31:0] icache_way0_6_rdata;
    wire[31:0] icache_way0_7_rdata;

    wire[31:0] icache_way1_0_rdata;
    wire[31:0] icache_way1_1_rdata;
    wire[31:0] icache_way1_2_rdata;
    wire[31:0] icache_way1_3_rdata;
    wire[31:0] icache_way1_4_rdata;
    wire[31:0] icache_way1_5_rdata;
    wire[31:0] icache_way1_6_rdata;
    wire[31:0] icache_way1_7_rdata;

    wire[31:0] icache_way2_0_rdata;
    wire[31:0] icache_way2_1_rdata;
    wire[31:0] icache_way2_2_rdata;
    wire[31:0] icache_way2_3_rdata;
    wire[31:0] icache_way2_4_rdata;
    wire[31:0] icache_way2_5_rdata;
    wire[31:0] icache_way2_6_rdata;
    wire[31:0] icache_way2_7_rdata;

    wire[31:0] icache_way3_0_rdata;
    wire[31:0] icache_way3_1_rdata;
    wire[31:0] icache_way3_2_rdata;
    wire[31:0] icache_way3_3_rdata;
    wire[31:0] icache_way3_4_rdata;
    wire[31:0] icache_way3_5_rdata;
    wire[31:0] icache_way3_6_rdata;
    wire[31:0] icache_way3_7_rdata;

    wire[7:0] way0_wen;
    wire[7:0] way1_wen;
    wire[7:0] way2_wen;
    wire[7:0] way3_wen;
    wire[31:0] way_wdata;

    icache_data way0_data_0(clk, rst, 1'b1, {4{way0_wen[0]}}, way_wdata, access_cache_addr, icache_way0_0_rdata);
    icache_data way0_data_1(clk, rst, 1'b1, {4{way0_wen[1]}}, way_wdata, access_cache_addr, icache_way0_1_rdata);
    icache_data way0_data_2(clk, rst, 1'b1, {4{way0_wen[2]}}, way_wdata, access_cache_addr, icache_way0_2_rdata);
    icache_data way0_data_3(clk, rst, 1'b1, {4{way0_wen[3]}}, way_wdata, access_cache_addr, icache_way0_3_rdata);
    icache_data way0_data_4(clk, rst, 1'b1, {4{way0_wen[4]}}, way_wdata, access_cache_addr, icache_way0_4_rdata);
    icache_data way0_data_5(clk, rst, 1'b1, {4{way0_wen[5]}}, way_wdata, access_cache_addr, icache_way0_5_rdata);
    icache_data way0_data_6(clk, rst, 1'b1, {4{way0_wen[6]}}, way_wdata, access_cache_addr, icache_way0_6_rdata);
    icache_data way0_data_7(clk, rst, 1'b1, {4{way0_wen[7]}}, way_wdata, access_cache_addr, icache_way0_7_rdata);

    icache_data way1_data_0(clk, rst, 1'b1, {4{way1_wen[0]}}, way_wdata, access_cache_addr, icache_way1_0_rdata);
    icache_data way1_data_1(clk, rst, 1'b1, {4{way1_wen[1]}}, way_wdata, access_cache_addr, icache_way1_1_rdata);
    icache_data way1_data_2(clk, rst, 1'b1, {4{way1_wen[2]}}, way_wdata, access_cache_addr, icache_way1_2_rdata);
    icache_data way1_data_3(clk, rst, 1'b1, {4{way1_wen[3]}}, way_wdata, access_cache_addr, icache_way1_3_rdata);
    icache_data way1_data_4(clk, rst, 1'b1, {4{way1_wen[4]}}, way_wdata, access_cache_addr, icache_way1_4_rdata);
    icache_data way1_data_5(clk, rst, 1'b1, {4{way1_wen[5]}}, way_wdata, access_cache_addr, icache_way1_5_rdata);
    icache_data way1_data_6(clk, rst, 1'b1, {4{way1_wen[6]}}, way_wdata, access_cache_addr, icache_way1_6_rdata);
    icache_data way1_data_7(clk, rst, 1'b1, {4{way1_wen[7]}}, way_wdata, access_cache_addr, icache_way1_7_rdata);

    icache_data way2_data_0(clk, rst, 1'b1, {4{way2_wen[0]}}, way_wdata, access_cache_addr, icache_way2_0_rdata);
    icache_data way2_data_1(clk, rst, 1'b1, {4{way2_wen[1]}}, way_wdata, access_cache_addr, icache_way2_1_rdata);
    icache_data way2_data_2(clk, rst, 1'b1, {4{way2_wen[2]}}, way_wdata, access_cache_addr, icache_way2_2_rdata);
    icache_data way2_data_3(clk, rst, 1'b1, {4{way2_wen[3]}}, way_wdata, access_cache_addr, icache_way2_3_rdata);
    icache_data way2_data_4(clk, rst, 1'b1, {4{way2_wen[4]}}, way_wdata, access_cache_addr, icache_way2_4_rdata);
    icache_data way2_data_5(clk, rst, 1'b1, {4{way2_wen[5]}}, way_wdata, access_cache_addr, icache_way2_5_rdata);
    icache_data way2_data_6(clk, rst, 1'b1, {4{way2_wen[6]}}, way_wdata, access_cache_addr, icache_way2_6_rdata);
    icache_data way2_data_7(clk, rst, 1'b1, {4{way2_wen[7]}}, way_wdata, access_cache_addr, icache_way2_7_rdata);

    icache_data way3_data_0(clk, rst, 1'b1, {4{way3_wen[0]}}, way_wdata, access_cache_addr, icache_way3_0_rdata);
    icache_data way3_data_1(clk, rst, 1'b1, {4{way3_wen[1]}}, way_wdata, access_cache_addr, icache_way3_1_rdata);
    icache_data way3_data_2(clk, rst, 1'b1, {4{way3_wen[2]}}, way_wdata, access_cache_addr, icache_way3_2_rdata);
    icache_data way3_data_3(clk, rst, 1'b1, {4{way3_wen[3]}}, way_wdata, access_cache_addr, icache_way3_3_rdata);
    icache_data way3_data_4(clk, rst, 1'b1, {4{way3_wen[4]}}, way_wdata, access_cache_addr, icache_way3_4_rdata);
    icache_data way3_data_5(clk, rst, 1'b1, {4{way3_wen[5]}}, way_wdata, access_cache_addr, icache_way3_5_rdata);
    icache_data way3_data_6(clk, rst, 1'b1, {4{way3_wen[6]}}, way_wdata, access_cache_addr, icache_way3_6_rdata);
    icache_data way3_data_7(clk, rst, 1'b1, {4{way3_wen[7]}}, way_wdata, access_cache_addr, icache_way3_7_rdata);

    reg[31:0] wait_data;
    reg[2:0] write_counter;
    reg[3:0] work_state;
    parameter[3:0] state_reset = 4'b0000;
    parameter[3:0] state_lookup = 4'b0001;
    parameter[3:0] state_access_ram_0 = 4'b0010;
    parameter[3:0] state_access_ram_1 = 4'b0011;
    parameter[3:0] state_data_ready = 4'b0100;
    parameter[3:0] state_miss_access_ram_0 = 4'b0101;
    parameter[3:0] state_miss_access_ram_1 = 4'b0110;
    parameter[3:0] state_miss_update = 4'b0111;

    always @ (posedge clk) begin
        if (rst) begin
            work_state <= state_reset;
            wait_data <= 32'b0;
            write_counter <= 3'b000;
        end else if (work_state == state_reset && inst_req == 1'b1) begin                   // state: 0
            if ((work0 & work1 & work2 & work3) == 1'b1 && inst_cache == 1'b1) begin
                work_state <= state_lookup;
            end else begin
                work_state <= state_access_ram_0;
            end
        end else if (work_state == state_access_ram_0 && arready == 1'b1) begin             // state: 2
            work_state <= state_access_ram_1;
        end else if (work_state == state_access_ram_1 && rvalid) begin                      // state: 3
            work_state <= state_data_ready;
            wait_data <= rdata;
        end else if (work_state == state_data_ready) begin                                  // state: 4
            if (inst_req || flush) begin
                if ((work0 & work1 & work2 & work3) == 1'b1 && inst_cache == 1'b1) begin
                    work_state <= state_lookup;
                end else begin
                    work_state <= state_access_ram_0;
                end
            end else work_state <= state_reset;
        end else if (work_state == state_lookup) begin                                      // state: 1
            if (hit) begin
                if (inst_req||flush) begin
                    if ((work0 & work1 & work2 & work3) == 1'b1 && inst_cache == 1'b1) begin
                        work_state <= state_lookup;
                    end else begin
                        work_state <= state_access_ram_0;
                    end
                end else
                    work_state <= state_reset;
            end else
                work_state <= state_miss_access_ram_0;
        end else if (work_state == state_miss_access_ram_0 && arready == 1'b1) begin        // state: 5
            work_state <= state_miss_access_ram_1;
        end else if (work_state == state_miss_access_ram_1) begin                           // state: 6
            if (rvalid) begin
                write_counter <= write_counter + 1'b1;
                if (write_counter == inst_addr_r[4:2]) wait_data = rdata;
            end
            if (rlast && rvalid) begin
                write_counter <= 3'b000;
                work_state <= state_miss_update;
            end
        end else if (work_state == state_miss_update) begin                                 // state: 7
            work_state <= state_data_ready;
        end
    end

    // LRU更新
    wire way0_is_victim, way1_is_victim, way2_is_victim, way3_is_victim;
    always @ (posedge clk) begin
        if (rst) begin
           lru1 <= 128'b0;
           lru2[0] <= 128'b0;
           lru2[1] <= 128'b0;
        end else begin
            if (work_state == state_lookup) begin
                if (hit0 && valid0) begin
                    lru1[inst_addr_r[11:5]] <= 1'b1;
                    lru2[0][inst_addr_r[11:5]] <= 1'b1;
                end else if (hit1 && valid1) begin
                    lru1[inst_addr_r[11:5]] <= 1'b1;
                    lru2[0][inst_addr_r[11:5]] <= 1'b0;
                end else if (hit2 && valid2) begin
                    lru1[inst_addr_r[11:5]] <= 1'b0;
                    lru2[1][inst_addr_r[11:5]] <= 1'b1;
                end else if (hit3 && valid3) begin
                    lru1[inst_addr_r[11:5]] <= 1'b0;
                    lru2[1][inst_addr_r[11:5]] <= 1'b0;
                end
            end else if ( work_state == state_miss_update) begin
                if (way0_is_victim || way1_is_victim) begin
                    lru1[inst_addr_r[11:5]] <= ~lru1[inst_addr_r[11:5]];
                    lru2[0][inst_addr_r[11:5]] <= ~lru2[0][inst_addr_r[11:5]];
                end else if (way2_is_victim || way3_is_victim) begin
                    lru1[inst_addr_r[11:5]] <= ~lru1[inst_addr_r[11:5]];
                    lru2[1][inst_addr_r[11:5]] <= ~lru2[1][inst_addr_r[11:5]];
                end
            end
        end
    end



    assign hit = (hit0 && valid0) || (hit1 && valid1) || (hit2 && valid2) || (hit3 && valid3);
    assign access_cache_addr = inst_req == 1'b1 ? inst_addr : inst_addr_r;
    wire[31:0] word_selection0, word_selection1, word_selection2, word_selection3;
    assign word_selection0 = (inst_addr_r[4:2] == 3'b000) ? icache_way0_0_rdata :
                             (inst_addr_r[4:2] == 3'b001) ? icache_way0_1_rdata :
                             (inst_addr_r[4:2] == 3'b010) ? icache_way0_2_rdata :
                             (inst_addr_r[4:2] == 3'b011) ? icache_way0_3_rdata :
                             (inst_addr_r[4:2] == 3'b100) ? icache_way0_4_rdata :
                             (inst_addr_r[4:2] == 3'b101) ? icache_way0_5_rdata :
                             (inst_addr_r[4:2] == 3'b110) ? icache_way0_6_rdata :
                             (inst_addr_r[4:2] == 3'b111) ? icache_way0_7_rdata : 32'b0;
    assign word_selection1 = (inst_addr_r[4:2] == 3'b000) ? icache_way1_0_rdata :
                             (inst_addr_r[4:2] == 3'b001) ? icache_way1_1_rdata :
                             (inst_addr_r[4:2] == 3'b010) ? icache_way1_2_rdata :
                             (inst_addr_r[4:2] == 3'b011) ? icache_way1_3_rdata :
                             (inst_addr_r[4:2] == 3'b100) ? icache_way1_4_rdata :
                             (inst_addr_r[4:2] == 3'b101) ? icache_way1_5_rdata :
                             (inst_addr_r[4:2] == 3'b110) ? icache_way1_6_rdata :
                             (inst_addr_r[4:2] == 3'b111) ? icache_way1_7_rdata : 32'b0;
    assign word_selection2 = (inst_addr_r[4:2] == 3'b000) ? icache_way2_0_rdata :
                             (inst_addr_r[4:2] == 3'b001) ? icache_way2_1_rdata :
                             (inst_addr_r[4:2] == 3'b010) ? icache_way2_2_rdata :
                             (inst_addr_r[4:2] == 3'b011) ? icache_way2_3_rdata :
                             (inst_addr_r[4:2] == 3'b100) ? icache_way2_4_rdata :
                             (inst_addr_r[4:2] == 3'b101) ? icache_way2_5_rdata :
                             (inst_addr_r[4:2] == 3'b110) ? icache_way2_6_rdata :
                             (inst_addr_r[4:2] == 3'b111) ? icache_way2_7_rdata : 32'b0;
    assign word_selection3 = (inst_addr_r[4:2] == 3'b000) ? icache_way3_0_rdata :
                             (inst_addr_r[4:2] == 3'b001) ? icache_way3_1_rdata :
                             (inst_addr_r[4:2] == 3'b010) ? icache_way3_2_rdata :
                             (inst_addr_r[4:2] == 3'b011) ? icache_way3_3_rdata :
                             (inst_addr_r[4:2] == 3'b100) ? icache_way3_4_rdata :
                             (inst_addr_r[4:2] == 3'b101) ? icache_way3_5_rdata :
                             (inst_addr_r[4:2] == 3'b110) ? icache_way3_6_rdata :
                             (inst_addr_r[4:2] == 3'b111) ? icache_way3_7_rdata : 32'b0;
    wire[31:0] hit_word;
    assign hit_word = (hit0 && valid0) ? word_selection0 :
                      (hit1 && valid1) ? word_selection1 :
                      (hit2 && valid2) ? word_selection2 :
                      (hit3 && valid3) ? word_selection3 : 32'b0;

    assign way0_is_victim = ((lru1[inst_addr_r[11:5]] == 1'b0) & (lru2[0][inst_addr_r[11:5]] == 1'b0));
    assign way1_is_victim = ((lru1[inst_addr_r[11:5]] == 1'b0) & (lru2[0][inst_addr_r[11:5]] == 1'b1));
    assign way2_is_victim = ((lru1[inst_addr_r[11:5]] == 1'b1) & (lru2[1][inst_addr_r[11:5]] == 1'b0));
    assign way3_is_victim = ((lru1[inst_addr_r[11:5]] == 1'b1) & (lru2[1][inst_addr_r[11:5]] == 1'b1));

    assign way_wdata = rdata;
    assign way0_wen[0] = (work_state == state_miss_access_ram_1 && rvalid && way0_is_victim && write_counter == 3'b000) ? 1'b1 : 1'b0;
    assign way0_wen[1] = (work_state == state_miss_access_ram_1 && rvalid && way0_is_victim && write_counter == 3'b001) ? 1'b1 : 1'b0;
    assign way0_wen[2] = (work_state == state_miss_access_ram_1 && rvalid && way0_is_victim && write_counter == 3'b010) ? 1'b1 : 1'b0;
    assign way0_wen[3] = (work_state == state_miss_access_ram_1 && rvalid && way0_is_victim && write_counter == 3'b011) ? 1'b1 : 1'b0;
    assign way0_wen[4] = (work_state == state_miss_access_ram_1 && rvalid && way0_is_victim && write_counter == 3'b100) ? 1'b1 : 1'b0;
    assign way0_wen[5] = (work_state == state_miss_access_ram_1 && rvalid && way0_is_victim && write_counter == 3'b101) ? 1'b1 : 1'b0;
    assign way0_wen[6] = (work_state == state_miss_access_ram_1 && rvalid && way0_is_victim && write_counter == 3'b110) ? 1'b1 : 1'b0;
    assign way0_wen[7] = (work_state == state_miss_access_ram_1 && rvalid && way0_is_victim && write_counter == 3'b111) ? 1'b1 : 1'b0;

    assign way1_wen[0] = (work_state == state_miss_access_ram_1 && rvalid && way1_is_victim && write_counter == 3'b000) ? 1'b1 : 1'b0;
    assign way1_wen[1] = (work_state == state_miss_access_ram_1 && rvalid && way1_is_victim && write_counter == 3'b001) ? 1'b1 : 1'b0;
    assign way1_wen[2] = (work_state == state_miss_access_ram_1 && rvalid && way1_is_victim && write_counter == 3'b010) ? 1'b1 : 1'b0;
    assign way1_wen[3] = (work_state == state_miss_access_ram_1 && rvalid && way1_is_victim && write_counter == 3'b011) ? 1'b1 : 1'b0;
    assign way1_wen[4] = (work_state == state_miss_access_ram_1 && rvalid && way1_is_victim && write_counter == 3'b100) ? 1'b1 : 1'b0;
    assign way1_wen[5] = (work_state == state_miss_access_ram_1 && rvalid && way1_is_victim && write_counter == 3'b101) ? 1'b1 : 1'b0;
    assign way1_wen[6] = (work_state == state_miss_access_ram_1 && rvalid && way1_is_victim && write_counter == 3'b110) ? 1'b1 : 1'b0;
    assign way1_wen[7] = (work_state == state_miss_access_ram_1 && rvalid && way1_is_victim && write_counter == 3'b111) ? 1'b1 : 1'b0;

    assign way2_wen[0] = (work_state == state_miss_access_ram_1 && rvalid && way2_is_victim && write_counter == 3'b000) ? 1'b1 : 1'b0;
    assign way2_wen[1] = (work_state == state_miss_access_ram_1 && rvalid && way2_is_victim && write_counter == 3'b001) ? 1'b1 : 1'b0;
    assign way2_wen[2] = (work_state == state_miss_access_ram_1 && rvalid && way2_is_victim && write_counter == 3'b010) ? 1'b1 : 1'b0;
    assign way2_wen[3] = (work_state == state_miss_access_ram_1 && rvalid && way2_is_victim && write_counter == 3'b011) ? 1'b1 : 1'b0;
    assign way2_wen[4] = (work_state == state_miss_access_ram_1 && rvalid && way2_is_victim && write_counter == 3'b100) ? 1'b1 : 1'b0;
    assign way2_wen[5] = (work_state == state_miss_access_ram_1 && rvalid && way2_is_victim && write_counter == 3'b101) ? 1'b1 : 1'b0;
    assign way2_wen[6] = (work_state == state_miss_access_ram_1 && rvalid && way2_is_victim && write_counter == 3'b110) ? 1'b1 : 1'b0;
    assign way2_wen[7] = (work_state == state_miss_access_ram_1 && rvalid && way2_is_victim && write_counter == 3'b111) ? 1'b1 : 1'b0;

    assign way3_wen[0] = (work_state == state_miss_access_ram_1 && rvalid && way3_is_victim && write_counter == 3'b000) ? 1'b1 : 1'b0;
    assign way3_wen[1] = (work_state == state_miss_access_ram_1 && rvalid && way3_is_victim && write_counter == 3'b001) ? 1'b1 : 1'b0;
    assign way3_wen[2] = (work_state == state_miss_access_ram_1 && rvalid && way3_is_victim && write_counter == 3'b010) ? 1'b1 : 1'b0;
    assign way3_wen[3] = (work_state == state_miss_access_ram_1 && rvalid && way3_is_victim && write_counter == 3'b011) ? 1'b1 : 1'b0;
    assign way3_wen[4] = (work_state == state_miss_access_ram_1 && rvalid && way3_is_victim && write_counter == 3'b100) ? 1'b1 : 1'b0;
    assign way3_wen[5] = (work_state == state_miss_access_ram_1 && rvalid && way3_is_victim && write_counter == 3'b101) ? 1'b1 : 1'b0;
    assign way3_wen[6] = (work_state == state_miss_access_ram_1 && rvalid && way3_is_victim && write_counter == 3'b110) ? 1'b1 : 1'b0;
    assign way3_wen[7] = (work_state == state_miss_access_ram_1 && rvalid && way3_is_victim && write_counter == 3'b111) ? 1'b1 : 1'b0;

    assign tag0_wen = (work_state == state_miss_update && way0_is_victim) ? 1'b1 : 1'b0;
    assign tag1_wen = (work_state == state_miss_update && way1_is_victim) ? 1'b1 : 1'b0;
    assign tag2_wen = (work_state == state_miss_update && way2_is_victim) ? 1'b1 : 1'b0;
    assign tag3_wen = (work_state == state_miss_update && way3_is_victim) ? 1'b1 : 1'b0;
    assign tag_wdata = (work_state == state_miss_update) ? {1'b1, inst_addr_r[31:12]} : 21'b0;



    // axi singal
    assign arid    = 4'b0000;
    assign araddr  = (work_state == state_access_ram_0) ? inst_addr_mapped :
                     (work_state == state_miss_access_ram_0) ? {inst_addr_r[31:5], 5'b00000} : 32'b0;
    assign arlen   = (inst_cache_r == 1'b1) ? 8'b0000_0111 : 8'b0000_0000;
    assign arsize  = 3'b010;
    assign arburst = (inst_cache_r == 1'b1) ? 2'b01 : 2'b00;
    assign arlock  = 2'b00;
    assign arcache = 4'b0000;
    assign arprot  = 3'b000;
    assign arvalid = (work_state == state_access_ram_0 || work_state == state_miss_access_ram_0) ? 1'b1 : 1'b0;

    assign rready  = 1'b1;

    // reg inst_addr_is_ready;  // 计数器,让inst_addr_ready的高只保持一个周期
    // always @ (posedge clk) begin
    //     if (rst) begin
    //         inst_addr_is_ready = 1'b0;
    //     end else if (inst_addr_is_ready == 1'b1) begin
    //         inst_addr_is_ready <= 1'b0;
    //         inst_addr_ready <= `NotReady;
    //     end else if (work_state == state_reset || work_state == state_lookup || work_state == state_data_ready) begin
    //         inst_addr_is_ready <= 1'b1;
    //         inst_addr_ready <= `Ready;
    //     end
    // end
    // assign inst_addr_ready = (work_state == state_lookup || work_state == state_access_ram_0) ? `Ready : `NotReady;
    // assign inst_addr_ready = (((arready && arvalid) || (work_state == state_lookup || work_state == state_data_ready)) && (inst_req)) ? `Ready : `NotReady;
    assign inst_addr_ready = (work_state == state_lookup || work_state == state_data_ready) && (inst_req || flushed);
    assign inst_data_ok = (work_state == state_data_ready) ? 1'b1 :
                          (work_state == state_lookup) ? hit :1'b0;
    assign inst_rdata = (work_state == state_data_ready && ~flushed) ? wait_data :
                        (work_state == state_lookup && ~flushed) ? hit_word : 32'b0;

endmodule
