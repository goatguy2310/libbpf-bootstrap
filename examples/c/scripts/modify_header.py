import argparse

parser = argparse.ArgumentParser()

parser.add_argument("def_file")
parser.add_argument("output_file")
parser.add_argument("prog_type")
parser.add_argument("table_file")

args = parser.parse_args()

# extract kallsyms
kallsyms_to_addr = dict()
with open("/proc/kallsyms") as f:
    for l in f:
        l_splitted = l.split()
        if len(l_splitted) != 3:
            continue
        ad, c, name = l_splitted
        kallsyms_to_addr[name] = ad

# create dict from id to addr
id_to_addr = dict()
with open(args.table_file, "r") as f:
    lines = f.read().split("\n")[1:]
    helpers = lines[int(args.prog_type)].split(", ")
    for j, sym in enumerate(helpers):
        id_to_addr[j] = kallsyms_to_addr.get(sym, "0")
# print(id_to_addr)

res = ""

with open(args.def_file, "r") as f:
    for l in f:
        spl = l.split()
        if len(spl) == 0 or len(spl[-1]) == 0:
            res += l
            continue
        pre, last = " ".join(spl[:-1]), spl[-1]
        id = last[:-1]
        
        if not id.isnumeric() or spl[0] == "*" or last[-1] != ";":
            res += l
            continue

        # print(id, id_to_addr)
        res += f"{pre} 0x{id_to_addr[int(id)]};\n"

# insert kallsyms to macros
def insert_to_macros(sym):
    global res
    res = res.replace(f"<{sym}>", f"0x{kallsyms_to_addr[sym]}")

insert_to_macros("cpu_number")
insert_to_macros("this_cpu_off")

with open(args.output_file, "w") as f:
    f.write(res)
