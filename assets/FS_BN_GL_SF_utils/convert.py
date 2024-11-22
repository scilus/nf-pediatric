#!/usr/bin/env python
import sys
import json

with open(sys.argv[1]) as f:
    content = f.readlines()

content = [x.strip().split() for x in content] 
print(len(content))
dict_data = {}
for line in content:
	if line and line[0].isnumeric():
		print(line)
		if '_RH_' in line[1]:
			dict_data['rh.'+line[1]] = line[0]
		elif '_LH_' in line[1]:
			dict_data['lh.'+line[1]] = line[0]

with open(sys.argv[1].replace('txt', 'json'), 'w') as outfile:
    json.dump(dict_data, outfile, indent=2)