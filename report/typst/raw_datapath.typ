#set page(width: auto, height: auto, margin: 1cm)
#import "@preview/circuiteria:0.2.1"
#import "@preview/cetz:0.3.4": draw

#circuiteria.circuit({
  import circuiteria: *

  // (Addr Counter)
  element.block(
    id: "counter",
    name: [Addr Counter\ `input_counter_r`],
    x: -9.5,
    y: -6,
    w: 8,
    h: 6,
    ports: (
      north: ((id: "clk", clock: true, small:true),),
      west: (
        (id: "rstn", name: "rstn"),
        (id: "size", name: "i_size"),
        (id: "clr", name: "clr"),
        (id: "ld", name: "ld"),
      ),
      east: (
        (id: "addr", name: [iw_addr]),
        (id: "co", name: [co]),
      ),
    ),
    fill: rgb("#e18d8d"),
  )

  // (Subtractor)
  element.block(
    id: "sub",
    name: [Subtractor\ `input_signed`],
    x: -9,
    y: 9,
    w: 7,
    h: 3,
    ports: (
      west: (
        (id: "zp", name: "zp"),
        (id: "data", name: "data"),
      ),
      east: ((id: "out", name: "signed\ndata"),),
    ),
    fill: rgb("#e18d8d"),
  )

  // PE
  let pe_block(idx, x, y) = {
    element.group(id: "pe" + idx, name: [*PE #idx*], {
      // mult
      element.block(
        id: "mult" + idx,
        name: [multiply],
        x: x,
        y: y,
        w: 6,
        h: 2,
        ports: (
          west: (
            (id: "in_signed"),
            (id: "w"),
          ),
          east: ((id: "out"),),
        ),
        fill: rgb("#8dc7e1"),
      )
      // (Acc)
      element.block(
        id: "acc" + idx,
        name: [acc],
        x: x + 7,
        y: y,
        w: 6,
        h: 2,
        ports: (
          west: (
            (id: "in_mult", name: "in_mult"),
          ),
          north: ((id: "in_reg", name: "in_reg"),),
          east: ((id: "out"),),
        ),
        fill: rgb("#8de18d"),
      )
      wire.wire("w_pe" + idx, ("mult" + idx + "-port-out", "acc" + idx + "-port-in_mult"))
    })
  }

  pe_block("0", 8, 15)
  pe_block("1", 8, 11)
  draw.content((15, 9), text(size: 50pt, fill: gray.darken(100%), [...]))
  pe_block("N", 8, 4)

  // --- نام‌گذاری و تعیین بُعد پورت‌های ورودی/خروجی اصلی ---
  wire.stub("counter-port-clk", "north", name: [clk #("[1]")])
  wire.stub("counter-port-rstn", "west", name: [rstn #("[1]")])
  wire.stub("counter-port-size", "west", name: [input_size #("[clog2(MAX_SIZE)-1:0]")])
  wire.stub("counter-port-clr", "west", name: [input_counter_clr #("[1]")])
  wire.stub("counter-port-ld", "west", name: [input_counter_ld #("[1]")])

  wire.stub("counter-port-addr", "east", name: [input_weight_address #("[ADDR_W-1:0]")])
  wire.stub("counter-port-co", "east", name: [input_counter_co #("[1]")])

  wire.stub("sub-port-zp", "west", name: [input_zp #("[ZP_W-1:0]")])
  wire.stub("sub-port-data", "west", name: [input_data #("[D_W-1:0]")])

  // --- باس input_signed ---
  let bus_x_signed = 4.5
  draw.content((-1, 11), [input_signed #("[D_W:0]")], anchor: "south-west", padding: 3pt, size: 7pt)
  draw.line("sub-port-out", (bus_x_signed, 10.5), stroke: (thickness: 1.5pt))
  draw.line((bus_x_signed, 5.33), (bus_x_signed, 16.33), stroke: (thickness: 1.5pt))
  draw.line((bus_x_signed, 16.33), "mult0-port-in_signed", stroke: (thickness: 1.5pt))
  draw.line((bus_x_signed, 12.33), "mult1-port-in_signed", stroke: (thickness: 1.5pt))
  draw.line((bus_x_signed, 5.33), "multN-port-in_signed", stroke: (thickness: 1.5pt))

  draw.circle((bus_x_signed, 5.33), radius: 1.5pt, fill: black)
  draw.circle((bus_x_signed, 16.33), radius: 1.5pt, fill: black)
  draw.circle((bus_x_signed, 12.33), radius: 1.5pt, fill: black)
  
  // نمایش بُعد اسلایس ورودی به هر ضربکننده
  draw.content((bus_x_signed - 2, 17), [#("[D_W:0]")], anchor: "west", size: 5pt)
  draw.content((bus_x_signed - 2, 13), [#("[D_W:0]")], anchor: "west", size: 5pt)


  // --- باس weight_data ---
  let bus_x_weight = 6
  draw.line((-4, 2), (bus_x_weight, 2), stroke: (thickness: 1.5pt))
  draw.line((bus_x_weight, 2), (bus_x_weight, 15.66), stroke: (thickness: 1.5pt))
  draw.line((bus_x_weight, 15.66), "mult0-port-w", stroke: (thickness: 1.5pt))
  draw.line((bus_x_weight, 11.66), "mult1-port-w", stroke: (thickness: 1.5pt))
  draw.line((bus_x_weight, 4.66), "multN-port-w", stroke: (thickness: 1.5pt))

  draw.circle((bus_x_weight, 4.66), radius: 1.5pt, fill: black)
  draw.circle((bus_x_weight, 11.66), radius: 1.5pt, fill: black)
  
  draw.content((-4, 2), [weight_data #("[W_W * MAX_PES -1:0]")], anchor: "east", padding: 3pt, size: 7pt)
  
  // نمایش بُعد اسلایس وزن دریافتی هر PE
  draw.content((bus_x_weight + 0.2, 14.2), [#("[W_W-1:0]")], anchor: "west", size: 5pt)
  draw.content((bus_x_weight + 0.2, 10.2), [#("[W_W-1:0]")], anchor: "west", size: 5pt)
  draw.content((bus_x_weight + 0.2, 3.2), [#("[W_W-1:0]")], anchor: "west", size: 5pt)


  // --- باس register_array ---
  let bus_x_reg = 18
  draw.content((-4, 20.5), [register_array #("[BYTE_REG_NUM * 8 -1:0]")], anchor: "east", padding: 3pt, size: 7pt)
  draw.line((-4, 20), (bus_x_reg, 20), stroke: (thickness: 1.5pt))
  
  
  draw.line((bus_x_reg, 20), "acc0-port-in_reg", stroke: (thickness: 1.5pt))
  draw.line((bus_x_reg, 14.5), "acc1-port-in_reg", stroke: (thickness: 1.5pt, dash: "dashed"))
  draw.line((bus_x_reg, 8.5), "accN-port-in_reg", stroke: (thickness: 1.5pt, dash: "dashed"))
  

  // نمایش بُعد اسلایس رجیستر ورودی هر Acc
  draw.content((bus_x_reg + 0.3, 18), [#("[PE_D_W-1:0]")], anchor: "west", size: 5pt)
  draw.content((bus_x_reg + 0.3, 14), [#("[PE_D_W-1:0]")], anchor: "west", size: 5pt)
  draw.content((bus_x_reg + 0.3, 7), [#("[PE_D_W-1:0]")], anchor: "west", size: 5pt)


  // --- باس خروجی ra_in_acc ---
  let bus_x_out = 23
  draw.line((bus_x_out, 5), (bus_x_out, 16), stroke: (thickness: 1.5pt))
  draw.line("acc0-port-out", (bus_x_out, 16), stroke: (thickness: 1.5pt))
  draw.line("acc1-port-out", (bus_x_out, 12), stroke: (thickness: 1.5pt))
  draw.line("accN-port-out", (bus_x_out, 5), stroke: (thickness: 1.5pt))

  draw.circle((bus_x_out, 12), radius: 1.5pt, fill: black)
  
  // اسلایس خروجی هر Acc
  draw.content((bus_x_out + 2, 17), [#("[PE_D_W-1:0]")], anchor: "east", size: 5pt)
  draw.content((bus_x_out + 2, 13), [#("[PE_D_W-1:0]")], anchor: "east", size: 5pt)
  draw.content((bus_x_out + 2, 6), [#("[PE_D_W-1:0]")], anchor: "east", size: 5pt)

  draw.line((bus_x_out, 12), (30, 12), stroke: (thickness: 1.5pt))
  draw.content((30, 12.5), [ra_in_acc #("[BYTE_REG_NUM * 8 -1:0]")], anchor: "west", padding: 5pt, size: 7pt)
})