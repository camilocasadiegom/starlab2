def patch_pydantic_py312():
    # Corrige la llamada a ForwardRef._evaluate en Py 3.12 para Pydantic v1
    import pydantic.typing as ptyping
    def _eval(type_, globalns, localns):
        try:
            # Firmas antiguas (Py<3.12)
            return type_._evaluate(globalns, localns, set())
        except TypeError:
            # Py3.12 requiere keyword-only 'recursive_guard'
            return type_._evaluate(globalns, localns, recursive_guard=set())
    ptyping.evaluate_forwardref = _eval
