#set page(width: auto, height: auto, margin: 0.5cm)
#import "@preview/circuiteria:0.2.1"
#import "@preview/cetz:0.3.4": draw

#circuiteria.circuit({
  
  import circuiteria: *

  element.block(
    id: "counter", 
    name: [Addr Counter\ `input_counter_r`],
    x: 0, y: -5, w: 7, h: 5,
    ports: (
      west: (
        (id: "ctrl", name: "clk"),
        (id: "ctrl2", name: "ld"),
        (id: "size", name: "input_size")
      ),
      east: ((id: "addr", name: "addr"),),
      south: ((id: "co", name: "co"),)
    ),
    fill: rgb("#e18d8d")
  )

  element.block(
    id: "sub", 
    name: [Subtractor],
    x: 0, y: 6, w: 4, h: 2.5,
    ports: (
      west: (
        (id: "data", name: "input_data"),
        (id: "zp", name: "input_zp")
      ),
      east: ((id: "out", name: "in_s"),)
    ),
    fill: rgb("#e18d8d")
  )

  let pe_block(idx, name, x, y) = {
    element.block(
      id: name,
      name: [*PE #idx* \ #text(size: 6pt)[Mul & Add]],
      x: x, y: y, w: 3, h: 3,
      ports: (
        north: ((id: "in"),),
        west: (
          (id: "w"),
          (id: "r")
        ),
        east: ((id: "out"),)
      ),
      fill: rgb("#e18d8d")
    )
  }

  // ۲. جایگذاری سه بلوک نماینده
  pe_block("0", "pe0", 8, 4)
  pe_block("1", "pe1", 8, 8)
  draw.content((8, 6.5), text(size: 16pt, fill: gray.darken(50%), [...]))
  pe_block("N-1", "peN", 8, 12)

  // قرار دادن علامت ... بین بلوک‌ها
  draw.content((18, 5.5), text(size: 16pt, fill: gray.darken(50%), [...]))
  draw.content((18, 4.5), text(size: 16pt, fill: gray.darken(50%), [...]))

  // ۳. رسم سیم‌های خارجی (Stub) برای ورودی/خروجی اصلی دیتاپس
  wire.stub("counter-port-ctrl", "west", name: "clk, rstn")
  wire.stub("counter-port-ctrl2", "west", name: "clr, ld")
  wire.stub("counter-port-size", "west", name: "input_size")
  wire.stub("counter-port-addr", "east", name: "input_weight_address")
  wire.stub("counter-port-co", "south", name: "input_counter_co")

  wire.stub("sub-port-data", "west", name: "input_data")
  wire.stub("sub-port-zp", "west", name: "input_zp")

  // ۴. رسم باس‌ها و سیم‌های داخلی
  // برای پخش کردن (Broadcast) یک باس به چند بلوک، از draw.line استفاده می‌کنیم
  
  // --- BroadCast کردن input_signed به همه PEها ---
  let bus_x = 6
  draw.line("sub-port-out", (bus_x, 7), stroke: (thickness: 1.5pt))
  draw.line((bus_x, 7), "pe0-port-in", stroke: (thickness: 1.5pt))
  draw.line((bus_x, 7), (bus_x, 8.5), stroke: (thickness: 1.5pt))
  draw.line((bus_x, 8.5), "pe1-port-in", stroke: (thickness: 1.5pt))
  draw.line((bus_x, 8.5), "peN-port-in", stroke: (thickness: 1.5pt))
  draw.content((bus_x, 7.2), "input_signed", anchor: "south-west", padding: 3pt, size: 7pt)

  // --- باس weight_data ---
  draw.line((-2, 2.5), (7, 2.5), stroke: (thickness: 1.5pt))
  draw.line((7, 2.5), "pe0-port-w", stroke: (thickness: 1.5pt))
  draw.line((7, 2.5), (12, 2.5), "pe1-port-w", stroke: (thickness: 1.5pt))
  draw.line((7, 2.5), (20, 2.5), "peN-port-w", stroke: (thickness: 1.5pt))
  draw.content((-1, 2.7), "weight_data", anchor: "south-west", padding: 3pt, size: 7pt)

  // --- باس register_array ---
  draw.line((-2, 1.5), (9, 1.5), stroke: (thickness: 1.5pt))
  draw.line((9, 1.5), "pe0-port-r", stroke: (thickness: 1.5pt))
  draw.line((9, 1.5), (14, 1.5), "pe1-port-r", stroke: (thickness: 1.5pt))
  draw.line((9, 1.5), (22, 1.5), "peN-port-r", stroke: (thickness: 1.5pt))
  draw.content((-1, 1.7), "register_array", anchor: "south-west", padding: 3pt, size: 7pt)

  // --- خروجی‌های ra_in (ترکیب شدن باس خروجی) ---
  draw.line("pe0-port-out", (25, 5.5), stroke: (thickness: 1.5pt))
  draw.line("pe1-port-out", (25, 5.5), stroke: (thickness: 1.5pt))
  draw.line("peN-port-out", (25, 5.5), stroke: (thickness: 1.5pt))
  draw.line((25, 5.5), (27, 5.5), stroke: (thickness: 1.5pt))
  draw.content((25.5, 5.7), "ra_in_acc", anchor: "south-west", padding: 3pt, size: 7pt)
})



// #import "/src/cetz.typ": draw
// #import "@preview/circuiteria:0.2.1": *

// #set page(width: auto, height: auto, margin: .5cm)

// #circuiteria.circuit({
  
//   import circuiteria: *
//   element.multiplexer(
//     x: 10, y: 0, w: 1, h: 6, id: "ResMux",
//     entries: ("000", "001", "010", "011", "101"),
//     h-ratio: 90%,
//     fill: util.colors.blue
//   )
//   element.extender(
//     x: (rel: -3, to: "ResMux.west"),
//     y: (from: "ResMux-port-in4", to: "out"),
//     w: 2, h: 1, id: "Ext",
//     name: "Zero Ext",
//     name-anchor: "south",
//     fill: util.colors.green
//   )
//   gates.gate-or(
//     x: (rel: -2, to: "ResMux.west"),
//     y: (from: "ResMux-port-in3", to: "out"),
//     w: 1, h: 1, id: "Or"
//   )
//   gates.gate-and(
//     x: (rel: -2, to: "ResMux.west"),
//     y: (from: "ResMux-port-in2", to: "out"),
//     w: 1, h: 1, id: "And"
//   )
//   element.alu(
//     x: (rel: -2.5, to: "Ext.west"),
//     y: (from: "ResMux-port-in0", to: "out"),
//     w: 1.5, h: 3, id: "Add",
//     name: text("+", size: 1.5em),
//     name-anchor: "name",
//     fill: util.colors.pink
//   )
//   element.multiplexer(
//     x: (rel: -1.5, to: "Add.west"),
//     y: (from: "Add-port-in1", to: "out"),
//     w: 0.5, h: 1.5, id: "NotMux",
//     h-ratio: 80%,
//     fill: util.colors.blue
//   )
//   gates.gate-not(
//     x: (rel: -2, to: "NotMux.west"),
//     y: (from: "NotMux-port-in1", to: "out"),
//     w: 1, h: 1, id: "Not"
//   )
  
//   draw.hide(
//     draw.line(name: "l1",
//       "Not-port-in0",
//       (rel: (-2, 0), to: ()),
//       (horizontal: (), vertical: "NotMux-port-in0")
//     )
//   )
//   let b = "l1.end"
//   draw.hide(
//     draw.line(name: "l2",
//       b,
//       (horizontal: (), vertical: "Add-port-in2")
//     )
//   )
//   let a = "l2.end"

//   wire.wire("wB0", (b, "NotMux-port-in0"), bus: true)
//   wire.wire(
//     "wB1", (b, "Not-port-in0"),
//     style: "zigzag",
//     zigzag-ratio: 1.5,
//     bus: true
//   )
//   wire.wire(
//     "wB2", (b, "And-port-in0"),
//     style: "zigzag",
//     zigzag-ratio: 1,
//     bus: true
//   )
//   wire.wire(
//     "wB3", (b, "Or-port-in0"),
//     style: "zigzag",
//     zigzag-ratio: 1,
//     bus: true
//   )
//   wire.intersection("wB1.zig")
//   wire.intersection("wB2.zig")
//   wire.intersection("wB2.zag")

//   wire.wire("wNot", ("Not-port-out", "NotMux-port-in1"), bus: true)
//   wire.wire("wAddA", ("NotMux-port-out", "Add-port-in1"), bus: true)

//   wire.wire("wA0", (a, "Add-port-in2"), bus: true)
//   wire.wire(
//     "wA1", (a, "And-port-in1"),
//     style: "zigzag",
//     zigzag-ratio: 0.5,
//     bus: true
//   )
//   wire.wire(
//     "wA2", (a, "Or-port-in1"),
//     style: "zigzag",
//     zigzag-ratio: 0.5,
//     bus: true
//   )
//   wire.intersection("wA1.zig")
//   wire.intersection("wA1.zag")

//   wire.wire("wMux0", ("Add-port-out", "ResMux-port-in0"), bus: true)
//   wire.wire(
//     "wMux1", ("Add-port-out", "ResMux-port-in1"),
//     style: "zigzag",
//     zigzag-ratio: 2,
//     bus: true
//   )
//   wire.wire("wMux2", ("And-port-out", "ResMux-port-in2"), bus: true)
//   wire.wire("wMux3", ("Or-port-out", "ResMux-port-in3"), bus: true)
//   wire.wire("wMux4", ("Ext-port-out", "ResMux-port-in4"), bus: true)

//   wire.wire(
//     "wAdd", ("Add-port-out", "Ext-port-in"),
//     style: "zigzag",
//     zigzag-ratio: 0.5,
//     bus: true
//   )

//   wire.intersection("wMux1.zig")
//   wire.intersection("wAdd.zig")

//   let c = (rel: (0, 2), to: "ResMux.north")
//   wire.wire("wResCtrl", (c, "ResMux.north"), bus: true)
//   wire.wire(
//     "wAddCtrl", (c, "Add.north"),
//     style: "zigzag",
//     zigzag-dir: "horizontal"
//   )

//   let d = (rel: (1, 0), to: "ResMux-port-out")
//   wire.wire("wRes", ("ResMux-port-out", d), bus: true)

//   draw.content(
//     "wAddCtrl.zag",
//     [ALUControl#sub("[1]")],
//     anchor: "south-west",
//     padding: 3pt
//   )
  
//   wire.wire(
//     "wCout", ("Add.south", (horizontal: (), vertical: "Ext.north-east"))
//   )
//   draw.content(
//     "wCout.end",
//     [C#sub("out")],
//     angle: 90deg,
//     anchor: "east",
//     padding: 3pt
//   )
//   draw.content(
//     a,
//     [A],
//     angle: 90deg,
//     anchor: "south",
//     padding: 3pt
//   )
//   draw.content(
//     b,
//     [B],
//     angle: 90deg,
//     anchor: "south",
//     padding: 3pt
//   )
//   draw.content(
//     c,
//     [ALUControl#sub("[2:0]")],
//     angle: 90deg,
//     anchor: "west",
//     padding: 3pt
//   )
//   draw.content(
//     d,
//     [Result],
//     angle: 90deg,
//     anchor: "north",
//     padding: 3pt
//   )
//   draw.content(
//     ("wAdd.zig", 0.2, "wAdd.zag"),
//     text("[N-1]", size: 0.8em),
//     angle: 90deg,
//     anchor: "north-east",
//     padding: 3pt
//   )
// })

















// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// 
// #import "/src/cetz.typ": draw
// #import "@preview/circuiteria:0.2.1": *

// #set page(width: auto, height: auto, margin: .5cm)

// #circuit({
//   element.group(id: "toplvl", name: "Toplevel", {
//     element.group(
//       id: "proc",
//       name: "Processor",
//       padding: 1.5em,
//       stroke: (dash: "dashed"),
//       {
//       element.block(
//         x: 0, y: 0, w: 8, h: 4,
//         id: "dp",
//         fill: util.colors.pink,
//         name: "Datapath",
//         ports: (
//           north: (
//             (id: "clk", clock: true, small: true),
//             (id: "Zero"),
//             (id: "Regsrc"),
//             (id: "PCSrc"),
//             (id: "ResultSrc"),
//             (id: "ALUControl"),
//             (id: "ImmSrc"),
//             (id: "RegWrite"),
//             (id: "dummy")
//           ),
//           east: (
//             (id: "PC", name: "PC"),
//             (id: "Instr", name: "Instr"),
//             (id: "ALUResult", name: "ALUResult"),
//             (id: "dummy"),
//             (id: "WriteData", name: "WriteData"),
//             (id: "ReadData", name: "ReadData"),
//           ),
//           west: (
//             (id: "rst"),
//           )
//         ),
//         ports-margins: (
//           north: (0%, 0%),
//           west: (0%, 70%)
//         )
//       )
      
//       element.block(
//         x: 0, y: 7, w: 8, h: 3,
//         id: "ctrl",
//         fill: util.colors.orange,
//         name: "Controller",
//         ports: (
//           east: (
//             (id: "Instr", name: "Instr"),
//           ),
//           south: (
//             (id: "dummy"),
//             (id: "Zero"),
//             (id: "Regsrc"),
//             (id: "PCSrc"),
//             (id: "ResultSrc"),
//             (id: "ALUControl"),
//             (id: "ImmSrc"),
//             (id: "RegWrite"),
//             (id: "MemWrite")
//           )
//         ),
//         ports-margins: (
//           south: (0%, 0%)
//         )
//       )
//       wire.wire(
//         "w-Zero",
//         ("dp-port-Zero", "ctrl-port-Zero"),
//         name: "Zero",
//         name-pos: "start",
//         directed: true
//       )
//       for p in ("Regsrc", "PCSrc", "ResultSrc", "ALUControl", "ImmSrc", "RegWrite") {
//         wire.wire(
//           "w-" + p,
//           ("ctrl-port-"+p, "dp-port-"+p),
//           name: p,
//           name-pos: "start",
//           directed: true
//         )
//       }

//       draw.content(
//         (rel: (0, 1em), to: "ctrl.north"),
//         [*RISCV single*],
//         anchor: "south"
//       )
//     })
    
//     element.block(
//       x: (rel: 3.5, to: "dp.east"),
//       y: (from: "dp-port-ReadData", to: "RD"),
//       w: 3, h: 4,
//       id: "dmem",
//       fill: util.colors.green,
//       name: "Data\n Memory",
//       ports: (
//         north: (
//           (id: "clk", clock: true, small: true),
//           (id: "WE", name: "WE")
//         ),
//         west: (
//           (id: "dummy"),
//           (id: "dummy"),
//           (id: "A", name: "A"),
//           (id: "dummy"),
//           (id: "WD", name: "WD"),
//           (id: "RD", name: "RD"),
//         )
//       ),
//       ports-margins: (
//         north: (0%, 10%)
//       )
//     )
//     wire.wire(
//       "w-DataAddr",
//       ("dp-port-ALUResult", "dmem-port-A"),
//       name: "DataAddr",
//       name-pos: "end",
//       directed: true
//     )
//     wire.wire(
//       "w-WriteData",
//       ("dp-port-WriteData", "dmem-port-WD"),
//       name: "WriteData",
//       name-pos: "end",
//       directed: true
//     )
//     wire.wire(
//       "w-ReadData",
//       ("dmem-port-RD", "dp-port-ReadData"),
//       name: "ReadData",
//       name-pos: "end",
//       reverse: true,
//       directed: true
//     )
//     wire.wire(
//       "w-MemWrite",
//       ("ctrl-port-MemWrite", "dmem-port-WE"),
//       style: "zigzag",
//       name: "MemWrite",
//       name-pos: "start",
//       zigzag-dir: "horizontal",
//       zigzag-ratio: 80%,
//       directed: true
//     )
//     wire.stub(
//       "dmem-port-clk", "north",
//       name: "clk", length: 3pt
//     )

//     element.block(
//       x: (rel: 3.5, to: "dp.east"),
//       y: (from: "ctrl-port-Instr", to: "dummy"),
//       w: 3, h: 4,
//       id: "imem",
//       fill: util.colors.green,
//       name: "Instruction\n Memory",
//       ports: (
//         west: (
//           (id: "A", name: "A"),
//           (id: "dummy"),
//           (id: "dummy2"),
//           (id: "RD", name: "RD"),
//         )
//       )
//     )
//     wire.wire(
//       "w-PC",
//       ("dp-port-PC", "imem-port-A"),
//       style: "zigzag",
//       directed: true
//     )
//     wire.wire(
//       "w-Instr1",
//       ("imem-port-RD", "dp-port-Instr"),
//       style: "zigzag",
//       zigzag-ratio: 30%,
//       directed: true
//     )
//     wire.wire(
//       "w-Instr2",
//       ("imem-port-RD", "ctrl-port-Instr"),
//       style: "zigzag",
//       zigzag-ratio: 30%,
//       directed: true
//     )
//     wire.intersection("w-Instr1.zig", radius: 2pt)
//     draw.content("w-Instr1.zig", "Instr", anchor: "south", padding: 4pt)
//     draw.content("w-PC.zig", "PC", anchor: "south-east", padding: 2pt)

//     draw.content("dmem.south-west", [*External Memories*], anchor: "north", padding: 10pt)
//   })

//   draw.line(name: "w-dp-clk",
//     "dp-port-clk",
//     (rel: (0, .5), to: ()),
//     (
//       rel: (-.5, 0),
//       to: (horizontal: "toplvl.west", vertical: ())
//     )
//   )
//   draw.content("w-dp-clk.end", "clk", anchor: "east", padding: 3pt)
  
//   draw.line(name: "w-dp-rst",
//     "dp-port-rst",
//     (
//       rel: (-.5, 0),
//       to: (horizontal: "toplvl.west", vertical: ())
//     )
//   )
//   draw.content("w-dp-rst.end", "rst", anchor: "east", padding: 3pt)
// })
// 
// 
// 
// #import "@preview/circuiteria:0.2.1": *

// #set page(width: auto, height: auto, margin: .5cm)

// #circuit({
//   element.multiplexer(
//     x: 0, y: 0, w: .5, h: 1.5, id: "PCMux",
//     entries: 2,
//     fill: util.colors.blue,
//     h-ratio: 80%
//   )
//   element.block(
//     x: (rel: 2, to: "PCMux.east"),
//     y: (from: "PCMux-port-out", to: "in"),
//     w: 1, h: 1.5, id: "PCBuf",
//     ports: (
//       north: ((id: "clk", clock: true),),
//       west: ((id: "in"),),
//       east: ((id: "out"),)
//     ),
//     fill: util.colors.green
//   )

//   element.block(
//     x: (rel: 2, to: "PCBuf.east"),
//     y: (from: "PCBuf-port-out", to: "A"),
//     w: 3, h: 4, id: "IMem",
//     ports: (
//       west: (
//         (id: "A", name: "A"),
//       ),
//       east: (
//         (id: "RD", name: "RD"),
//       )
//     ),
//     ports-margins: (
//       west: (0%, 50%),
//       east: (0%, 50%)
//     ),
//     fill: util.colors.green,
//     name: "Instruction\nMemory"
//   )
//   element.block(
//     x: (rel: 3, to: "IMem.east"),
//     y: (from: "IMem-port-RD", to: "A1"),
//     w: 4.5, h: 4, id: "RegFile",
//     ports: (
//       north: (
//         (id: "clk", clock: true, small: true),
//         (id: "WE3", name: "WE3"),
//         (id: "dummy1")
//       ),
//       west: (
//         (id: "dummy2"),
//         (id: "A1", name: "A1"),
//         (id: "dummy3"),
//         (id: "A2", name: "A2"),
//         (id: "A3", name: "A3"),
//         (id: "dummy4"),
//         (id: "WD3", name: "WD3"),
//       ),
//       east: (
//         (id: "RD1", name: "RD1"),
//         (id: "RD2", name: "RD2"),
//       )
//     ),
//     ports-margins: (
//       north: (-20%, -20%),
//       east: (0%, 10%)
//     ),
//     fill: util.colors.green,
//     name: "Register\nFile"
//   )

//   element.alu(
//     x: (rel: -.7, to: "IMem.center"),
//     y: -7,
//     w: 1.4, h: 2.8, id: "PCAdd",
//     name: text("+", size: 1.5em),
//     name-anchor: "name",
//     fill: util.colors.pink
//   )
//   element.extender(
//     x: (rel: 0, to: "RegFile.west"),
//     y: (from: "PCAdd-port-out", to: "in"),
//     w: 4, h: 1.5, id: "Ext",
//     h-ratio: 50%,
//     name: "Extend",
//     name-anchor: "south",
//     align-out: false,
//     fill: util.colors.green
//   )

//   element.multiplexer(
//     x: (rel: 3, to: "RegFile.east"),
//     y: (from: "RegFile-port-RD2", to: "in0"),
//     w: .5, h: 1.5, id: "SrcBMux",
//     fill: util.colors.blue,
//     h-ratio: 80%
//   )

//   element.alu(
//     x: (rel: 2, to: "SrcBMux.east"),
//     y: (from: "SrcBMux-port-out", to: "in2"),
//     w: 1.4, h: 2.8, id: "ALU",
//     name: rotate("ALU", -90deg),
//     name-anchor: "name",
//     fill: util.colors.pink
//   )
//   element.alu(
//     x: (rel: 2, to: "SrcBMux.east"),
//     y: (from: "Ext-port-out", to: "in2"),
//     w: 1.4, h: 2.8, id: "JumpAdd",
//     name: text("+", size: 1.5em),
//     name-anchor: "name",
//     fill: util.colors.pink
//   )

//   element.block(
//     x: (rel: 4, to: "ALU.east"),
//     y: (from: "ALU-port-out", to: "A"),
//     w: 3, h: 4, id: "DMem",
//     name: "Data\nMemory",
//     ports: (
//       north: (
//         (id: "clk", clock: true, small: true),
//         (id: "dummy1"),
//         (id: "WE", name: "WE")
//       ),
//       west: (
//         (id: "A", name: "A"),
//         (id: "WD", name: "WD")
//       ),
//       east: (
//         (id: "RD", name: "RD"),
//         (id: "dummy2")
//       )
//     ),
//     ports-margins: (
//       north: (-10%, -10%),
//       west: (-20%, -30%),
//       east: (-10%, -20%)
//     ),
//     fill: util.colors.green
//   )

//   element.multiplexer(
//     x: (rel: 3, to: "DMem.east"),
//     y: (from: "DMem-port-RD", to: "in1"),
//     w: .5, h: 1.5, id: "ResMux",
//     entries: 2,
//     fill: util.colors.blue,
//     h-ratio: 80%
//   )

//   element.block(
//     x: (rel: 0, to: "RegFile.west"),
//     y: 3.5, w: 2.5, h: 5, id: "Ctrl",
//     name: "Control\nUnit",
//     name-anchor: "north",
//     ports: (
//       west: (
//         (id: "op", name: "op"),
//         (id: "funct3", name: "funct3"),
//         (id: "funct7", name: [funct7#sub("[5]")]),
//         (id: "zero", name: "Zero"),
//       ),
//       east: (
//         (id: "PCSrc"),
//         (id: "ResSrc"),
//         (id: "MemWrite"),
//         (id: "ALUCtrl"),
//         (id: "ALUSrc"),
//         (id: "ImmSrc"),
//         (id: "RegWrite"),
//       )
//     ),
//     ports-margins: (
//       west: (40%, 0%)
//     ),
//     fill: util.colors.orange
//   )

//   // Wires
//   wire.wire(
//     "wPCNext", ("PCMux-port-out", "PCBuf-port-in"),
//     name: "PCNext"
//   )
//   wire.stub("PCBuf-port-clk", "north", name: "clk", length: 0.25)
//   wire.wire(
//     "wPC1", ("PCBuf-port-out", "IMem-port-A"),
//     name: "PC"
//   )
//   wire.wire(
//     "wPC2", ("PCBuf-port-out", "JumpAdd-port-in1"),
//     style: "zigzag",
//     zigzag-ratio: 1
//   )
//   wire.wire(
//     "wPC3", ("PCBuf-port-out", "PCAdd-port-in1"),
//     style: "zigzag",
//     zigzag-ratio: 1
//   )
//   wire.intersection("wPC2.zig")
//   wire.intersection("wPC2.zag")
//   wire.stub("PCAdd-port-in2", "west", name: "4", length: 1.5)
//   wire.wire(
//     "wPC+4", ("PCAdd-port-out", "PCMux-port-in0"),
//     style: "dodge",
//     dodge-sides: ("east", "west"),
//     dodge-y: -7.5,
//     dodge-margins: (1.2, .5),
//     name: "PC+4",
//     name-pos: "start"
//   )
  
//   let mid = ("IMem-port-RD", 50%, "RegFile-port-A1")
//   wire.wire(
//     "wInstr", ("IMem-port-RD", mid),
//     bus: true,
//     name: "Instr",
//     name-pos: "start"
//   )
//   draw.hide({
//     draw.line(name: "bus-top",
//       mid,
//       (horizontal: (), vertical: "Ctrl-port-op")
//     )
//     draw.line(name: "bus-bot",
//       mid,
//       (horizontal: (), vertical: "Ext-port-in")
//     )
//   })
//   wire.wire(
//     "wInstrBus", ("bus-top.end", "bus-bot.end"),
//     bus: true
//   )
//   wire.wire(
//     "wOp", ("Ctrl-port-op", (horizontal: mid, vertical: ())),
//     bus: true,
//     reverse: true,
//     slice: (6, 0)
//   )
//   wire.wire(
//     "wF3", ("Ctrl-port-funct3", (horizontal: mid, vertical: ())),
//     bus: true,
//     reverse: true,
//     slice: (14, 12)
//   )
//   wire.wire(
//     "wF7", ("Ctrl-port-funct7", (horizontal: mid, vertical: ())),
//     bus: true,
//     reverse: true,
//     slice: (30,)
//   )
//   wire.wire(
//     "wA1", ("RegFile-port-A1", (horizontal: mid, vertical: ())),
//     bus: true,
//     reverse: true,
//     slice: (19, 15)
//   )
//   wire.wire(
//     "wA2", ("RegFile-port-A2", (horizontal: mid, vertical: ())),
//     bus: true,
//     reverse: true,
//     slice: (24, 20)
//   )
//   wire.wire(
//     "wA3", ("RegFile-port-A3", (horizontal: mid, vertical: ())),
//     bus: true,
//     reverse: true,
//     slice: (11, 7)
//   )
//   wire.wire(
//     "wExt", ("Ext-port-in", (horizontal: mid, vertical: ())),
//     bus: true,
//     reverse: true,
//     slice: (31, 7)
//   )
//   wire.intersection("wF3.end")
//   wire.intersection("wF7.end")
//   wire.intersection("wA1.end")
//   wire.intersection("wA2.end")
//   wire.intersection("wA3.end")

//   wire.stub("RegFile-port-clk", "north", name: "clk", length: 0.25)
//   wire.wire("wRD2", ("RegFile-port-RD2", "SrcBMux-port-in0"))
//   wire.wire(
//     "wWD", ("RegFile-port-RD2", "DMem-port-WD"),
//     style: "zigzag",
//     zigzag-ratio: 1.5,
//     name: "WriteData",
//     name-pos: "end"
//   )
//   wire.intersection("wWD.zig")

//   wire.wire(
//     "wImmALU", ("Ext-port-out", "SrcBMux-port-in1"),
//     style: "zigzag",
//     zigzag-ratio: 2.5,
//     name: "ImmExt",
//     name-pos: "start"
//   )
//   wire.wire(
//     "wImmJump", ("Ext-port-out", "JumpAdd-port-in2")
//   )
//   wire.intersection("wImmALU.zig")
//   wire.wire(
//     "wJumpPC", ("JumpAdd-port-out", "PCMux-port-in1"),
//     style: "dodge",
//     dodge-sides: ("east", "west"),
//     dodge-y: -8,
//     dodge-margins: (1, 1),
//     name: "PCTarget",
//     name-pos: "start"
//   )

//   wire.wire(
//     "wSrcA", ("RegFile-port-RD1", "ALU-port-in1"),
//     name: "SrcA",
//     name-pos: "end"
//   )
//   wire.wire(
//     "wSrcB", ("SrcBMux-port-out", "ALU-port-in2"),
//     name: "SrcB",
//     name-pos: "end"
//   )

//   wire.wire(
//     "wZero", (
//       ("ALU.north-east", 50%, "ALU-port-out"),
//       "Ctrl-port-zero"
//     ),
//     style: "dodge",
//     dodge-sides: ("east", "west"),
//     dodge-y: 3,
//     dodge-margins: (1.5, 1),
//     name: "Zero",
//     name-pos: "start"
//   )
//   wire.wire(
//     "wALURes1", ("ALU-port-out", "DMem-port-A"),
//     name: "ALUResult",
//     name-pos: "start"
//   )
//   wire.wire(
//     "wALURes2", ("ALU-port-out", "ResMux-port-in0"),
//     style: "dodge",
//     dodge-sides: ("east", "west"),
//     dodge-y: 2,
//     dodge-margins: (3, 2)
//   )
//   wire.intersection("wALURes2.start2")

//   wire.stub("DMem-port-clk", "north", name: "clk", length: 0.25)
//   wire.wire(
//     "wRD", ("DMem-port-RD", "ResMux-port-in1"),
//     name: "ReadData",
//     name-pos: "start"
//   )

//   wire.wire(
//     "wRes", ("ResMux-port-out", "RegFile-port-WD3"),
//     style: "dodge",
//     dodge-sides: ("east", "west"),
//     dodge-y: -7.5,
//     dodge-margins: (1, 2)
//   )
//   draw.content(
//     "wRes.dodge-start",
//     "Result",
//     anchor: "south-east",
//     padding: 5pt
//   )

//   // Other wires
//   draw.group({
//     draw.stroke(util.colors.blue)
//     draw.line(name: "wPCSrc", 
//       "Ctrl-port-PCSrc",
//       (horizontal: "RegFile.east", vertical: ()),
//       (horizontal: (), vertical: (rel: (0, 0.5), to: "Ctrl.north")),
//       (horizontal: "PCMux.north", vertical: ()),
//       "PCMux.north"
//     )
//     draw.line(name: "wResSrc",
//       "Ctrl-port-ResSrc",
//       (horizontal: "ResMux.north", vertical: ()),
//       "ResMux.north"
//     )
//     draw.line(name: "wMemWrite",
//       "Ctrl-port-MemWrite",
//       (horizontal: "DMem-port-WE", vertical: ()),
//       "DMem-port-WE"
//     )
//     draw.line(name: "wALUCtrl",
//       "Ctrl-port-ALUCtrl",
//       (horizontal: "ALU.north", vertical: ()),
//       "ALU.north"
//     )
//     draw.line(name: "wALUSrc",
//       "Ctrl-port-ALUSrc",
//       (horizontal: "SrcBMux.north", vertical: ()),
//       "SrcBMux.north"
//     )
//     draw.line(name: "wImmSrc",
//       "Ctrl-port-ImmSrc",
//       (rel: (1, 0), to: (horizontal: "RegFile.east", vertical: ())),
//       (horizontal: (), vertical: (rel: (0, -.5), to: "RegFile.south")),
//       (horizontal: "Ext.north", vertical: ()),
//       "Ext.north"
//     )
//     draw.line(name: "wRegWrite",
//       "Ctrl-port-RegWrite",
//       (rel: (.5, 0), to: (horizontal: "RegFile.east", vertical: ())),
//       (horizontal: (), vertical: ("Ctrl.south", 50%, "RegFile.north")),
//       (horizontal: "RegFile-port-WE3", vertical: ()),
//       "RegFile-port-WE3"
//     )

//     let names = (
//       "PCSrc": "PCSrc",
//       "ResSrc": "ResultSrc",
//       "MemWrite": "MemWrite",
//       "ALUCtrl": [ALUControl#sub("[2:0]")],
//       "ALUSrc": "ALUSrc",
//       "ImmSrc": [ImmSrc#sub("[1:0]")],
//       "RegWrite": "RegWrite"
//     )
//     for (port, name) in names {
//       draw.content("Ctrl-port-"+port, name, anchor: "south-west", padding: 3pt)
//     }
//   })
// })