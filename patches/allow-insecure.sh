#!/usr/bin/env bash
set -euo pipefail

# Restore the removed TLS allowInsecure option at build time.
# This intentionally lives outside the normal source tree so upstream merges do
# not have to carry a permanent modification to the TLS implementation.

python3 <<'PY'
from pathlib import Path
import re


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    if new in text:
        return
    if old not in text:
        raise SystemExit(f"allow-insecure patch: marker not found in {path}: {old!r}")
    p.write_text(text.replace(old, new, 1))


# Field 1 was deliberately left unused by upstream after allowInsecure was
# removed, so restoring it here preserves compatibility with old configs.
replace_once(
    "transport/internet/tls/config.proto",
    "message Config {\n",
    "message Config {\n  // Legacy client-side option: skip TLS certificate verification.\n  bool allow_insecure = 1;\n",
)

# The JSON-facing config type lives in transport_security.go in current Xray.
conf_path = "infra/conf/transport_security.go"
replace_once(
    conf_path,
    "type TLSConfig struct {\n",
    "type TLSConfig struct {\n\tAllowInsecure           bool             `json:\"allowInsecure\"`\n",
)

# Upstream's removal block has changed formatting across revisions. Match the
# semantic block instead of depending on whitespace or the exact error text.
p = Path(conf_path)
text = p.read_text()
if "\t\tconfig.AllowInsecure = true" not in text:
    pattern = re.compile(
        r'\tif c\.AllowInsecure \{\n'
        r'\t\treturn nil, errors\.PrintRemovedFeatureError\(.*?\n'
        r'\t\}\n',
        re.DOTALL,
    )
    text, count = pattern.subn(
        "\tif c.AllowInsecure {\n\t\tconfig.AllowInsecure = true\n\t}\n",
        text,
        count=1,
    )
    if count != 1:
        raise SystemExit("allow-insecure patch: upstream allowInsecure removal block not found in transport_security.go")
    p.write_text(text)

# Propagate the restored proto flag into Go's crypto/tls config.
tls_path = "transport/internet/tls/config.go"
replace_once(
    tls_path,
    "\trandCarrier.Config = config\n",
    "\trandCarrier.Config = config\n\tif c.AllowInsecure {\n\t\tconfig.InsecureSkipVerify = true\n\t}\n",
)
PY

protoc -I . --go_out=. --go_opt=paths=source_relative transport/internet/tls/config.proto

gofmt -w infra/conf/transport_security.go transport/internet/tls/config.go transport/internet/tls/config.pb.go

echo "allowInsecure patch applied"
