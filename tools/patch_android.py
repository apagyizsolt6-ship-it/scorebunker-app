#!/usr/bin/env python3
"""A `flutter create .` után lefutó javítások az Android projekten:
 - engedélyek (internet, értesítések, rezgés)
 - az app neve: APISCORES
 - kék háttér az indításkor (a Flutter animált indítóképernyője előtt)
 - a plugin-modulok lint-vital feladatának kikapcsolása (lint-összeomlás ellen)
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
    'android.permission.REQUEST_INSTALL_PACKAGES',
):
    if perm not in text:
        tag = f'<uses-permission android:name="{perm}"/>'
        text = text.replace('<application', tag + '\n    <application', 1)

text = re.sub(r'android:label="[^"]*"', 'android:label="APISCORES"', text, count=1)
manifest.write_text(text, encoding='utf-8')
print('manifest ok')

# ---------- indítási háttér: fehér helyett kék ----------
for d in ('drawable', 'drawable-v21'):
    lb = root / 'src/main/res' / d / 'launch_background.xml'
    if lb.exists():
        t = lb.read_text(encoding='utf-8')
        t2 = t.replace('@android:color/white', '#FF1A73E8')
        if t2 != t:
            lb.write_text(t2, encoding='utf-8')
            print('launch background ok:', lb)

# ---------- lint-vital kikapcsolása (a plugin-modulok lint-összeomlása miatt) ----------
# A `lintVitalAnalyzeRelease` feladat egyes pluginoknál (pl. url_launcher_android)
# összeomlik a JDK 17 + az Android lint verzió eltérése miatt
# (NoSuchMethodError: List.removeLast). A feladat csak statikus ellenőrzés,
# az APK tartalmát nem érinti, ezért kikapcsoljuk.
LINT_MARK = 'apiscores-lint-fix'
for name in ('build.gradle.kts', 'build.gradle'):
    rootg = pathlib.Path('android') / name
    if not rootg.exists():
        continue
    rt = rootg.read_text(encoding='utf-8')
    if LINT_MARK in rt:
        print('root gradle: lint-fix már be van állítva')
    elif name.endswith('.kts'):
        rt += (
            '\n// ' + LINT_MARK + '\n'
            'subprojects {\n'
            '    tasks.configureEach {\n'
            '        if (name.startsWith("lintVital")) {\n'
            '            enabled = false\n'
            '        }\n'
            '    }\n'
            '}\n'
        )
        rootg.write_text(rt, encoding='utf-8')
        print('root gradle lint-fix ok:', rootg)
    else:
        rt += (
            '\n// ' + LINT_MARK + '\n'
            'subprojects {\n'
            '    tasks.configureEach { t ->\n'
            "        if (t.name.startsWith('lintVital')) {\n"
            '            t.enabled = false\n'
            '        }\n'
            '    }\n'
            '}\n'
        )
        rootg.write_text(rt, encoding='utf-8')
        print('root gradle lint-fix ok:', rootg)
    break

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
