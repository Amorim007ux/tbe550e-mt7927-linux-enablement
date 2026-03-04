#!/usr/bin/env bash
set -euo pipefail

FNAME="DRV_WiFi_MTK_MT7925_MT7927_TP_W11_64_V5603998_20250709R.zip"
WORKDIR="/tmp/mt7927-fw"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$WORKDIR"

python3 - <<'PY'
import json, urllib.request, urllib.parse, pathlib
f='DRV_WiFi_MTK_MT7925_MT7927_TP_W11_64_V5603998_20250709R.zip'
out=pathlib.Path('/tmp/mt7927-fw')/f
token_url='https://cdnta.asus.com/api/v1/TokenHQ?filePath=https:%2F%2Fdlcdnta.asus.com%2Fpub%2FASUS%2Fmb%2F08WIRELESS%2F'+urllib.parse.quote(f)+'%3Fmodel%3DROG%2520CROSSHAIR%2520X870E%2520HERO&systemCode=rog'
req=urllib.request.Request(token_url, method='POST', headers={'Origin':'https://rog.asus.com'})
with urllib.request.urlopen(req, timeout=30) as r:
    payload=json.loads(r.read().decode())['result']
url='https://dlcdnta.asus.com/pub/ASUS/mb/08WIRELESS/{f}?model=ROG%20CROSSHAIR%20X870E%20HERO&Signature={s}&Expires={e}&Key-Pair-Id={k}'.format(f=f,s=payload['signature'],e=payload['expires'],k=payload['keyPairId'])
urllib.request.urlretrieve(url, out)
print(out)
PY

python3 - <<'PY'
import zipfile, pathlib
z = zipfile.ZipFile('/tmp/mt7927-fw/DRV_WiFi_MTK_MT7925_MT7927_TP_W11_64_V5603998_20250709R.zip')
names = [n for n in z.namelist() if n.lower().endswith('mtkwlan.dat')]
if not names:
    raise SystemExit('mtkwlan.dat not found in ZIP')
z.extract(names[0], '/tmp/mt7927-fw')
print('/tmp/mt7927-fw/' + names[0])
PY

python3 "$SCRIPT_DIR/extract_mt7927_firmware.py" /tmp/mt7927-fw/mtkwlan.dat /tmp/mt7927-fw/firmware

sudo mkdir -p /lib/firmware/mediatek/mt7927 /lib/firmware/mediatek/mt6639
sudo install -m 0644 /tmp/mt7927-fw/firmware/WIFI_MT6639_PATCH_MCU_2_1_hdr.bin /lib/firmware/mediatek/mt7927/
sudo install -m 0644 /tmp/mt7927-fw/firmware/WIFI_RAM_CODE_MT6639_2_1.bin /lib/firmware/mediatek/mt7927/
sudo install -m 0644 /tmp/mt7927-fw/firmware/BT_RAM_CODE_MT6639_2_1_hdr.bin /lib/firmware/mediatek/mt6639/

echo "Firmware installed."
