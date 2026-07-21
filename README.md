# Install Prerequirments

## Install Python Libs: COCOTB, COCOTB-AXI
```bash
pip install cocotb
pip install cocotbext-axi
```

## Install verilator

```bash
cd external
git clone https://github.com/verilator/verilator
cd verilator
git checkout stable
autoconf
./configure
make -j$(nproc)
sudo make install
verilator --version
```