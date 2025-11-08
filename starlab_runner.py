import os, sys, json, argparse, importlib, importlib.util, inspect, asyncio

def import_module_by_name_or_path(project_root: str, modname: str):
    if project_root not in sys.path:
        sys.path.insert(0, project_root)
    try:
        return importlib.import_module(modname)
    except Exception:
        file_guess = os.path.join(project_root, *modname.split(".")) + ".py"
        if os.path.exists(file_guess):
            spec = importlib.util.spec_from_file_location(modname, file_guess)
            if spec and spec.loader:
                m = importlib.util.module_from_spec(spec)
                sys.modules[modname] = m
                spec.loader.exec_module(m)
                return m
    return None

async def _maybe_await(x):
    if inspect.isawaitable(x):
        return await x
    return x

def run(project_root: str, target: str, args_json: str):
    if ":" not in target:
        raise SystemExit("Usa modulo:function (ej. paquete.modulo:func)")
    modname, funcname = target.split(":", 1)
    mod = import_module_by_name_or_path(project_root, modname)
    if mod is None:
        raise SystemExit(f"No se pudo importar el módulo: {modname}")
    fn = getattr(mod, funcname, None)
    if not callable(fn):
        raise SystemExit(f"No existe la función: {funcname} en {modname}")
    kwargs = {}
    if args_json:
        try:
            parsed = json.loads(args_json)
            if not isinstance(parsed, dict):
                raise ValueError("Los argumentos deben ser un objeto JSON (dict).")
            kwargs = parsed
        except Exception as e:
            raise SystemExit(f"JSON inválido: {e}")
    res = fn(**kwargs)
    if inspect.isawaitable(res):
        res = asyncio.run(_maybe_await(res))
    try:
        print(json.dumps(res, ensure_ascii=False, indent=2, default=str))
    except Exception:
        print(res)

def main():
    ap = argparse.ArgumentParser(description="Runner de funciones Starlab")
    ap.add_argument("--project", default=os.getcwd())
    ap.add_argument("--run", required=True, help="modulo:function")
    ap.add_argument("--args", default=None, help="kwargs en JSON")
    ns = ap.parse_args()
    run(ns.project, ns.run, ns.args)

if __name__ == "__main__":
    main()
