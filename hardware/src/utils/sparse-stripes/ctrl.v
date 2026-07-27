`ifndef FSM_MODULE
`define FSM_MODULE

        module FSM (
            input   clk,
            input   reset,
            input   start,
            input   done,
            output reg  Areg_en,
            output reg Areg_pl,
            output reg Wreg_en,
            output reg acc_en,
            output reg acc_pl,
            output reg ready
          );

          localparam [1:0]
                     INIT       = 2'b01,
                     LOAD = 2'b10,
                     MULTIPLY   = 2'b11;

          reg [1:0] present_state, next_state;

          always @(posedge clk or posedge reset)
          begin
            if (reset)
              present_state <= INIT;
            else
              present_state <= next_state;
          end

          always @(*)
          begin
            case (present_state)
              INIT:
                next_state = start ? LOAD : INIT;
              LOAD:
                next_state = start ? LOAD : MULTIPLY;
              MULTIPLY:
                next_state = done ? INIT : MULTIPLY;
              default:
                next_state = present_state;
            endcase
          end

          always @(*)
          begin

            Areg_en=1'b0;
            Areg_pl=1'b0;
            Wreg_en=1'b0;
            acc_en=1'b0;
            acc_pl=1'b0;
            ready=1'b0;
            case (present_state)

              INIT:
              begin
                ready = 1'b1;
              end
              LOAD:
              begin
                Areg_en=1'b1;
                Wreg_en=1'b1;
                acc_pl=1'b1;
              end
              MULTIPLY:
              begin
                Areg_pl = 1'b1;
                acc_en = 1'b1;
              end
            endcase
          end

        endmodule

`endif  //FSM_MODULE
