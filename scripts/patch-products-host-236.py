"""Patch the already bundled runtime; never replace its root delegate with raw source."""
import io,zipfile,copy
from pathlib import Path

def candidate(blob):
    old=zipfile.ZipFile(io.BytesIO(blob));runtime='_discount_review/merchant-products/index.js'
    source=old.read(runtime).decode()
    before='const actor = require_merchant_lifecycle().merchantRequestContext.getStore();\n  if (actor?.deviceGuards) return actor.businessId;'
    after='const actor = require_merchant_lifecycle().merchantRequestContext.getStore();\n  return actor?.businessId || null;'
    assert source.count(before)==1,'UNEXPECTED_PRODUCT_RUNTIME'
    replacements={runtime:source.replace(before,after).encode(),
                  'product_management_handler.js':b"'use strict';\nmodule.exports = require('./_discount_review/merchant-products/index.js');\n"}
    out=io.BytesIO()
    with zipfile.ZipFile(out,'w',zipfile.ZIP_DEFLATED) as z:
        for entry in old.infolist():z.writestr(copy.copy(entry),replacements.get(entry.filename,old.read(entry.filename)))
    actual=zipfile.ZipFile(io.BytesIO(out.getvalue()))
    assert actual.namelist()==old.namelist()
    assert all(actual.read(n)==old.read(n) for n in old.namelist() if n not in replacements)
    return out.getvalue(),replacements

if __name__=='__main__':
    data,changed=candidate(Path('/private/tmp/products-236-base.zip').read_bytes())
    Path('/private/tmp/products-236-candidate.zip').write_bytes(data)
    import os
    root=Path('/private/tmp/products-236-runtime');root.mkdir(exist_ok=True)
    with zipfile.ZipFile(io.BytesIO(data)) as z:z.extractall(root)
    print('Prepared bounded bundled runtime patch; unchanged entries verified')
