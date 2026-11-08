#!/usr/bin/env python3
"""A `flutter create .` után lefutó javítások az Android projekten:
 - engedélyek (internet, értesítések, rezgés)
 - az app neve: APISCORES
 - core library desugaring (a flutter_local_notifications miatt kell)
Többször lefuttatva sem csinál duplikációt.
"""
import pathlib
import re
import sys

root = pathlib.Path('android/app')

# ---------- AndroidManifest ----------
manifest = root / 'src/main/AndroidManifest.xml'
text = manifest.read_text(encoding='utf-8')

for perm in (
    'android.permission.INTERNET',
    'android.permission.POST_NOTIFICATIONS',
    'android.permission.VIBRATE',
):
    if perm not in text:
        tag = f'<uses-permission android:name="{perm}"/>'
        text = text.replace('<application', tag + '\n    <application', 1)

text = re.sub(r'android:label="[^"]*"', 'android:label="APISCORES"', text, count=1)
manifest.write_text(text, encoding='utf-8')
print('manifest ok')

# ---------- build.gradle(.kts) ----------
gradle = None
for name in ('build.gradle.kts', 'build.gradle'):
    candidate = root / name
    if candidate.exists():
        gradle = candidate
        break

if gradle is None:
    print('HIBA: nem találom az android/app/build.gradle(.kts) fájlt')
    sys.exit(1)

src = gradle.read_text(encoding='utf-8')
if 'coreLibraryDesugaring' in src:
    print('gradle: a desugaring már be van állítva')
    sys.exit(0)

is_kts = gradle.name.endswith('.kts')
if not re.search(r'compileOptions\s*\{', src):
    print('HIBA: nincs compileOptions blokk a', gradle)
    sys.exit(1)

if is_kts:
    src = re.sub(r'(compileOptions\s*\{)',
                 r'\1\n        isCoreLibraryDesugaringEnabled = true', src, count=1)
    src += ('\ndependencies {\n'
            '    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n'
            '}\n')
else:
    src = re.sub(r'(compileOptions\s*\{)',
                 r'\1\n        coreLibraryDesugaringEnabled true', src, count=1)
    src += ("\ndependencies {\n"
            "    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n"
            "}\n")

gradle.write_text(src, encoding='utf-8')
print('gradle ok:', gradle)
