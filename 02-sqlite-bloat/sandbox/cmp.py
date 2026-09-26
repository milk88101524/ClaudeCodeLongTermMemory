import sys
a=open(sys.argv[1],'rb').read().split(b'\n'); b=open(sys.argv[2],'rb').read().split(b'\n')
# drop trailing empty from final newline
if a and a[-1]==b'': a=a[:-1]
if b and b[-1]==b'': b=b[:-1]
changed=[i for i in range(min(len(a),len(b))) if a[i]!=b[i]]
removed=list(range(len(b),len(a)))
print(f"before={len(a)} after={len(b)} prefix_identical={not changed and len(b)>=len(a)} changed_idx={changed[:50]} removed_idx={removed[:50]}")
import json
for i in changed[:5]:
    try: ta=json.loads(a[i]).get('type'); tb=json.loads(b[i]).get('type')
    except Exception: ta=tb='?'
    print(f"  [{i}] {ta} -> {tb}")
