import csv
from pprint import pprint as print

CSV_FILE = '/home/fky/iladata.csv'
TRACE_FILE = '/home/fky/playground/nsc/func_test_v0.01/cpu132_gettrace/golden_trace.txt'

ROW_RB_EN = "u_cpu/openmips0/debug_wb_rf_wen[3:0]"
ROW_PC = "u_cpu/openmips0/debug_wb_pc[31:0]"
ROW_RB_NUM = "u_cpu/openmips0/debug_wb_rf_wnum[4:0]"
ROW_RB_DATA = "u_cpu/openmips0/debug_wb_rf_wdata[31:0]"

with open(CSV_FILE) as f:
    reader = csv.DictReader(f)
    columns =  [[row[ROW_RB_EN],row[ROW_PC], row[ROW_RB_NUM], row[ROW_RB_DATA]] for row in reader]

with open(TRACE_FILE) as f:
    rows = f.readlines()
rows = [i.strip().split() for i in rows]
        

columns = [i for i in columns if i[0] != '0' and int(i[1], 16) != 0 and int(i[2],16) != 0]

print(columns[-10:])

flag = False
start_index = 0
for i, row in enumerate(rows):
    if columns[0][1:] == row[1:]:
        flag = True
        start_index = i
        break;

if flag == False:
    print("WARNING!!!")
    print("cannot find")
    print(columns[0])
    exit(0)


for i,row in enumerate(columns):
    try:
        if row[1:] != rows[i + start_index][1:]:
            print("WARNING!!!")
            print(i+1)
            print(row[1:])
            print(i + start_index +1)
            print(rows[i+start_index])
            break
    except:
        break

with open("output.txt", "w") as f:
    for row in columns:
        t = ["1"] + [str(i) for i in row[1:]]
        f.write(' '.join(t) + '\n')
