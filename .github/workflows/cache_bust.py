"""Give the web export a new pack URL so browsers do not keep the previous game."""
import os
import pathlib
import sys

sha = os.environ.get("SHA", "dev")[:8]
root = pathlib.Path("build/web")
html_path = root / "index.html"
if not html_path.exists():
    print("cache-bust skipped: no index.html")
    sys.exit(0)
text = html_path.read_text(encoding="utf-8")
new = "index.%s" % sha
updated = text.replace('"executable":"index"', '"executable":"%s"' % new)
updated = updated.replace('"executable": "index"', '"executable": "%s"' % new)
if updated == text:
    print("cache-bust skipped: executable field not found")
    sys.exit(0)
for path in sorted(root.glob("index*.wasm"), key=lambda item: len(item.name), reverse=True):
    renamed = new + path.name[len("index"):]
    updated = updated.replace(path.name, renamed)
    path.rename(root / renamed)
    print("%s -> %s" % (path.name, renamed))
pack = root / "index.pck"
if not pack.exists():
    print("cache-bust aborted: index.pck missing")
    sys.exit(1)
updated = updated.replace("index.pck", "%s.pck" % new)
pack.rename(root / ("%s.pck" % new))
print("index.pck -> %s.pck" % new)
if "</head>" in updated:
    updated = updated.replace("</head>", '<meta name="bf-build" content="%s"></head>' % sha, 1)
html_path.write_text(updated, encoding="utf-8")
script = root / "index.js"
if script.exists():
    body = script.read_text(encoding="utf-8")
    body = body.replace('"executable":"index"', '"executable":"%s"' % new)
    body = body.replace('"executable": "index"', '"executable": "%s"' % new)
    if "index.pck" in body:
        body = body.replace("index.pck", "%s.pck" % new)
    script.write_text(body, encoding="utf-8")
print("cache-bust", sha)
