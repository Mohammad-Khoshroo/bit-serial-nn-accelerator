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

# Test and Run project

first choose the target arch (raw/bit-serial/sparsity-aware) from makefile then:
```bash
make clean
make > terminal.log 2>&1
```
