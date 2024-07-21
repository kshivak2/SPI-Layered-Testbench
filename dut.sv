module spi_master(
  input clk, rst, newd,
  input [11:0] din,
  output reg sclk, mosi, cs);
  
  typedef enum bit [1:0] {idle = 2'b00,  send = 2'b01} state_type;
  state_type state = idle;
  
  int countc = 0;
  int count = 0;
  
  
  always @(posedge clk)
    begin
      if (rst == 1'b1) begin
        countc <= 0;
        sclk <= 1'b0; 
      end
      else begin
        if (countc <10) begin
          countc <= countc + 1;
        end
        else begin
          sclk <= ~sclk;
          countc <= 0;
        end
      end
    end
  
  reg [11:0] temp;
  
  always@(posedge sclk) begin
    if(rst == 1'b1) begin
      cs <= 1;
      mosi <= 1'b0;
    end
    else begin
      case(state)
        idle: begin
          if(newd) begin
            cs<=0;
            temp <= din;
            count<=0;
            state <= send;
          end
          else begin
            cs<=1;
            temp <= 8'h00;
            state = idle;
          end
        end
        send: begin
          if(count <= 11) begin
            mosi <= temp[count];
            count <= count+1;
          end
          else begin
            cs <= 1;
            mosi <= 1'b0;
            state <= idle;
          end
        end
        default: state <= idle;
      endcase
    end
  end
endmodule

module spi_slave (
input sclk, cs, mosi,
output [11:0] dout,
output reg done
);
 
  typedef enum bit [1:0] {detect_start = 2'b00, read_data = 2'b10} state_type;
  state_type state = detect_start;
 
reg [11:0] temp = 12'h000;
int count = 0;
 
always@(posedge sclk)
begin
  case(state)
    detect_start: 
      begin
      done <= 1'b0;
      if(cs == 1'b0)
       state <= read_data;
       else
       state <= detect_start;
      end

    read_data : begin
      if(count <= 11)
       begin
       count <= count + 1;
       temp  <= { mosi, temp[11:1]};
       end
       else
       begin
       count <= 0;
       done <= 1'b1;
       state <= detect_start;
      end
    end
    default: state <= detect_start;
  endcase
end
  
assign dout = temp;
endmodule
 
module top (
input clk, rst, newd,
input [11:0] din,
output [11:0] dout,
output done
);
 
wire sclk, cs, mosi;
  
spi_master m1 (.clk(clk), .newd(newd), .rst(rst), .din(din), .sclk(sclk), .cs(cs), .mosi(mosi));
spi_slave s1  (sclk, cs, mosi, dout, done);
endmodule

interface sif_if;
  logic sclk;
  logic cs;
  logic mosi;
  logic [11:0] din;
  logic [11:0] dout;
  logic newd;
  logic clk;
  logic rst;
  logic done;
endinterface