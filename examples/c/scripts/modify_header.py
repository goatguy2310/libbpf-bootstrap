import argparse

parser = argparse.ArgumentParser()

parser.add_argument("def_file")
parser.add_argument("output_file")
parser.add_argument("map_file")

args = parser.parse_args()

id_to_addr = dict()
with open(args.map_file, "r") as f:
    for l in f:
        id, fun, addr = l.split()
        id_to_addr[int(id)] = (fun, addr)
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

        info = id_to_addr[int(id)]
        if info[0] not in l:
            res += l
            continue

        # print(id, info)
        res += f"{pre} 0x{info[1]};\n"

with open(args.output_file, "w") as f:
    f.write(res)
