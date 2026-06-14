import json

log_path = r'C:\Users\Mhmd\.gemini\antigravity-ide\brain\613e4a29-6eec-4d5a-8b69-eb020e9e6c65\.system_generated\logs\transcript.jsonl'
lines = []
with open(log_path, 'r', encoding='utf-8') as f:
    for line in f:
        lines.append(json.loads(line))

largest_diff = ''
for line in lines:
    content = line.get('content', '')
    if '[diff_block_start]' in content:
        diff_block = content.split('[diff_block_start]')[1].split('[diff_block_end]')[0]
        if len(diff_block) > len(largest_diff):
            largest_diff = diff_block

out_lines = []
for line in largest_diff.split('\n'):
    if line.startswith('-'):
        out_lines.append(line[1:])
    elif line.startswith(' '):
        out_lines.append(line[1:])
    elif line == '':
        out_lines.append('')

with open('temp_teachers_schedule_screen.dart', 'w', encoding='utf-8') as f:
    f.write('\n'.join(out_lines))

print(f'File extracted successfully! {len(out_lines)} lines written. Length of largest diff was {len(largest_diff)}')
