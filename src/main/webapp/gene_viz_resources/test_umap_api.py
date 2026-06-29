"""
Integration tests for the gene-expression UMAP overlay JSON endpoints.

These hit the running Dash/gunicorn service (skindb-dash) on 127.0.0.1:8050, so
run them ON THE SERVER after deploying the routes:

    /root/miniconda3/envs/scrna/bin/python -m unittest \
        /root/SkinDB/services/test_umap_api.py            # (or this repo copy)

Base URL overridable via UMAP_API_BASE.
"""
import json
import os
import unittest
import urllib.request
import urllib.error

BASE = os.environ.get("UMAP_API_BASE", "http://127.0.0.1:8050") + "/integrated_umap/api"
EXPECTED_PANEL = 8000


def _get(path):
    with urllib.request.urlopen(BASE + path, timeout=30) as r:
        return r.status, json.loads(r.read().decode("utf-8"))


class UmapApiTests(unittest.TestCase):

    def test_genes_list(self):
        # Human symbols are upper-case (EPCAM); mouse symbols are mouse-cased (Epcam).
        marker = {"human": "EPCAM", "mouse": "Epcam"}
        for sp in ("human", "mouse"):
            status, body = _get("/genes?species=%s" % sp)
            self.assertEqual(status, 200)
            self.assertEqual(body["species"], sp)
            self.assertEqual(len(body["genes"]), EXPECTED_PANEL)
            self.assertIn(marker[sp], body["genes"])

    def test_umap_base_shape(self):
        status, body = _get("/umap-base?species=human")
        self.assertEqual(status, 200)
        n = body["n"]
        self.assertGreater(n, 0)
        self.assertEqual(len(body["x"]), n)
        self.assertEqual(len(body["y"]), n)
        self.assertEqual(len(body["cell_ids"]), n)
        self.assertEqual(len(body["meta"]["cell_type"]["codes"]), n)
        self.assertGreater(len(body["meta"]["cell_type"]["categories"]), 1)

    def test_expression_known_gene_aligns_with_base(self):
        _, base = _get("/umap-base?species=human")
        status, expr = _get("/expression?species=human&gene=epcam")  # lower-case on purpose
        self.assertEqual(status, 200)
        self.assertEqual(expr["gene"], "EPCAM")  # canonical symbol resolved
        self.assertEqual(len(expr["values"]), base["n"])  # positional alignment
        self.assertLessEqual(expr["min"], expr["max"])
        self.assertGreaterEqual(expr["n_nonzero"], 0)

    def test_expression_unknown_gene_404(self):
        try:
            _get("/expression?species=human&gene=NOTAREALGENE123")
            self.fail("expected HTTP 404 for unknown gene")
        except urllib.error.HTTPError as e:
            self.assertEqual(e.code, 404)
            body = json.loads(e.read().decode("utf-8"))
            self.assertEqual(body["error"], "gene_not_found")

    def test_expression_missing_gene_param_400(self):
        try:
            _get("/expression?species=human")
            self.fail("expected HTTP 400 when gene param missing")
        except urllib.error.HTTPError as e:
            self.assertEqual(e.code, 400)


if __name__ == "__main__":
    unittest.main(verbosity=2)
