import sys
sys.path.append("/data/data/com.termux/files/usr/lib/python3.12/site-packages")

from .py312_pydantic_compat import patch_pydantic_py312
patch_pydantic_py312()

from .web_app import app

