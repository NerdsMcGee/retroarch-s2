#!/usr/bin/env python3
# build_core.py <name> [subdir]: clone via libretro-super recipe, add libounce
# platform, build static .a into $SW2_OUT/<name>.a.
# Paths come from the environment, as switch2/env.sh sets them; unset ones
# default to the layout that file describes, relative to this checkout.
import os, re, subprocess, sys, glob, shutil
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.environ.get("SW2_REPO") or os.path.dirname(HERE)
WORK = os.environ.get("SW2_WORK") or os.path.dirname(REPO)
ROOT = os.environ.get("SW2_CORES") or os.path.join(WORK, "cores")
OUT = os.environ.get("SW2_OUT") or os.path.join(ROOT, "out")
LOGS = os.environ.get("SW2_LOGS") or ROOT
RECIPES = os.environ.get("SW2_RECIPES") or os.path.join(WORK, "libretro-super", "recipes", "nintendo", "libnx")
DKP = os.environ.get("DEVKITPRO") or "/opt/devkitpro"
DKA64 = os.environ.get("DEVKITA64") or os.path.join(DKP, "devkitA64")
name = sys.argv[1]
env = dict(os.environ, DEVKITPRO=DKP, DEVKITA64=DKA64)
env["PATH"] = os.path.join(DKP, "tools", "bin") + os.pathsep + os.path.join(DKA64, "bin") + os.pathsep + env["PATH"]
rec = None
for l in open(RECIPES):
    p = l.split()
    if p and p[0] == name:
        rec = p
        break
if not rec:
    sys.exit("no recipe " + name)
_, d, url, branch, _, _, mk, sub = rec[:8]
if len(sys.argv) > 2: sub = sys.argv[2]
src = os.path.join(ROOT, d)
if not os.path.isdir(src):
    subprocess.check_call(["git", "clone", "--depth", "1", "--recurse-submodules", "-b", branch, url, src])
bd = os.path.normpath(os.path.join(src, sub))
cands = [os.path.join(bd, mk)] + sorted(glob.glob(os.path.join(bd, "Makefile*"))) + sorted(glob.glob(os.path.join(bd, "*.mk")))
pat = re.compile(r"ifeq\s*\(\s*\$\(platform\)\s*,\s*libnx\s*\)")
mkpath = cands[0]
for c in cands:
    if os.path.isfile(c) and any(pat.search(l) or "platform), libounce" in l for l in open(c, errors="replace")):
        mkpath = c
        break
lines = open(mkpath).read().split("\n")
if any("platform), libounce" in l or "platform),libounce" in l for l in lines):
    print("already patched")
else:
    start = None
    for i, l in enumerate(lines):
        if re.search(r"ifeq\s*\(\s*\$\(platform\)\s*,\s*libnx\s*\)", l):
            start = i
            break
    if start is None:
        sys.exit("no libnx block in " + mkpath)
    end = start + 1
    while end < len(lines) and not re.match(r"\s*(else\s+ifeq|else\s+ifneq|else\b|endif)", lines[end]) and not re.match(r"\s*else\s+ifeq", lines[end]):
        end += 1
    blk = lines[start:end]
    new = []
    for l in blk:
        l = re.sub(r"(\$\(platform\)\s*,\s*)libnx", r"\1libounce", l)
        l = l.replace("libnx/switch_rules", "libounce/switch2_rules")
        l = l.replace("$(DEVKITPRO)/libnx", "$(DEVKITPRO)/libounce")
        l = l.replace("-D__SWITCH__", "-D__SWITCH__ -D__SWITCH2__", 1) if "-D__SWITCH2__" not in l else l
        l = l.replace("_libretro_$(platform)", "_libretro_libnx")
        new.append(l)
    lines[end:end] = new[:1] and (["# libounce (Switch 2)"] + new)
    # first line of new block must begin as 'else ifeq' to chain; fix if original began with plain 'ifeq'
    open(mkpath, "w").write("\n".join(lines))
args = ["make", "-f", mk, "platform=libounce", "-j8"]
log = os.path.join(LOGS, name + ".log")
with open(log, "w") as f:
    r = subprocess.call(args, cwd=bd, env=env, stdout=f, stderr=subprocess.STDOUT)
arch = sorted(glob.glob(os.path.join(bd, "*_libretro_libnx.a")) + glob.glob(os.path.join(bd, "*libnx*.a")), key=os.path.getmtime)
if r != 0 or not arch:
    print("FAIL", name, "rc", r, "(see", log + ")")
    sys.exit(1)
os.makedirs(OUT, exist_ok=True)
shutil.copy(arch[-1], os.path.join(OUT, name + ".a"))
print("OK", name, os.path.getsize(arch[-1]))
