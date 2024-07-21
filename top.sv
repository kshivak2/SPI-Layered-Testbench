class transaction;
  rand bit [11:0] din;

  function transaction copy;
    copy = new();
    copy.din = this.din;
    return copy;
  endfunction
endclass
  
class generator;
  transaction trans;
  mailbox #(transaction) gen2drv;
  event done;
  event drvnext;
  event sconext;
  
  int count = 0;
  
  function new (mailbox #(transaction) gen2drv);
    this.gen2drv = gen2drv;
    trans = new();
  endfunction
  
  task run();
    repeat(count) begin
      assert(trans.randomize) else $error ("[GEN] RANDOMIZATION FAILED");
      gen2drv.put(trans);
      $display("[GEN] DIN : %0d", trans.din);
      @(sconext);
    end
    ->done;
  endtask
endclass
      
class driver;
  mailbox #(transaction) gen2drv;
  mailbox #(bit [11:0]) drv2sco;
  event drvnext;
 
  
  virtual sif_if vif;
  transaction trans;
  
  function new(mailbox #(transaction) gen2drv, mailbox #(bit [11:0]) drv2sco);
    this.gen2drv = gen2drv;
    this.drv2sco = drv2sco;
  endfunction
  
  task reset();
    vif.rst <= 1'b1;
    vif.newd <= 1'b0;
    vif.din <= 1'b0;
    repeat(10) @(posedge vif.clk);
    vif.rst <= 1'b0;
    repeat(5) @(posedge vif.clk);
    $display("----------------------------------------");
    $display("RESET DONE");
    $display("----------------------------------------");
  endtask
  
  task run();
    forever begin
      gen2drv.get(trans);
      @(posedge vif.sclk);
      vif.newd = 1'b1;
      vif.din = trans.din;
      drv2sco.put(trans.din);
      @(posedge vif.sclk);
      vif.newd = 1'b0;
      wait(vif.done == 1'b1);
      $display("[DRV] DATA SENT TO DAC : %0d", trans.din);
      @(posedge vif.sclk);
    end
  endtask
endclass

class monitor;
  transaction trans;
  mailbox #(bit [11:0]) mon2sco;
  virtual sif_if vif;
  
  bit [11:0] din_rcvd;
  
  function new(mailbox #(bit[11:0]) mon2sco);
    this.mon2sco = mon2sco;
  endfunction
  
  task run();
    forever begin;
      @(posedge vif.sclk);
      wait(vif.done == 1'b1);
      @(posedge vif.sclk);    
      din_rcvd = vif.dout;
      wait(vif.done == 1'b0);
      $display("[MON] : DATA SENT : %0d", din_rcvd);
      mon2sco.put(din_rcvd);
    end
  endtask
endclass

class scoreboard;
  mailbox #(bit [11:0]) drv2sco;
  mailbox #(bit [11:0]) mon2sco;
  bit [11:0] din_drv; // Data from driver
  bit [11:0] din_mon; // Data from monitor
  event sconext;
 
  function new(mailbox #(bit [11:0]) drv2sco, mailbox #(bit [11:0]) mon2sco);
    this.drv2sco = drv2sco;
    this.mon2sco = mon2sco;
  endfunction
 
  task run();
    forever begin
      drv2sco.get(din_drv);
      mon2sco.get(din_mon);
      $display("[SCO] : DRV : %0d MON : %0d", din_drv, din_mon);
 
      if (din_drv == din_mon && din_drv != 1'b0)
        $display("[SCO] : DATA MATCHED");
      else
        $display("[SCO] : DATA MISMATCHED");
 
      $display("-----------------------------------------");
      ->sconext;
    end
  endtask
endclass

class environment;
  generator gen;
  driver drv;
  monitor mon;
  scoreboard sco;
  
  virtual sif_if vif;
  
  event drv_next;
  event sco_next;
  
  mailbox #(transaction) gen2drv;
  mailbox #(bit [11:0]) drv2sco;
  mailbox #(bit [11:0]) mon2sco;

  function new(virtual sif_if vif);
    gen2drv = new();
    drv2sco = new();
    mon2sco = new();
    
    gen = new(gen2drv);
    drv = new(gen2drv,drv2sco);
    mon = new(mon2sco);
    sco = new(drv2sco,mon2sco);
    
    gen.drvnext = drv_next;
    drv.drvnext = drv_next;
    
    gen.sconext = sco_next;
    sco.sconext = sco_next;
    
    this.vif = vif;
    drv.vif = this.vif;
    mon.vif = this.vif;
  endfunction
  
  task pre_test();
    drv.reset();
  endtask
  
  task test();
    fork
    gen.run;
    drv.run;
    mon.run;
    sco.run;
    join_any
  endtask
  
  task post_test();
    wait(gen.done.triggered);
    $finish();
  endtask
  
  task run();
    pre_test();
    test();
    post_test();
  endtask
endclass

module tb;
  
  sif_if vif();
  top dut  (.clk(vif.clk),
          .rst(vif.rst), 
          .newd(vif.newd), 
          .din(vif.din), 
          .dout(vif.dout),
          .done(vif.done));
  
  initial begin
    vif.clk <= 0;
  end
 
  always #10 vif.clk <= ~vif.clk;
  
  assign vif.sclk = dut.m1.sclk;
 
  environment env;
 
  initial begin
    env = new(vif);
    env.gen.count = 20;
    env.run();
  end
 
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars;
  end
endmodule
