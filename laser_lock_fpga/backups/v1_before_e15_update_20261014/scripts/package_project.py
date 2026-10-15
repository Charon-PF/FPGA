"""Create a portable zip, including run checkpoints and verification reports."""
from pathlib import Path
import hashlib
import json
import sys
import zipfile

root = Path(__file__).resolve().parent.parent
destination = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else root.parent / "laser_lock_fpga_vivado2024_1.zip"
sources = sorted(list((root / "rtl").glob("*.v")) + list((root / "sim").glob("*.v")) + list((root / "constr").glob("*.xdc")))
manifest = {str(p.relative_to(root)).replace("\\", "/"): hashlib.sha256(p.read_bytes()).hexdigest() for p in sources}
(root / "reports" / "source_sha256.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
excluded = {".Xil", "laser_lock_fpga.cache", "laser_lock_fpga.sim", "laser_lock_fpga.hw"}
with zipfile.ZipFile(destination, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
    for path in sorted(root.rglob("*")):
        relative = path.relative_to(root)
        if not path.is_file() or any(part in excluded for part in relative.parts):
            continue
        if path == destination or path.suffix == ".jou" or ".backup." in path.name:
            continue
        if path.name.startswith(("vivado_params", "inspect_vivado_params", "prepare_debug")):
            continue
        if "oocip_save_work_area" in relative.parts:
            continue
        archive.write(path, (Path(root.name) / relative).as_posix())
with zipfile.ZipFile(destination) as archive:
    bad = archive.testzip()
    if bad:
        raise RuntimeError(f"Bad archived file: {bad}")
    required = ["laser_lock_fpga/laser_lock_fpga.xpr", "laser_lock_fpga/rtl/laser_lock_top.v", "laser_lock_fpga/ip/laser_lock_ila/laser_lock_ila.xci", "laser_lock_fpga/reports/simulation_result.txt", "laser_lock_fpga/reports/controller_result.txt", "laser_lock_fpga/reports/build_summary.txt"]
    for name in required:
        if name not in archive.namelist():
            raise RuntimeError(f"Missing artifact: {name}")
print(f"Verified archive: {destination} ({destination.stat().st_size:,} bytes)")
