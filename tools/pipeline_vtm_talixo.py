import os, re, json, datetime, shutil, subprocess
from pathlib import Path

import pandas as pd

# Intentamos usar pdfplumber; si está tabula (requiere Java), también
USE_TABULA = False
try:
    import pdfplumber
except Exception:
    pdfplumber = None

try:
    import tabula  # tabula-py
    USE_TABULA = True
except Exception:
    pass

BASE = Path("/data/data/com.termux/files/home/starlab2")
IN_VTM = BASE / "invoices" / "vtm"
IN_TALIXO = BASE / "invoices" / "talixo"
DATA = BASE / "data"
OUT = BASE / "output"
OUT_VTM_DRIVERS = OUT / "vtm_por_conductor"
OUT_TALIXO_DRIVERS = OUT / "talixo_por_conductor"
TARIFAS = json.load(open(BASE / "tools" / "tarifas.json", "r"))

TODAY = datetime.datetime.now().strftime("%Y%m%d")

def ensure_dirs():
    for d in [IN_VTM, IN_TALIXO, DATA, OUT, OUT_VTM_DRIVERS, OUT_TALIXO_DRIVERS]:
        d.mkdir(parents=True, exist_ok=True)

def clean_money(x):
    if pd.isna(x): return 0.0
    s = str(x).replace("€","").replace(",","").strip()
    # Cambia separador decimal si viene con coma
    if re.match(r"^\d+\.\d+$", s): return float(s)
    if re.match(r"^\d+\,\d+$", s): return float(s.replace(",", "."))
    try: return float(s)
    except: return 0.0

def classify_service(txt):
    t = (txt or "").lower()
    if "airport" in t or "air" in t:
        return "airport"
    if "hour" in t or "hora" in t:
        return "hourly"
    if "long" in t or "dist" in t or "km" in t:
        return "long_distance"
    if "transfer" in t or "traslado" in t:
        return "transfer"
    return "other"

def apply_tarifa(row):
    rules = TARIFAS["rules"]
    com_pct = TARIFAS["commission"]["default_pct"]
    tipo = row.get("tipo") or "other"
    km = row.get("km") or 0.0

    bruto = row.get("bruto")
    if bruto is None or bruto == 0:
        # Si no hay bruto, estimamos según tipo
        rule = rules.get(tipo, rules["other"])
        if rule["type"] == "flat":
            bruto = rule["value"]
        elif rule["type"] == "per_hour":
            # Si no tenemos horas, asigna 1h por defecto
            bruto = rule["value"] * float(row.get("horas", 1))
        elif rule["type"] == "per_km":
            bruto = rule["value"] * float(km or 0)
        else:
            bruto = 0.0

    comision = row.get("comision")
    if comision is None or comision == 0:
        comision = round(bruto * com_pct, 2)
    neto = round(bruto - comision, 2)
    return bruto, comision, neto

def extract_tables_pdf(pdf_path: Path):
    """Devuelve lista de DataFrames por cada tabla encontrada (pdfplumber o tabula)."""
    dfs = []
    if pdfplumber:
        try:
            with pdfplumber.open(str(pdf_path)) as pdf:
                for page in pdf.pages:
                    tables = page.extract_tables()
                    for t in tables or []:
                        df = pd.DataFrame(t)
                        # descartar tablas de 1-2 columnas que son cabeceras
                        if df.shape[1] >= 3 and df.shape[0] >= 2:
                            dfs.append(df)
        except Exception as e:
            pass
    if not dfs and USE_TABULA:
        try:
            dfs = tabula.read_pdf(str(pdf_path), pages="all", multiple_tables=True, lattice=True)
        except Exception:
            pass
    return dfs

def normalize_df(df: pd.DataFrame):
    """Heurística para mapear columnas a: fecha, conductor, servicio/ruta, km, bruto, comision"""
    # Normaliza headers
    df = df.copy()
    df = df.rename(columns={c: str(c).strip().lower() for c in df.columns})
    cols = list(df.columns)

    def pick(*cands):
        for c in cands:
            for cc in cols:
                if c in cc:
                    return cc
        return None

    col_fecha = pick("date","fecha")
    col_driver = pick("driver","conductor","chofer")
    col_desc = pick("service","servicio","route","ruta","desc")
    col_km = pick("km","kilomet")
    col_total = pick("total","importe","amount","bruto")
    col_comm = pick("comm","comis","commission")

    # construimos out
    out = pd.DataFrame()
    out["fecha"] = pd.to_datetime(df[col_fecha], errors="coerce") if col_fecha else pd.NaT
    out["conductor"] = df[col_driver] if col_driver in df else ""
    out["ruta_servicio"] = df[col_desc] if col_desc in df else ""
    out["km"] = df[col_km].apply(clean_money) if col_km in df else 0.0
    out["bruto"] = df[col_total].apply(clean_money) if col_total in df else 0.0
    out["comision"] = df[col_comm].apply(clean_money) if col_comm in df else 0.0
    out["tipo"] = out["ruta_servicio"].apply(classify_service)
    return out

def collect_from_folder(folder: Path, provider: str):
    rows = []
    for pdf in sorted(folder.glob("*.pdf")):
        for df in extract_tables_pdf(pdf):
            try:
                norm = normalize_df(df)
                norm["provider"] = provider
                rows.append(norm)
            except Exception:
                continue
    if not rows:
        return pd.DataFrame(columns=["fecha","conductor","ruta_servicio","km","bruto","comision","tipo","provider"])
    return pd.concat(rows, ignore_index=True)

def enrich_and_totals(df: pd.DataFrame):
    # Normalizaciones mínimas
    df["conductor"] = df["conductor"].fillna("").astype(str).str.strip()
    df["ruta_servicio"] = df["ruta_servicio"].fillna("").astype(str)
    df["km"] = pd.to_numeric(df["km"], errors="coerce").fillna(0.0)
    df["bruto"] = pd.to_numeric(df["bruto"], errors="coerce").fillna(0.0)
    df["comision"] = pd.to_numeric(df["comision"], errors="coerce").fillna(0.0)
    df["tipo"] = df["tipo"].fillna("other")

    # Aplica tarifas si falta bruto/comisión
    bs, cs, ns = [], [], []
    for _, r in df.iterrows():
        b, c, n = apply_tarifa(r.to_dict())
        bs.append(b); cs.append(c); ns.append(n)
    df["bruto"] = bs
    df["comision"] = cs
    df["neto"] = ns
    return df

def save_per_driver_reports(df: pd.DataFrame, out_dir: Path, tag: str):
    """Genera HTML + intenta PDF con wkhtmltopdf si disponible."""
    html_tpl = (BASE / "templates" / "reporte_conductor.html").read_text(encoding="utf-8")
    summary_rows = []
    for driver, g in df.groupby("conductor"):
        if not str(driver).strip():
            continue
        viajes = len(g)
        bruto = round(g["bruto"].sum(),2)
        comision = round(g["comision"].sum(),2)
        neto = round(g["neto"].sum(),2)
        filas_html = "\n".join(
            f"<tr><td>{(r['fecha'] if pd.notna(r['fecha']) else '')}</td>"
            f"<td>{r['tipo']}</td><td>{r['ruta_servicio']}</td>"
            f"<td>{r['km']}</td><td>{r['bruto']}</td><td>{r['comision']}</td><td>{r['neto']}</td></tr>"
            for _, r in g.iterrows()
        )
        html = (html_tpl
                .replace("{{conductor}}", str(driver))
                .replace("{{fecha}}", datetime.datetime.now().strftime("%Y-%m-%d %H:%M"))
                .replace("{{viajes}}", str(viajes))
                .replace("{{bruto}}", f"{bruto:.2f}")
                .replace("{{comision}}", f"{comision:.2f}")
                .replace("{{neto}}", f"{neto:.2f}")
                .replace("{{filas}}", filas_html)
               )
        safe_name = re.sub(r"[^A-Za-z0-9_-]+","_", str(driver)).strip("_") or "SIN_NOMBRE"
        html_path = out_dir / f"{safe_name}_{tag}.html"
        html_path.write_text(html, encoding="utf-8")

        # intenta PDF si está wkhtmltopdf
        try:
            subprocess.run(["which","wkhtmltopdf"], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            pdf_path = out_dir / f"{safe_name}_{tag}.pdf"
            subprocess.run(["wkhtmltopdf", str(html_path), str(pdf_path)], check=True)
        except Exception:
            pass

        summary_rows.append({"conductor": driver, "viajes": viajes, "bruto": bruto, "comision": comision, "neto": neto})
    return pd.DataFrame(summary_rows)

def main():
    ensure_dirs()
    # VTM
    vtm_df = collect_from_folder(IN_VTM, "vtm")
    if not vtm_df.empty:
        vtm_df = enrich_and_totals(vtm_df)
        vtm_raw = DATA / f"vtm_raw_{TODAY}.csv"
        vtm_df.to_csv(vtm_raw, index=False)

        # Resumen general
        vtm_summary = vtm_df.groupby("conductor", dropna=False).agg(
            viajes=("conductor","count"),
            bruto=("bruto","sum"),
            comision=("comision","sum"),
            neto=("neto","sum"),
        ).reset_index()
        with pd.ExcelWriter(OUT / "vtm_resumen_general.xlsx") as xw:
            vtm_summary.to_excel(xw, index=False, sheet_name="Resumen")
            vtm_df.to_excel(xw, index=False, sheet_name="Detalle")

        # Reportes por conductor
        save_per_driver_reports(vtm_df, OUT_VTM_DRIVERS, "vtm")

    # TALIXO
    tal_df = collect_from_folder(IN_TALIXO, "talixo")
    if not tal_df.empty:
        tal_df = enrich_and_totals(tal_df)
        tal_raw = DATA / f"talixo_raw_{TODAY}.csv"
        tal_df.to_csv(tal_raw, index=False)

        tal_summary = tal_df.groupby("conductor", dropna=False).agg(
            viajes=("conductor","count"),
            bruto=("bruto","sum"),
            comision=("comision","sum"),
            neto=("neto","sum"),
        ).reset_index()
        with pd.ExcelWriter(OUT / "talixo_resumen_general.xlsx") as xw:
            tal_summary.to_excel(xw, index=False, sheet_name="Resumen")
            tal_df.to_excel(xw, index=False, sheet_name="Detalle")

        save_per_driver_reports(tal_df, OUT_TALIXO_DRIVERS, "talixo")

    # Mensaje final
    print("OK - Pipeline completado.")
    print(f"VTM PDFs: {len(list(IN_VTM.glob('*.pdf')))} | TALIXO PDFs: {len(list(IN_TALIXO.glob('*.pdf')))}")
    if (OUT / 'vtm_resumen_general.xlsx').exists():
        print('Generado:', OUT / 'vtm_resumen_general.xlsx')
    if (OUT / 'talixo_resumen_general.xlsx').exists():
        print('Generado:', OUT / 'talixo_resumen_general.xlsx')
    print('Reportes por conductor en:', OUT_VTM_DRIVERS, 'y', OUT_TALIXO_DRIVERS)

if __name__ == "__main__":
    main()
