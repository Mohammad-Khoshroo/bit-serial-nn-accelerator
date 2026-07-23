import os
from pathlib import Path
from cocotb_tools.runner import get_runner

def test_runner():
    
    sim = os.getenv("SIM", "verilator")
    
    proj_path = Path(__file__).resolve().parent

    sources = []
    for pattern in ["hardware/**/*.v", "hardware/**/*.sv"]:
        sources.extend(proj_path.glob(pattern))

    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="cluster_wrapper",
        build_dir="build",
        includes=[str(proj_path / "hardware" / "include")],  # For hw_config.vh
        extra_args=["--trace", "--timing"] # pyright: ignore[reportCallIssue]
    )

    runner.test(
        hdl_toplevel="cluster_wrapper",
        test_module="test_bench",
        test_dir=str(proj_path),
        extra_env={"PYTHONPATH": str(proj_path / "src")}
    )

if __name__ == "__main__":
    test_runner()