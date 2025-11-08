#!/bin/bash

# Configuration
TARGET="$1"
OUTPUT_DIR="reports"
OUTPUT_JSON="$OUTPUT_DIR/nmap_vuln.json"
OUTPUT_XML="$OUTPUT_DIR/nmap_vuln.xml"

# Créer le dossier de rapports
mkdir -p "$OUTPUT_DIR"

# Exécuter Nmap et générer le XML
echo "[*] Exécution du scan Nmap sur $TARGET..."
nmap --script vuln --script-args mincvss=5.0 -sV -p- "$TARGET" -oX "$OUTPUT_XML" 2>/dev/null

# Générer le JSON avec Python
python3 - <<END > "$OUTPUT_JSON"
import json
import xml.etree.ElementTree as ET
import re

tree = ET.parse("$OUTPUT_XML")
root = tree.getroot()

result = []
for host in root.findall('host'):
    ip_elem = host.find(".//address[@addrtype='ipv4']")
    if ip_elem is not None:
        ip = ip_elem.get('addr')
    else:
        continue

    ports = []
    for port in host.findall('.//port'):
        port_id = port.get('portid')
        service = port.find('service')
        service_name = service.get('name') if service is not None else 'unknown'
        service_product = service.get('product') if service is not None else 'unknown'
        service_version = service.get('version') if service is not None else 'unknown'

        vulnerabilities = []
        for script in port.findall('.//script'):
            script_id = script.get('id')
            output = script.get('output', '')

            cves = re.findall(r'CVE-\d{4}-\d+', output)
            cvss = re.findall(r'CVSS: (\d+\.\d+)', output)
            severity_pattern = re.findall(r'\t(\d+\.\d+)\t', output)

            for i, cve in enumerate(cves):
                severity = cvss[i] if i < len(cvss) else (severity_pattern[i] if i < len(severity_pattern) else 'unknown')
                vulnerabilities.append({
                    'script': script_id,
                    'cve': cve,
                    'severity': severity,
                    'output': output
                })

        ports.append({
            'port': port_id,
            'service': {
                'name': service_name,
                'product': service_product,
                'version': service_version
            },
            'vulnerabilities': vulnerabilities
        })

    result.append({
        'ip': ip,
        'ports': ports
    })

print(json.dumps(result, indent=2))
END
