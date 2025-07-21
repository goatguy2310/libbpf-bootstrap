from pathlib import Path
import argparse

script_path = Path(__file__).resolve().parent
parent_path = script_path.parent

def log_line_to_dict(line):
    if "EBPF_INFO" not in line:
        return False

    splitted = line.split()
    start_idx = splitted.index("EBPF_INFO:")

    entries = splitted[start_idx + 1:]

    res = dict()
    for e in entries:
        key, value = e.split("=")
        res[key] = value

    return res

parser = argparse.ArgumentParser()

parser.add_argument("prog")
parser.add_argument("pid")
parser.add_argument("log_file")

args = parser.parse_args()

ld_template = script_path / "template.ld"

map_addr = ""
internal_addr = ""

with open(ld_template) as f:
    template = f.read()

with open(parent_path / args.log_file, "r") as f:
    for line in f:
        data = log_line_to_dict(line)
        if not data or data["pid"] != args.pid:
            continue

        if data["type"] == "map" and not data["name"].startswith("libbpf_"):
            map_addr += f"\t{data['name']} = 0x{data['addr']};\n"
        elif data["type"] == "intsec":
            internal_addr += "\t" + data['sec_name'] + " 0x" + data['addr'] + ": { *(" + data['sec_name'] + "*) }\n"

script = template.replace("MAP_PLACEHOLDER", map_addr).replace("INTERNAL_PLACEHOLDER", internal_addr)

print(script)

with open(parent_path / f".linker_scripts/{args.prog}.ld", "w") as f:
    f.write(script)
