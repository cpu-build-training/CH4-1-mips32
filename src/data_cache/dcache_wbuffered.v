`timescale 1ns / 1ps

module dcache_wbuffered(
    input         clk ,
    input         rstn,     // 低有效
    
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
    input  [1 :0] rresp  ,
    input         rlast  ,
    input         rvalid ,
    output        rready ,
    // uncached写由dcache直接完成,因此仍然需要这些写相关的axi信号
    //aw
    output [3 :0] awid   ,
    output [31:0] awaddr ,
    output [7 :0] awlen  ,
    output [2 :0] awsize ,
    output [1 :0] awburst,
    output [1 :0] awlock ,
    output [3 :0] awcache,
    output [2 :0] awprot ,
    output        awvalid,
    input         awready,
    //w
    output [3 :0] wid    ,
    output [31:0] wdata  ,
    output [3 :0] wstrb  ,
    output        wlast  ,
    output        wvalid ,
    input         wready ,
    //b
    input  [3 :0] bid    ,
    input  [1 :0] bresp  ,
    input         bvalid ,
    output        bready ,

    // wbuffer
    output        wbuffer_wreq      ,
    input         wbuffer_wreq_recvd,
    input         wbuffer_wdone     ,

    output [31:0] wbuffer_wdata_paddr,
    output [31:0] wbuffer_wdata_bank0,
    output [31:0] wbuffer_wdata_bank1,
    output [31:0] wbuffer_wdata_bank2,
    output [31:0] wbuffer_wdata_bank3,
    output [31:0] wbuffer_wdata_bank4,
    output [31:0] wbuffer_wdata_bank5,
    output [31:0] wbuffer_wdata_bank6,
    output [31:0] wbuffer_wdata_bank7,

    input         wbuffer_empty     ,
    output        wbuffer_clear_req ,
    input         wbuffer_clear_done,

    output        wbuffer_lookup_req  ,
    output        wbuffer_lookup_paddr,

    input         lookup_res_hit     ,
    input  [31:0] wbuffer_rdata_bank0,
    input  [31:0] wbuffer_rdata_bank1,
    input  [31:0] wbuffer_rdata_bank2,
    input  [31:0] wbuffer_rdata_bank3,
    input  [31:0] wbuffer_rdata_bank4,
    input  [31:0] wbuffer_rdata_bank5,
    input  [31:0] wbuffer_rdata_bank6,
    input  [31:0] wbuffer_rdata_bank7,
    
    // from cpu, sram like
    input         data_req    ,
    input         data_wr     ,
    input  [3:0]  data_sel    ,
    input  [31:0] data_addr   ,
    input  [31:0] data_wdata  ,
    output        data_addr_ok,
    output        data_data_ok,
    output [31:0] data_rdata

    // input         data_cache
    );
    
    wire rst;
    assign rst = ~rstn;
    
    wire data_cache = data_addr[31:29] == 3'b101 ? 1'b0 : 1'b1;

    wire[31:0] data_paddr;
    assign data_paddr = (data_addr[31:29] == 3'b100 ||
                    data_addr[31:29] == 3'b101) ? 
                    {3'b0, data_addr[28:0]} : data_addr;
    reg[31:0] data_paddr_r;
    reg[31:0] data_wdata_r;
    reg[3:0]  data_sel_r;
    reg       data_cache_r;
    always @ (posedge clk) begin
        if (data_req) begin
            data_paddr_r     <= data_paddr;
            data_wdata_r    <= data_wdata;
            data_sel_r      <= data_sel;
            data_cache_r    <= data_cache;
        end
    end
    
    
    reg[127:0] lru;
    reg[127:0] way0_dirty;
    reg[127:0] way1_dirty;
    
    wire tag0_wen;
    wire tag1_wen;
    wire[20:0] tag_wdata;
    wire[31:0] access_cache_addr;
    wire hit0, hit1, hit;
    wire valid0, valid1;
    wire work0, work1;
    wire op0, op1;
    wire[19:0] tag0_rdata, tag1_rdata;
    dcache_tag dcache_tag_0(rst, clk, tag0_wen, tag_wdata, access_cache_addr, tag0_rdata, hit0, valid0, work0, op0);
    dcache_tag dcache_tag_1(rst, clk, tag1_wen, tag_wdata, access_cache_addr, tag1_rdata, hit1, valid1, work1, op1);
    
    wire[31:0] dcache_way0_0_rdata;
    wire[31:0] dcache_way0_1_rdata;
    wire[31:0] dcache_way0_2_rdata;
    wire[31:0] dcache_way0_3_rdata;
    wire[31:0] dcache_way0_4_rdata;
    wire[31:0] dcache_way0_5_rdata;
    wire[31:0] dcache_way0_6_rdata;
    wire[31:0] dcache_way0_7_rdata;
    wire[31:0] dcache_way1_0_rdata;
    wire[31:0] dcache_way1_1_rdata;
    wire[31:0] dcache_way1_2_rdata;
    wire[31:0] dcache_way1_3_rdata;
    wire[31:0] dcache_way1_4_rdata;
    wire[31:0] dcache_way1_5_rdata;
    wire[31:0] dcache_way1_6_rdata;
    wire[31:0] dcache_way1_7_rdata;
    
    wire[31:0] cache_wdata;
    wire[7:0]  way0_wen;
    wire[7:0]  way1_wen;
    wire[3:0]  way0_data0_wen;
    wire[3:0]  way0_data1_wen;
    wire[3:0]  way0_data2_wen;
    wire[3:0]  way0_data3_wen;
    wire[3:0]  way0_data4_wen;
    wire[3:0]  way0_data5_wen;
    wire[3:0]  way0_data6_wen;
    wire[3:0]  way0_data7_wen;
    wire[3:0]  way1_data0_wen;
    wire[3:0]  way1_data1_wen;
    wire[3:0]  way1_data2_wen;
    wire[3:0]  way1_data3_wen;
    wire[3:0]  way1_data4_wen;
    wire[3:0]  way1_data5_wen;
    wire[3:0]  way1_data6_wen;
    wire[3:0]  way1_data7_wen;
    
    
    
    dcache_data way0_data_0(clk, rst, 1'b1, way0_data0_wen, cache_wdata, access_cache_addr, dcache_way0_0_rdata);
    dcache_data way0_data_1(clk, rst, 1'b1, way0_data1_wen, cache_wdata, access_cache_addr, dcache_way0_1_rdata);
    dcache_data way0_data_2(clk, rst, 1'b1, way0_data2_wen, cache_wdata, access_cache_addr, dcache_way0_2_rdata);
    dcache_data way0_data_3(clk, rst, 1'b1, way0_data3_wen, cache_wdata, access_cache_addr, dcache_way0_3_rdata);
    dcache_data way0_data_4(clk, rst, 1'b1, way0_data4_wen, cache_wdata, access_cache_addr, dcache_way0_4_rdata);
    dcache_data way0_data_5(clk, rst, 1'b1, way0_data5_wen, cache_wdata, access_cache_addr, dcache_way0_5_rdata);
    dcache_data way0_data_6(clk, rst, 1'b1, way0_data6_wen, cache_wdata, access_cache_addr, dcache_way0_6_rdata);
    dcache_data way0_data_7(clk, rst, 1'b1, way0_data7_wen, cache_wdata, access_cache_addr, dcache_way0_7_rdata);
    dcache_data way1_data_0(clk, rst, 1'b1, way1_data0_wen, cache_wdata, access_cache_addr, dcache_way1_0_rdata);
    dcache_data way1_data_1(clk, rst, 1'b1, way1_data1_wen, cache_wdata, access_cache_addr, dcache_way1_1_rdata);
    dcache_data way1_data_2(clk, rst, 1'b1, way1_data2_wen, cache_wdata, access_cache_addr, dcache_way1_2_rdata);
    dcache_data way1_data_3(clk, rst, 1'b1, way1_data3_wen, cache_wdata, access_cache_addr, dcache_way1_3_rdata);
    dcache_data way1_data_4(clk, rst, 1'b1, way1_data4_wen, cache_wdata, access_cache_addr, dcache_way1_4_rdata);
    dcache_data way1_data_5(clk, rst, 1'b1, way1_data5_wen, cache_wdata, access_cache_addr, dcache_way1_5_rdata);
    dcache_data way1_data_6(clk, rst, 1'b1, way1_data6_wen, cache_wdata, access_cache_addr, dcache_way1_6_rdata);
    dcache_data way1_data_7(clk, rst, 1'b1, way1_data7_wen, cache_wdata, access_cache_addr, dcache_way1_7_rdata);
    
    
    wire victim_is_dirty;
    reg[2:0] write_counter;
    reg[2:0] read_counter;
    reg[31:0] wait_data;
    reg[4:0] work_state;
    reg[4:0] next_work_state;  // 转移到下个状态后,下个状态再转移到哪个状态  用于状态合并
    parameter[4:0] state_idle                           = 5'b00000;

    parameter[4:0] state_uncached_read_addr_hshake      = 5'b00001;
    parameter[4:0] state_uncached_read_data_transf      = 5'b00010;

    parameter[4:0] state_uncached_write_addr_hshake     = 5'b00011;
    parameter[4:0] state_uncached_write_data_transf     = 5'b00100;
    parameter[4:0] state_uncahed_write_waitfor_bv       = 5'b00101;

    // 与state_idle完全相同,且在没有请求的情况下会无条件转换至idle
    // 设这个状态只是为了在这个状态下发出data_ok
    parameter[4:0] state_rw_done                        = 5'b00110;

    parameter[4:0] state_cached_read_lookup             = 5'b00111;
    parameter[4:0] state_cached_write_lookup            = 5'b01000;

    // parameter[4:0] state_miss_read_wb_addr_hshake       = 5'b01001;
    // parameter[4:0] state_miss_read_wb_data_transf       = 5'b01010;
    // parameter[4:0] state_miss_read_wb_waitfor_bv        = 5'b01011;
    parameter[4:0] state_miss_read_wb_wreq              = 5'b01001;
    parameter[4:0] state_miss_read_wb_waitfor_wdone     = 5'b01010;

    parameter[4:0] state_miss_read_fetch_addr_hshake    = 5'b01100;
    parameter[4:0] state_miss_read_fetch_data_transf    = 5'b01101;
    parameter[4:0] state_miss_read_update               = 5'b01110;

    // parameter[4:0] state_miss_write_wb_addr_hshake      = 5'b01111;
    // parameter[4:0] state_miss_write_wb_data_transf      = 5'b10000;
    // parameter[4:0] state_miss_write_wb_waitfor_bv       = 5'b10001;
    parameter[4:0] state_miss_write_wb_wreq             = 5'b01111;
    parameter[4:0] state_miss_write_wb_waitfor_wdone    = 5'b10000;

    parameter[4:0] state_miss_write_fetch_addr_hshake   = 5'b10010;
    parameter[4:0] state_miss_write_fetch_data_transf   = 5'b10011;
    parameter[4:0] state_miss_write_update              = 5'b10100;
    

    
    always @ (posedge clk) begin
        if (rst) begin
            work_state <= state_idle;
            wait_data <= 32'b0;
            write_counter <= 3'b0;
            read_counter <= 3'b0;
        end else begin
            case(work_state)
            state_idle: begin 
                if (data_req == 1'b1) begin
                    if (data_wr == 1'b0) begin
                        if (work0 && work1 && data_cache)
                            work_state <= state_cached_read_lookup;
                        else
                            work_state <= state_uncached_read_addr_hshake;
                    end else if (data_wr == 1'b1) begin
                        if (work0 && work1 && data_cache)
                            work_state <= state_cached_write_lookup;
                        else
                            work_state <= state_uncached_write_addr_hshake;
                    end
                end
            end
            // uncached read
            state_uncached_read_addr_hshake: begin
                if (arready)
                    work_state <= state_uncached_read_data_transf;
            end
            state_uncached_read_data_transf: begin
                if (rvalid) begin
                    work_state <= state_rw_done;
                    wait_data <= rdata;
                end
            end
            // uncached/cached read/write done
            state_rw_done: begin
                if (data_req == 1'b1) begin
                    if (data_wr == 1'b0) begin
                        if (work0 && work1 && data_cache)
                            work_state <= state_cached_read_lookup;
                        else
                            work_state <= state_uncached_read_addr_hshake;
                    end else if (data_wr == 1'b1) begin
                        if (work0 && work1 && data_cache)
                            work_state <= state_cached_write_lookup;
                        else
                            work_state <= state_uncached_write_addr_hshake;
                    end
                end else
                    work_state <= state_idle;
            end
            // uncached write
            //////////////////////////////////////////////////////////
            state_uncached_write_addr_hshake: begin
                if (awready)
                    work_state <= state_uncached_write_data_transf;
            end 
            state_uncached_write_data_transf: begin
                if (wready)
                    work_state <= state_uncahed_write_waitfor_bv;
            end 
            state_uncahed_write_waitfor_bv: begin
                if (bvalid)
                    work_state <= state_rw_done;
            end
            //////////////////////////////////////////////////////////

            // cached read
            state_cached_read_lookup: begin
                if (hit) begin
                    if (data_req == 1'b1) begin
                        if (data_wr == 1'b0) begin
                            if (work0 && work1 && data_cache)
                                work_state <= state_cached_read_lookup;
                            else 
                                work_state <= state_uncached_read_addr_hshake;
                        end else if (data_wr == 1'b1) begin
                            if (work0 && work1 && data_cache)
                                work_state <= state_cached_write_lookup;
                            else
                                work_state <= state_uncached_write_addr_hshake;
                        end
                    end else
                        work_state <= state_idle;
                end
                else begin
                    // 读未命中,开始在wbuffer中找有没有需要的行
                    // 该状态下发出wbuffer_lookup_req与wbuffer_lookup_paddr
                    work_state <= state_
                    // if (victim_is_dirty)
                    //     work_state <= state_miss_read_wb_addr_hshake;
                    // else
                    //     work_state <= state_miss_read_fetch_addr_hshake;

                    // if(!wbuffer_empty)
                    //     // 如果wbuffer不为空则需要先清空
                    //     work_state <= state_miss_read_waitfor_clear_buffer_done;
                    // else begin
                    //     if (victim_is_dirty)
                    //         // work_state <= state_miss_read_wb_addr_hshake;
                    //         work_state <= state_miss_read_wb_wreq;
                    //     else
                    //         work_state <= state_miss_read_fetch_addr_hshake;
                    // end
                end
            end
            // 读未命中,且victim不是dirty的
            // 在cached_read_lookup时若发现未命中,会发出clear_req,并转移到该状态
            // 该状态用于等待clear_done
            state_miss_read_waitfor_clear_buffer_done: begin
                if(clear_done) begin
                    if (victim_is_dirty)
                        // work_state <= state_miss_read_wb_addr_hshake;
                        work_state <= state_miss_read_wb_wreq;
                    else
                        work_state <= state_miss_read_fetch_addr_hshake;
                end
            end
            state_miss_read_fetch_addr_hshake: begin
                if (arready)
                    work_state <= state_miss_read_fetch_data_transf;
            end 
            state_miss_read_fetch_data_transf: begin
                if (rvalid) begin
                    read_counter <= read_counter + 1'b1;
                    if (read_counter == data_paddr_r[4:2])
                        wait_data = rdata;
                end
                if (rlast && rvalid) begin
                    read_counter <= 3'b000;
                    work_state <= state_miss_read_update;
                end
            end 
            state_miss_read_update: begin
                work_state <= state_rw_done;
            end 
            // 读未命中时victim是dirty的,开始写回
            // 向wbuffer发送写请求并等待wdone
            state_miss_read_wb_wreq: begin
                if(wbuffer_wreq_recvd)
                    work_state <= state_miss_read_wb_waitfor_wdone;
            end
            state_miss_read_wb_waitfor_wdone: begin
                if(wbuffer_wdone)
                    work_state <= state_miss_read_fetch_addr_hshake;
            end
            //////////////////////////////////////////////////////////
            // state_miss_read_wb_addr_hshake: begin
            //     if (awready)
            //         work_state <= state_miss_read_wb_data_transf;
            // end 
            // state_miss_read_wb_data_transf: begin
            //     if (wready) begin
            //          if (write_counter == 3'b111) begin
            //             write_counter <= 3'b000;
            //             work_state <= state_miss_read_wb_waitfor_bv;
            //          end else
            //             write_counter <= write_counter + 1'b1;
            //     end
            // end 
            // state_miss_read_wb_waitfor_bv: begin
            //     if (bvalid)
            //         work_state <= state_miss_read_fetch_addr_hshake;
            // end
            //////////////////////////////////////////////////////////

            // cached write
            // 感觉这里假设了不会连续两个周期都有写请求
            // 因此这里没有处理data_req的部分,而是交给rw_done处理,因此处理两个写请求之间要间隔一个周期
            state_cached_write_lookup: begin
                if (hit) begin
                   work_state <= state_rw_done;
                end
                else begin
                    if (victim_is_dirty)
                        work_state <= state_miss_write_wb_addr_hshake;
                    else
                        work_state <= state_miss_write_fetch_addr_hshake;
                end
            end
            // 写未命中,且victim不是dirty的
            state_miss_write_fetch_addr_hshake: begin
                if (arready)
                    work_state <= state_miss_write_fetch_data_transf;
            end 
            state_miss_write_fetch_data_transf: begin
                if (rvalid) begin
                    read_counter <= read_counter + 1'b1;
                end
                if (rlast && rvalid) begin
                    read_counter <= 3'b000;
                    work_state <= state_miss_write_update;
                end
            end
            // 改状态下更新LRU和tag,并向取到cache的行中写数据
            state_miss_write_update: begin
                work_state <= state_rw_done;
            end
            // victim是dirty的,开始写回
            // 向wbuffer发送wreq并等待wdone
            state_miss_write_wb_wreq: begin
                if(wbuffer_wreq_recvd)
                    work_state <= state_miss_write_wb_waitfor_wdone;
            end
            state_miss_write_wb_waitfor_wdone: begin
                if(wbuffer_wdone)
                    work_state <= state_miss_write_fetch_addr_hshake;
            end
            //////////////////////////////////////////////////////////
            // state_miss_write_wb_addr_hshake: begin
            //     if (awready)
            //         work_state <= state_miss_write_wb_data_transf;
            // end 
            // state_miss_write_wb_data_transf: begin
            //     if (wready) begin
            //          if (write_counter == 3'b111) begin
            //             write_counter <= 3'b000;
            //             work_state <= state_miss_write_wb_waitfor_bv;
            //          end else
            //             write_counter <= write_counter + 1'b1;
            //     end
            // end
            // state_miss_write_wb_waitfor_bv: begin
            //     if (bvalid)
            //         work_state <= state_miss_write_fetch_addr_hshake;
            //////////////////////////////////////////////////////////
            end
            default: ;
            endcase
        end
    end
    
    always @ (posedge clk) begin
        if (rst) begin
            lru <= 128'b0;
        end else begin
            if (work_state == state_cached_read_lookup || work_state == state_cached_write_lookup) begin
                if (hit0 && valid0)
                    lru[data_paddr_r[11:5]] <= 1'b1;
                else if (hit1 && valid1)
                    lru[data_paddr_r[11:5]] <= 1'b0;
            end else if (work_state == state_miss_read_update || work_state == state_miss_write_update) begin
                lru[data_paddr_r[11:5]] <= ~lru[data_paddr_r[11:5]];
            end
        end
    end
    
    always @ (posedge clk) begin
        if (rst) begin
            way0_dirty <= 128'b0;
        end else begin
            if (work_state == state_cached_write_lookup && hit0 && valid0) begin
                way0_dirty[data_paddr_r[11:5]] <= 1'b1;
            end else if (work_state == state_miss_read_update && lru[data_paddr_r[11:5]] == 1'b0) begin
                way0_dirty[data_paddr_r[11:5]] <= 1'b0;
            end else if (work_state == state_miss_write_update && lru[data_paddr_r[11:5]] == 1'b0) begin
                way0_dirty[data_paddr_r[11:5]] <= 1'b1;
            end 
        end
    end
    
    always @ (posedge clk) begin
        if (rst) begin
            way1_dirty <= 128'b0;
        end else begin
            if (work_state == state_cached_write_lookup && hit1 && valid1) begin
                way1_dirty[data_paddr_r[11:5]] <= 1'b1;
            end else if (work_state == state_miss_read_update && lru[data_paddr_r[11:5]] == 1'b1) begin
                way1_dirty[data_paddr_r[11:5]] <= 1'b0;
            end else if (work_state == state_miss_write_update && lru[data_paddr_r[11:5]] == 1'b1) begin
                way1_dirty[data_paddr_r[11:5]] <= 1'b1;
            end
        end
    end
    
    assign victim_is_dirty = lru[data_paddr_r[11:5]] == 1'b0 ? way0_dirty[data_paddr_r[11:5]] :
                          lru[data_paddr_r[11:5]] == 1'b1 ? way1_dirty[data_paddr_r[11:5]] : 1'b0;
    
    assign tag0_wen = ((work_state == state_miss_read_update || work_state == state_miss_write_update) && lru[data_paddr_r[11:5]] == 1'b0) ? 1'b1 : 1'b0;
    assign tag1_wen = ((work_state == state_miss_read_update || work_state == state_miss_write_update) && lru[data_paddr_r[11:5]] == 1'b1) ? 1'b1 : 1'b0;
    assign tag_wdata = (work_state == state_miss_read_update || work_state == state_miss_write_update) ? {1'b1, data_paddr_r[31:12]} : 21'b0;
    
    assign hit = (hit0 && valid0) || (hit1 && valid1);
    wire[31:0] hit_word;
    wire[31:0] writeback_data;
    
    wire way0_burst_read_wen = (work_state == state_miss_read_fetch_data_transf || work_state == state_miss_write_fetch_data_transf) && rvalid && lru[data_paddr_r[11:5]] == 1'b0;
    wire way1_burst_read_wen = (work_state == state_miss_read_fetch_data_transf || work_state == state_miss_write_fetch_data_transf) && rvalid && lru[data_paddr_r[11:5]] == 1'b1;
    assign way0_wen[0] = ((way0_burst_read_wen && read_counter == 3'b000)) ? 1'b1 : 1'b0;
    assign way0_wen[1] = ((way0_burst_read_wen && read_counter == 3'b001)) ? 1'b1 : 1'b0;
    assign way0_wen[2] = ((way0_burst_read_wen && read_counter == 3'b010)) ? 1'b1 : 1'b0;
    assign way0_wen[3] = ((way0_burst_read_wen && read_counter == 3'b011)) ? 1'b1 : 1'b0;
    assign way0_wen[4] = ((way0_burst_read_wen && read_counter == 3'b100)) ? 1'b1 : 1'b0;
    assign way0_wen[5] = ((way0_burst_read_wen && read_counter == 3'b101)) ? 1'b1 : 1'b0;
    assign way0_wen[6] = ((way0_burst_read_wen && read_counter == 3'b110)) ? 1'b1 : 1'b0;
    assign way0_wen[7] = ((way0_burst_read_wen && read_counter == 3'b111)) ? 1'b1 : 1'b0;
    assign way1_wen[0] = ((way1_burst_read_wen && read_counter == 3'b000)) ? 1'b1 : 1'b0;
    assign way1_wen[1] = ((way1_burst_read_wen && read_counter == 3'b001)) ? 1'b1 : 1'b0;
    assign way1_wen[2] = ((way1_burst_read_wen && read_counter == 3'b010)) ? 1'b1 : 1'b0;
    assign way1_wen[3] = ((way1_burst_read_wen && read_counter == 3'b011)) ? 1'b1 : 1'b0;
    assign way1_wen[4] = ((way1_burst_read_wen && read_counter == 3'b100)) ? 1'b1 : 1'b0;
    assign way1_wen[5] = ((way1_burst_read_wen && read_counter == 3'b101)) ? 1'b1 : 1'b0;
    assign way1_wen[6] = ((way1_burst_read_wen && read_counter == 3'b110)) ? 1'b1 : 1'b0;
    assign way1_wen[7] = ((way1_burst_read_wen && read_counter == 3'b111)) ? 1'b1 : 1'b0;
    
    assign way0_data0_wen = (((work_state == state_cached_write_lookup && hit0 && valid0) || (work_state == state_miss_write_update && lru[data_paddr_r[11:5]] == 1'b0)) && data_paddr_r[4:2] == 3'b000) ? data_sel : {4{way0_wen[0]}}; 
    assign way0_data1_wen = (((work_state == state_cached_write_lookup && hit0 && valid0) || (work_state == state_miss_write_update && lru[data_paddr_r[11:5]] == 1'b0)) && data_paddr_r[4:2] == 3'b001) ? data_sel : {4{way0_wen[1]}};
    assign way0_data2_wen = (((work_state == state_cached_write_lookup && hit0 && valid0) || (work_state == state_miss_write_update && lru[data_paddr_r[11:5]] == 1'b0)) && data_paddr_r[4:2] == 3'b010) ? data_sel : {4{way0_wen[2]}};
    assign way0_data3_wen = (((work_state == state_cached_write_lookup && hit0 && valid0) || (work_state == state_miss_write_update && lru[data_paddr_r[11:5]] == 1'b0)) && data_paddr_r[4:2] == 3'b011) ? data_sel : {4{way0_wen[3]}};
    assign way0_data4_wen = (((work_state == state_cached_write_lookup && hit0 && valid0) || (work_state == state_miss_write_update && lru[data_paddr_r[11:5]] == 1'b0)) && data_paddr_r[4:2] == 3'b100) ? data_sel : {4{way0_wen[4]}};
    assign way0_data5_wen = (((work_state == state_cached_write_lookup && hit0 && valid0) || (work_state == state_miss_write_update && lru[data_paddr_r[11:5]] == 1'b0)) && data_paddr_r[4:2] == 3'b101) ? data_sel : {4{way0_wen[5]}};
    assign way0_data6_wen = (((work_state == state_cached_write_lookup && hit0 && valid0) || (work_state == state_miss_write_update && lru[data_paddr_r[11:5]] == 1'b0)) && data_paddr_r[4:2] == 3'b110) ? data_sel : {4{way0_wen[6]}};
    assign way0_data7_wen = (((work_state == state_cached_write_lookup && hit0 && valid0) || (work_state == state_miss_write_update && lru[data_paddr_r[11:5]] == 1'b0)) && data_paddr_r[4:2] == 3'b111) ? data_sel : {4{way0_wen[7]}};
    assign way1_data0_wen = (((work_state == state_cached_write_lookup && hit1 && valid1) || (work_state == state_miss_write_update && lru[data_paddr_r[11:5]] == 1'b1)) && data_paddr_r[4:2] == 3'b000) ? data_sel : {4{way1_wen[0]}};
    assign way1_data1_wen = (((work_state == state_cached_write_lookup && hit1 && valid1) || (work_state == state_miss_write_update && lru[data_paddr_r[11:5]] == 1'b1)) && data_paddr_r[4:2] == 3'b001) ? data_sel : {4{way1_wen[1]}};
    assign way1_data2_wen = (((work_state == state_cached_write_lookup && hit1 && valid1) || (work_state == state_miss_write_update && lru[data_paddr_r[11:5]] == 1'b1)) && data_paddr_r[4:2] == 3'b010) ? data_sel : {4{way1_wen[2]}};
    assign way1_data3_wen = (((work_state == state_cached_write_lookup && hit1 && valid1) || (work_state == state_miss_write_update && lru[data_paddr_r[11:5]] == 1'b1)) && data_paddr_r[4:2] == 3'b011) ? data_sel : {4{way1_wen[3]}};
    assign way1_data4_wen = (((work_state == state_cached_write_lookup && hit1 && valid1) || (work_state == state_miss_write_update && lru[data_paddr_r[11:5]] == 1'b1)) && data_paddr_r[4:2] == 3'b100) ? data_sel : {4{way1_wen[4]}};
    assign way1_data5_wen = (((work_state == state_cached_write_lookup && hit1 && valid1) || (work_state == state_miss_write_update && lru[data_paddr_r[11:5]] == 1'b1)) && data_paddr_r[4:2] == 3'b101) ? data_sel : {4{way1_wen[5]}};
    assign way1_data6_wen = (((work_state == state_cached_write_lookup && hit1 && valid1) || (work_state == state_miss_write_update && lru[data_paddr_r[11:5]] == 1'b1)) && data_paddr_r[4:2] == 3'b110) ? data_sel : {4{way1_wen[6]}};
    assign way1_data7_wen = (((work_state == state_cached_write_lookup && hit1 && valid1) || (work_state == state_miss_write_update && lru[data_paddr_r[11:5]] == 1'b1)) && data_paddr_r[4:2] == 3'b111) ? data_sel : {4{way1_wen[7]}};
    
    assign cache_wdata = (work_state == state_miss_read_fetch_data_transf || work_state == state_miss_write_fetch_data_transf) ? rdata :
                         (work_state == state_cached_write_lookup || work_state == state_miss_write_update) ? data_wdata_r : 32'b0;
    
    assign access_cache_addr = data_req ? data_paddr : data_paddr_r;
    
    wire[31:0] word_selection0, word_selection1;
    assign word_selection0 = (data_paddr_r[4:2] == 3'b000) ? dcache_way0_0_rdata :
                             (data_paddr_r[4:2] == 3'b001) ? dcache_way0_1_rdata :
                             (data_paddr_r[4:2] == 3'b010) ? dcache_way0_2_rdata :
                             (data_paddr_r[4:2] == 3'b011) ? dcache_way0_3_rdata :
                             (data_paddr_r[4:2] == 3'b100) ? dcache_way0_4_rdata :
                             (data_paddr_r[4:2] == 3'b101) ? dcache_way0_5_rdata :
                             (data_paddr_r[4:2] == 3'b110) ? dcache_way0_6_rdata :
                             (data_paddr_r[4:2] == 3'b111) ? dcache_way0_7_rdata : 32'b0;
    assign word_selection1 = (data_paddr_r[4:2] == 3'b000) ? dcache_way1_0_rdata :
                             (data_paddr_r[4:2] == 3'b001) ? dcache_way1_1_rdata :
                             (data_paddr_r[4:2] == 3'b010) ? dcache_way1_2_rdata :
                             (data_paddr_r[4:2] == 3'b011) ? dcache_way1_3_rdata :
                             (data_paddr_r[4:2] == 3'b100) ? dcache_way1_4_rdata :
                             (data_paddr_r[4:2] == 3'b101) ? dcache_way1_5_rdata :
                             (data_paddr_r[4:2] == 3'b110) ? dcache_way1_6_rdata :
                             (data_paddr_r[4:2] == 3'b111) ? dcache_way1_7_rdata : 32'b0;
    assign hit_word = (hit0 && valid0) ? word_selection0 :
                      (hit1 && valid1) ? word_selection1 : 32'b0;
    
    wire[31:0] wb_word0, wb_word1;
    assign wb_word0 = (write_counter == 3'b000) ? dcache_way0_0_rdata :       
                      (write_counter == 3'b001) ? dcache_way0_1_rdata :       
                      (write_counter == 3'b010) ? dcache_way0_2_rdata :       
                      (write_counter == 3'b011) ? dcache_way0_3_rdata :       
                      (write_counter == 3'b100) ? dcache_way0_4_rdata :       
                      (write_counter == 3'b101) ? dcache_way0_5_rdata :       
                      (write_counter == 3'b110) ? dcache_way0_6_rdata :       
                      (write_counter == 3'b111) ? dcache_way0_7_rdata : 32'b0;
    assign wb_word1 = (write_counter == 3'b000) ? dcache_way1_0_rdata :       
                      (write_counter == 3'b001) ? dcache_way1_1_rdata :       
                      (write_counter == 3'b010) ? dcache_way1_2_rdata :       
                      (write_counter == 3'b011) ? dcache_way1_3_rdata :       
                      (write_counter == 3'b100) ? dcache_way1_4_rdata :       
                      (write_counter == 3'b101) ? dcache_way1_5_rdata :       
                      (write_counter == 3'b110) ? dcache_way1_6_rdata :       
                      (write_counter == 3'b111) ? dcache_way1_7_rdata : 32'b0;
    assign writeback_data = (lru[data_paddr_r[11:5]] == 1'b0) ? wb_word0 :
                            (lru[data_paddr_r[11:5]] == 1'b1) ? wb_word1 : 32'b0;
    
    
    // ar
    assign arid = 4'b0000;
    assign araddr = (work_state == state_uncached_read_addr_hshake) ? {data_paddr_r[31:2], 2'b00} :
                    (work_state == state_miss_read_fetch_addr_hshake || work_state == state_miss_write_fetch_addr_hshake) ? {data_paddr_r[31:5], 5'b00000} : 32'b0;
    assign arlen = (data_cache_r == 1'b1) ? 8'b0000_0111 : 8'b0000_0000;
    assign arsize = 3'b010;
    assign arburst = (data_cache_r == 1'b1) ? 2'b01 : 2'b00;
    assign arlock = 2'b00;
    assign arcache = 4'b0000;
    assign arprot = 3'b000;
    assign arvalid = (work_state == state_uncached_read_addr_hshake || work_state == state_miss_read_fetch_addr_hshake || work_state == state_miss_write_fetch_addr_hshake) ? 1'b1 : 1'b0;
    
    // r
    assign rready = 1'b1;
    
    // aw
    assign awid = 4'b0000;
    assign awaddr = (work_state == state_uncached_write_addr_hshake) ? {data_paddr_r[31:2], 2'b00} : 32'b0;
    assign awlen = (data_cache_r == 1'b1) ? 8'b0000_0111 : 8'b0000_0000;
    assign awsize = 3'b010;
    assign awburst = (data_cache_r == 1'b1) ? 2'b01 : 2'b00;
    assign awlock = 2'b00;
    assign awcache = 4'b0000;
    assign awprot = 3'b000;
    assign awvalid = (work_state == state_uncached_write_addr_hshake) ? 1'b1 : 1'b0;
    
    // w
    assign wid = 4'b0000;
    assign wdata = (work_state == state_uncached_write_data_transf) ? data_wdata_r : 32'b0;
    assign wstrb = (work_state == state_uncached_write_data_transf) ? data_sel : 4'b0000;
    assign wlast = (work_state == state_uncached_write_data_transf) ? 1'b1 : 1'b0;
    assign wvalid = (work_state == state_uncached_write_data_transf) ? 1'b1 : 1'b0;
    
    // b
    assign bready = 1'b1;
    
    // wbuffer
    assign wbuffer_wreq = 
    assign clear_req = (work_state == state_cached_read_lookup && !hit) ? 1'b1 : 1'b0;
    
    // data sram like
    // assign data_addr_ok = 1'b1;
    assign data_addr_ok = ((work_state == state_idle || 
                            work_state == state_rw_done ||
                            work_state == state_cached_read_lookup) && data_req) ? 1'b1 : 1'b0;
    assign data_data_ok = (work_state == state_rw_done) ? 1'b1 : 
                          (work_state == state_cached_read_lookup && hit) ? 1'b1 :1'b0;
    assign data_rdata   = (work_state == state_rw_done) ? wait_data :
                          (work_state == state_cached_read_lookup) ? hit_word : 32'b0;

endmodule
