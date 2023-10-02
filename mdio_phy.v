
`timescale 1ns / 1ps 
module mdio_phy(
    input clk_8_3mhz,
    input reset_n,
    input [95:0] mdio_packet_data,
    input mdio_packet_valid,
    input rd_wr_sig,
    output pckt_rcvd,
    output done,
    output reg [15:0] read_reg_data,
    output read_valid,
    //inout mdio,
    input mdio_in,
    output mdio_out,
    output read_en,
    output mdc
    );
reg packet_valid_d,packet_valid_d1;
reg [6:0]counter;//max count of 96bits per packet
reg [95:0] mdio_packet_data_reg;
reg [95:0] shift_mdio_packet;
reg mdio_reg,pckt_rcvd_reg,done_reg;
reg rd_wr_sig_d, rd_wr_sig_d1;
reg start_d, start_d1;
reg start,serialise_complt;
wire posedge_packet_valid, start_posedge;
reg [15:0] read_reg;
reg read_valid_reg;
reg read_en_reg;
(*KEEP="TRUE"*) reg mdio_in_reg;

assign mdc = clk_8_3mhz;
assign mdio_out = mdio_reg;
assign done = done_reg;
assign pckt_rcvd = pckt_rcvd_reg;
assign read_en = read_en_reg;

assign posedge_packet_valid = (packet_valid_d && (~ packet_valid_d1));
assign read_valid = read_valid_reg; 
assign start_posedge =  (start_d && (~ start_d1));

//Edge Detect Logic
always@(posedge clk_8_3mhz)
begin
  if(!reset_n)
    begin
    packet_valid_d <= 1'b0;
    packet_valid_d1 <= 1'b0;
    rd_wr_sig_d1 <= 1'b0;
    rd_wr_sig_d <= 1'b0;
    start_d <= 1'b0;
    start_d1<= 1'b0;
    mdio_in_reg <= 1'b0;
    end
  else
    begin
    packet_valid_d <= mdio_packet_valid;
    packet_valid_d1 <= packet_valid_d;
    rd_wr_sig_d <= rd_wr_sig;
    rd_wr_sig_d1 <= rd_wr_sig_d;
    start_d <= start;
    start_d1 <= start_d;
    mdio_in_reg <= mdio_in;
    end
end

//Sampling the data 
always@(posedge clk_8_3mhz)
begin
  if(!reset_n)
    begin
      mdio_packet_data_reg <= {96{1'b0}};
      pckt_rcvd_reg <= 1'b0;
      start <= 1'b0;
    end
  else
   begin
    if (posedge_packet_valid == 1'b1)
      begin
      mdio_packet_data_reg <= mdio_packet_data;
      pckt_rcvd_reg <= 1'b1;
      start <= 1'b1;
      end
    else if (serialise_complt == 1'b1)
      begin
      start <= 1'b0;
      mdio_packet_data_reg <= mdio_packet_data_reg;
      pckt_rcvd_reg <= 1'b0;
      end
    else
      begin
      mdio_packet_data_reg <= mdio_packet_data_reg;
      pckt_rcvd_reg <= 1'b0;
      start <= start;
      end
   end
end
//output read data logic
always@ (posedge clk_8_3mhz)
begin
  if (!reset_n)
  begin
    read_reg_data <= {16{1'b0}};
    read_valid_reg <= 1'b0;
  end
  else
  begin
    if((done_reg == 1'b1) && (rd_wr_sig_d1 == 1'b1))
      begin
          read_reg_data <= read_reg;
          read_valid_reg <= 1'b1;
      end
    else
      begin
          read_reg_data <= read_reg_data;
          read_valid_reg <= 1'b0;
      end
  end
end
// transmitting the data on the mdio line    
always@(negedge clk_8_3mhz)
begin
if(!reset_n)
  begin
  mdio_reg <= 1'b1;
  counter <= 7'b0;
  done_reg <= 1'b0;
  serialise_complt <= 1'b0;
  shift_mdio_packet <= {96{1'b1}};
  end
else
  begin
  if (start == 1'b1) 
  begin
  if (start_posedge == 1'b1)
    begin
    shift_mdio_packet <= mdio_packet_data_reg;
    end
  else if (counter == 7'h60)
    begin 
    counter <= 7'b0;
    done_reg <= 1'b1;
    serialise_complt <= 1'b1;
    end
  else
    begin
    mdio_reg <= shift_mdio_packet[95];    
    shift_mdio_packet <= { shift_mdio_packet[94:0], 1'b0};
    counter <= counter + 1'b1;
    done_reg <= 1'b0;
    end
  end
  else
    begin
    serialise_complt <= 1'b0;
    mdio_reg <= 1'b1;
    counter <= 7'b0;
    done_reg <= 1'b0;
    end
  end
end    

//Reading the Register Data on the line
always@ (posedge clk_8_3mhz)
begin
  if (!reset_n) 
  read_reg <= {16{1'b0}};
  else
  begin
    if (rd_wr_sig_d1 ==1'b1)
      begin
      //if ((counter > 7'd48)  && (counter < 7'd65))
      if ((counter > 7'd49)  && (counter < 7'd67))
      read_reg <= {read_reg[14:0], mdio_in_reg};
      else
      read_reg <= read_reg;
      end
    else
      read_reg <= {16{1'b0}};
  end
end

// Combo Logic to drive the IOBUF at required conditions
always@ (counter,rd_wr_sig_d1,reset_n)
begin
  if (!reset_n) 
  read_en_reg <= 1'b0;
  else
  begin
    if (rd_wr_sig_d1 ==1'b1)
      begin
      //if ((counter > 7'd49)  && (counter < 7'd66))//read high impedance drive
      if ((counter > 7'd49)  && (counter < 7'd67))
          read_en_reg <= 1'b1;
      else if (counter == 7'd48)//turnover high impedance drive
          read_en_reg <= 1'b1;
      else
          read_en_reg <= 1'b0;
      end
    else if (start == 1'b0)
        read_en_reg <= 1'b0;
    else 
        read_en_reg <= 1'b0;
  end
end
endmodule


/*`timescale 1ns / 1ps 
module mdio_phy(
    input clk_8_3mhz,
    input reset_n,
    input [95:0] mdio_packet_data,
    input mdio_packet_valid,
    input rd_wr_sig,
    output pckt_rcvd,
    output done,
    output reg [15:0] read_reg_data,
    output read_valid,
    //inout mdio,
    input mdio_in,
    output mdio_out,
    output read_en,
    output mdc
    );
reg packet_valid_d,packet_valid_d1;
reg [6:0]counter;//max count of 96bits per packet
reg [95:0] mdio_packet_data_reg;
reg [95:0] shift_mdio_packet;
reg mdio_reg,pckt_rcvd_reg,done_reg;
reg rd_wr_sig_d, rd_wr_sig_d1;
reg start_d, start_d1;
reg start,serialise_complt;
wire posedge_packet_valid, start_posedge;
reg [15:0] read_reg;
reg read_valid_reg;
reg read_en_reg;
(*KEEP="TRUE"*) reg mdio_in_reg;

assign mdc = clk_8_3mhz;
assign mdio_out = mdio_reg;
assign done = done_reg;
assign pckt_rcvd = pckt_rcvd_reg;
assign read_en = read_en_reg;

assign posedge_packet_valid = (packet_valid_d && (~ packet_valid_d1));
assign read_valid = read_valid_reg; 
assign start_posedge =  (start_d && (~ start_d1));

//Edge Detect Logic
always@(posedge clk_8_3mhz)
begin
  if(!reset_n)
    begin
    packet_valid_d <= 1'b0;
    packet_valid_d1 <= 1'b0;
    rd_wr_sig_d1 <= 1'b0;
    rd_wr_sig_d <= 1'b0;
    start_d <= 1'b0;
    start_d1<= 1'b0;
    mdio_in_reg <= 1'b0;
    end
  else
    begin
    packet_valid_d <= mdio_packet_valid;
    packet_valid_d1 <= packet_valid_d;
    rd_wr_sig_d <= rd_wr_sig;
    rd_wr_sig_d1 <= rd_wr_sig_d;
    start_d <= start;
    start_d1 <= start_d;
    mdio_in_reg <= mdio_in;
    end
end

//Sampling the data 
always@(posedge clk_8_3mhz)
begin
  if(!reset_n)
    begin
      mdio_packet_data_reg <= {96{1'b0}};
      pckt_rcvd_reg <= 1'b0;
      start <= 1'b0;
    end
  else
   begin
    if (posedge_packet_valid == 1'b1)
      begin
      mdio_packet_data_reg <= mdio_packet_data;
      pckt_rcvd_reg <= 1'b1;
      start <= 1'b1;
      end
    else if (serialise_complt == 1'b1)
      begin
      start <= 1'b0;
      mdio_packet_data_reg <= mdio_packet_data_reg;
      pckt_rcvd_reg <= 1'b0;
      end
    else
      begin
      mdio_packet_data_reg <= mdio_packet_data_reg;
      pckt_rcvd_reg <= 1'b0;
      start <= start;
      end
   end
end
//output read data logic
always@ (posedge clk_8_3mhz)
begin
  if (!reset_n)
  begin
    read_reg_data <= {16{1'b0}};
    read_valid_reg <= 1'b0;
  end
  else
  begin
    if((done_reg == 1'b1) && (rd_wr_sig_d1 == 1'b1))
      begin
          read_reg_data <= read_reg;
          read_valid_reg <= 1'b1;
      end
    else
      begin
          read_reg_data <= read_reg_data;
          read_valid_reg <= 1'b0;
      end
  end
end
// transmitting the data on the mdio line    
always@(negedge clk_8_3mhz)
begin
if(!reset_n)
  begin
  mdio_reg <= 1'b1;
  counter <= 7'b0;
  done_reg <= 1'b0;
  serialise_complt <= 1'b0;
  shift_mdio_packet <= {96{1'b1}};
  end
else
  begin
  if (start == 1'b1) 
  begin
  if (start_posedge == 1'b1)
    begin
    shift_mdio_packet <= mdio_packet_data_reg;
    end
  else if (counter == 7'h60)
    begin 
    counter <= 7'b0;
    done_reg <= 1'b1;
    serialise_complt <= 1'b1;
    end
  else
    begin
    mdio_reg <= shift_mdio_packet[95];    
    shift_mdio_packet <= { shift_mdio_packet[94:0], 1'b0};
    counter <= counter + 1'b1;
    done_reg <= 1'b0;
    end
  end
  else
    begin
    serialise_complt <= 1'b0;
    mdio_reg <= 1'b1;
    counter <= 7'b0;
    done_reg <= 1'b0;
    end
  end
end    

//Reading the Register Data on the line
always@ (posedge clk_8_3mhz)
begin
  if (!reset_n) 
  read_reg <= {16{1'b0}};
  else
  begin
    if (rd_wr_sig_d1 ==1'b1)
      begin
      if ((counter > 7'd48)  && (counter < 7'd65))
      read_reg <= {read_reg[14:0], mdio_in_reg};
      else
      read_reg <= read_reg;
      end
    else
      read_reg <= {16{1'b0}};
  end
end

// Combo Logic to drive the IOBUF at required conditions
always@ (counter,rd_wr_sig_d1,reset_n)
begin
  if (!reset_n) 
  read_en_reg <= 1'b0;
  else
  begin
    if (rd_wr_sig_d1 ==1'b1)
      begin
      if ((counter > 7'd49)  && (counter < 7'd66))//read high impedance drive
          read_en_reg <= 1'b1;
      else if (counter == 7'd48)//turnover high impedance drive
          read_en_reg <= 1'b1;
      else
          read_en_reg <= 1'b0;
      end
    else if (start == 1'b0)
        read_en_reg <= 1'b0;
    else 
        read_en_reg <= 1'b0;
  end
end
endmodule*/
