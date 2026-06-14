import re
import json

log_path = r'C:\Users\Mhmd\.gemini\antigravity-ide\brain\613e4a29-6eec-4d5a-8b69-eb020e9e6c65\.system_generated\logs\transcript.jsonl'
lines = []
with open(log_path, 'r', encoding='utf-8') as f:
    for line in f:
        lines.append(json.loads(line))

diff_msg = None
for i in range(len(lines)-1, -1, -1):
    content = lines[i].get('content', '')
    if '[diff_block_start]' in content:
        diff_msg = content
        break

if not diff_msg:
    print('Diff not found')
    exit()

diff_block = diff_msg.split('[diff_block_start]')[1].split('[diff_block_end]')[0]

out_lines = []
for line in diff_block.split('\n'):
    if line.startswith('-'):
        out_lines.append(line[1:])

with open('lib/features/schedule_screen/screens/teachers_schedule_screen.dart', 'w', encoding='utf-8') as f:
    f.write('\n'.join(out_lines))

print(f'File recovered successfully! {len(out_lines)} lines written.')
