from pathlib import Path
from PIL import Image

p = Path(__file__).resolve().parents[1] / 'windows' / 'runner' / 'resources' / 'app_icon.ico'
backup = p.with_suffix('.ico.bak')
print('icon path:', p)
if not p.exists():
    raise SystemExit('icon not found')
# backup
if not backup.exists():
    p.rename(backup)
    p = backup
else:
    p = backup

img = Image.open(p)
print('loaded format:', img.format, 'size:', img.size)
# Convert to multiple sizes
sizes = [(256,256),(128,128),(64,64),(48,48),(32,32),(16,16)]
# Ensure image is RGBA
img = img.convert('RGBA')
# Create a list of resized images
imgs = [img.resize(s, Image.LANCZOS) for s in sizes]
# Save to new icon file (same original name)
out_path = backup.with_suffix('')  # remove .bak
out_path = out_path.with_name('app_icon.ico')
print('saving to', out_path)
imgs[0].save(out_path, format='ICO', sizes=sizes)
print('done')
