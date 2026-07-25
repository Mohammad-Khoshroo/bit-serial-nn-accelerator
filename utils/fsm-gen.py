import re
import json

def parse_verilog_fsm(verilog_code):
    # 1. استخراج Stateها از localparam یا parameter
    states = []
    param_match = re.search(r'(?:localparam|parameter)(?:\s*\[[^\]]*\])?\s+(.*?);', verilog_code, re.DOTALL)
    if param_match:
        param_str = param_match.group(1)
        states = re.findall(r'(\w+)\s*=\s*\d+', param_str)
    
    if not states:
        return [], []

    transitions = []
    
    # 2. ایزوله کردن بلاک always که مربوط به انتقال stateها است
    always_blocks = re.split(r'always\s+@', verilog_code)
    trans_block = ""
    for block in always_blocks:
        if 'case' in block and any(f'= {state}' in block or f'<= {state}' in block for state in states):
            trans_block = block
            break
            
    # 3. پیدا کردن بلاک case
    case_match = re.search(r'case\s*\([^)]+\)(.*?)endcase', trans_block, re.DOTALL | re.IGNORECASE)
    if not case_match:
        return states, transitions

    case_body = case_match.group(1)
    
    # 4. استخراج انتقال‌ها (با توجه به اینکه ممکن است stateها در یک خط باشند)
    # این الگو از نام state شروع شده تا قبل از نام state بعدی یا endcase را می‌گیرد
    state_chunks = re.finditer(r'(\w+)\s*:\s*(.*?)(?=\n\s*\w+\s*:|endcase|$)', case_body, re.DOTALL)
    
    for match in state_chunks:
        current_state = match.group(1).strip()
        logic = match.group(2).strip()
        
        if current_state not in states:
            continue
            
        # حالت الف: استفاده از عملگر سه‌تایی (Ternary) مثل ns = start ? S1 : S2
        ternary_match = re.search(r'=\s*(.*?)\s*\?\s*(\w+)\s*:\s*(\w+)', logic)
        if ternary_match:
            cond = ternary_match.group(1).strip()
            target1 = ternary_match.group(2).strip()
            target2 = ternary_match.group(3).strip()
            
            if target1 in states:
                transitions.append({"source": current_state, "target": target1, "condition": cond})
            if target2 in states:
                if cond.startswith('!') or cond.startswith('~'):
                    else_cond = cond[1:]
                else:
                    else_cond = f"!{cond}" if len(cond) < 20 else "else"
                transitions.append({"source": current_state, "target": target2, "condition": else_cond})
            continue
            
        # حالت ب: استفاده از if/else
        if_match = re.search(r'if\s*\((.*?)\)\s*\w+\s*<=?\s*(\w+)', logic)
        if if_match:
            cond = if_match.group(1).strip()
            target = if_match.group(2).strip()
            if target in states:
                transitions.append({"source": current_state, "target": target, "condition": cond})
                
            else_match = re.search(r'else\s*\w+\s*<=?\s*(\w+)', logic)
            if else_match:
                else_target = else_match.group(1).strip()
                if else_target in states:
                    if cond.startswith('!') or cond.startswith('~'):
                        else_cond = cond[1:]
                    else:
                        else_cond = f"!{cond}" if len(cond) < 20 else "else"
                    transitions.append({"source": current_state, "target": else_target, "condition": else_cond})
            continue

        # حالت ج: انتساب مستقیم (بدون شرط) مثل ns = S_CALCULATE;
        direct_match = re.search(r'\w+\s*<=?\s*(\w+)\s*;', logic)
        if direct_match:
            target = direct_match.group(1).strip()
            if target in states:
                transitions.append({"source": current_state, "target": target, "condition": "always"})

    return states, transitions

def generate_html(states, transitions):
    elements = []
    for state in states:
        elements.append({"data": {"id": state, "label": state}})
        
    for t in transitions:
        edge_id = f"{t['source']}_to_{t['target']}_{t['condition']}"
        elements.append({"data": {"id": edge_id, "source": t["source"], "target": t["target"], "label": t["condition"]}})

    # تبدیل به JSON معتبر
    elements_json = json.dumps(elements, indent=4)

    # قالب HTML به صورت کاملاً جداگانه برای جلوگیری از خطای فورمت‌دهی پایتون
    html_template = """<!DOCTYPE html>
<html lang="fa" dir="rtl">
<head>
    <meta charset="UTF-8">
    <title>FSM Diagram Viewer</title>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/cytoscape/3.23.0/cytoscape.min.js"></script>
    <style>
        body { font-family: Tahoma, Arial, sans-serif; margin: 0; padding: 0; display: flex; flex-direction: column; height: 100vh; background-color: #f0f2f5; }
        #toolbar { background: #fff; padding: 15px; box-shadow: 0 2px 5px rgba(0,0,0,0.1); z-index: 10; display: flex; justify-content: space-between; align-items: center; }
        #toolbar h2 { margin: 0; color: #333; font-size: 18px;}
        #toolbar button { background: #4CAF50; color: white; border: none; padding: 10px 20px; border-radius: 5px; cursor: pointer; font-weight: bold; transition: 0.3s; }
        #toolbar button:hover { background: #45a049; }
        #cy { flex-grow: 1; width: 100%; height: 100%; background: #fafafa; background-image: radial-gradient(#e0e0e0 1px, transparent 1px); background-size: 20px 20px; }
    </style>
</head>
<body>
    <div id="toolbar">
        <h2>دیاگرام ماشین حالت (FSM) - cluster_ctrl</h2>
        <button onclick="exportImage()">📸 خروجی عکس (PNG)</button>
    </div>
    <div id="cy"></div>

    <script>
        const elements = __ELEMENTS_JSON__;

        const cy = cytoscape({
            container: document.getElementById('cy'),
            elements: elements,
            style: [
                {
                    selector: 'node',
                    style: {
                        'label': 'data(label)',
                        'text-valign': 'center',
                        'color': '#fff',
                        'background-color': '#673AB7',
                        'border-width': 2,
                        'border-color': '#512DA8',
                        'width': 120,
                        'height': 50,
                        'font-size': '14px',
                        'font-weight': 'bold',
                        'shape': 'roundrectangle'
                    }
                },
                {
                    selector: 'edge',
                    style: {
                        'label': 'data(label)',
                        'curve-style': 'bezier',
                        'target-arrow-shape': 'triangle',
                        'target-arrow-color': '#555',
                        'line-color': '#555',
                        'width': 2,
                        'text-background-color': '#fff',
                        'text-background-opacity': 1,
                        'text-background-padding': '2px',
                        'text-background-shape': 'roundrectangle',
                        'font-size': '12px',
                        'color': '#333',
                        'text-rotation': 'autorotate',
                        'loop-direction': '180deg',
                        'loop-sweep': '30deg'
                    }
                }
            ],
            layout: {
                name: 'cose',
                animate: true,
                nodeRepulsion: 10000,
                idealEdgeLength: 150
            }
        });

        function exportImage() {
            const png64 = cy.png({
                full: true,
                scale: 3,
                bg: '#ffffff'
            });
            
            const a = document.createElement('a');
            a.href = png64;
            a.download = 'cluster_ctrl_fsm.png';
            document.body.appendChild(a);
            a.click();
            document.body.removeChild(a);
        }
    </script>
</body>
</html>"""

    # جایگزینی JSON در قالب HTML
    html_content = html_template.replace("__ELEMENTS_JSON__", elements_json)

    with open("fsm_diagram.html", "w", encoding="utf-8") as f:
        f.write(html_content)
    print("✅ فایل fsm_diagram.html با موفقیت ساخته شد. آن را در مرورگر باز کنید.")


# ----- کد وریلاگ شما -----
verilog_code = """
`include "hw_config.vh"

module cluster_ctrl(
    input clk,
    input rstn,
    input start,
    output reg logic_wen,
    output reg done,
    output reg ra_ld_axi,
    output reg ra_ld_acc,
    output reg axi_ram_ld,
    output reg input_weight_ren,
    output reg input_counter_clr,
    output reg input_counter_ld,
    input input_counter_co
);

localparam [2:0] S_IDLE = 0, S_LD_BETA = 1, S_WAIT_BETA = 2, S_WAIT_MEM = 3, S_CALCULATE = 4, S_WRITE_TO_MEM = 5, S_WAIT_ACK = 6;
reg [2:0] ps, ns;

always @(posedge clk) begin
    ps <= ns;
    if (!rstn)
        ps <= S_IDLE;
end

always @(*) begin
    ns = S_IDLE;
    case(ps)
    S_IDLE: ns = start ? S_LD_BETA : S_IDLE;
    S_LD_BETA: ns = S_CALCULATE;
    S_CALCULATE: ns = input_counter_co ? S_WRITE_TO_MEM : S_CALCULATE;
    S_WRITE_TO_MEM: ns = S_WAIT_ACK;
    S_WAIT_ACK: ns = ~start ? S_IDLE : S_WAIT_ACK;
    endcase
end

always @(*) begin
    {done, ra_ld_acc, input_weight_ren, ra_ld_axi,input_counter_clr,input_counter_ld, axi_ram_ld, logic_wen} = 0;
    case(ps)
    S_IDLE:{input_counter_clr} = 1'b1;
    S_LD_BETA: ra_ld_axi = 1'b1;
    S_CALCULATE: {input_weight_ren, ra_ld_acc, input_counter_ld} = 3'b111;
    S_WRITE_TO_MEM: {axi_ram_ld, logic_wen, done} = 3'b111;
    S_WAIT_ACK: {logic_wen ,done} = {~start, start};
    endcase
end

endmodule
"""

if __name__ == "__main__":
    states, transitions = parse_verilog_fsm(verilog_code)
    generate_html(states, transitions)