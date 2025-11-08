import os, ast, json, argparse

EXCLUDE_DIRS = {".venv", "__pycache__", ".git"}

def discover_python_files(root):
    for base, dirs, files in os.walk(root):
        dirs[:] = [d for d in dirs if d not in EXCLUDE_DIRS]
        for f in files:
            if f.endswith(".py"):
                yield os.path.join(base, f)

def ast_sig(fn: ast.FunctionDef) -> str:
    a = fn.args
    parts = []
    for x in getattr(a, "posonlyargs", []):
        parts.append(x.arg)
    if getattr(a, "posonlyargs", []):
        parts.append("/")
    for x in a.args:
        parts.append(x.arg)
    if a.vararg:
        parts.append("*" + a.vararg.arg)
    elif a.kwonlyargs:
        parts.append("*")
    for x in a.kwonlyargs:
        parts.append(x.arg)
    if a.kwarg:
        parts.append("**" + a.kwarg.arg)
    return "(" + ", ".join(parts) + ")"

def collect(project_root):
    out = []
    for path in discover_python_files(project_root):
        rel = os.path.relpath(path, project_root)
        try:
            src = open(path, "r", encoding="utf-8", errors="ignore").read()
            tree = ast.parse(src)
        except Exception:
            continue
        mod = os.path.splitext(rel)[0].replace(os.sep, ".")
        if mod.endswith(".__init__"):
            mod = mod.rsplit(".__init__", 1)[0]
        for node in tree.body:
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
                out.append({
                    "module": mod,
                    "function": node.name,
                    "signature": ast_sig(node),
                    "async": isinstance(node, ast.AsyncFunctionDef),
                    "file": rel
                })
    return sorted(out, key=lambda x: (x["module"], x["function"]))

def main():
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("--project", default=os.getcwd())
    ap.add_argument("--export", choices=["md","json"], nargs="+", default=["md","json"])
    ns = ap.parse_args()
    data = collect(ns.project)
    if "json" in ns.export:
        with open(os.path.join(ns.project, "FUNCIONES.json"), "w", encoding="utf-8") as fh:
            json.dump(data, fh, indent=2, ensure_ascii=False)
    if "md" in ns.export:
        with open(os.path.join(ns.project, "FUNCIONES.md"), "w", encoding="utf-8") as fh:
            fh.write("# Inventario de funciones (Starlab)\n\n")
            last = None
            for r in data:
                if r["module"] != last:
                    if last is not None: fh.write("\n")
                    fh.write(f"## {r['module']}\n")
                    last = r["module"]
                tag = "async " if r["async"] else ""
                fh.write(f"- **{tag}{r['function']}**`{r['signature']}` — _{r['file']}_\n")
    print("Listo.")

if __name__ == "__main__":
    main()
