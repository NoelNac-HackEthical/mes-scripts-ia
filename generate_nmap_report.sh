#!/bin/bash

# Configuration
TARGET="valentine.htb"
PORTS="22,80,443"
OUTPUT_DIR="nmap_reports"
mkdir -p "$OUTPUT_DIR"

# Étape 1: Générer le fichier XML avec Nmap
echo "[*] Lancement du scan Nmap..."
nmap -Pn -p $PORTS $TARGET -sV --script=ssl-heartbleed,http-title,ssl-cert -oX "$OUTPUT_DIR/test.xml" 2>/dev/null

# Étape 2: Extraire les ports et services
echo "[*] Extraction des ports et services..."
xmlstarlet sel -t -m "//host/address[@addrtype='ipv4']" -v "@addr" "$OUTPUT_DIR/test.xml" > "$OUTPUT_DIR/target.txt"
xmlstarlet sel -t -m "//port" -v "@portid" -o ";" -v "service/@name" -o ";" -v "service/@version" -o ";" -v "state/@state" -n "$OUTPUT_DIR/test.xml" | \
awk -F';' 'NF==4 {print "{\"port\":\""$1"\",\"service\":\""$2"\",\"version\":\""$3"\",\"state\":\""$4"\"}"}' > "$OUTPUT_DIR/ports.json"

jq --rawfile target "$OUTPUT_DIR/target.txt" -s '{
  target: ($target | rtrimstr("\n")),
  ports: .
}' "$OUTPUT_DIR/ports.json" > "$OUTPUT_DIR/test_ports.json"

# Étape 3: Extraire les scripts NSE avec Python
echo "[*] Extraction des scripts NSE..."
cat > "$OUTPUT_DIR/extract_scripts.py" << 'EOF'
import xml.etree.ElementTree as ET
import json

tree = ET.parse("nmap_reports/test.xml")
root = tree.getroot()

scripts = []
for port in root.findall(".//port"):
    port_id = port.get("portid")
    for script in port.findall("script"):
        script_id = script.get("id")
        output = script.get("output")
        if output:
            output = output.replace("&apos;", "'").replace("&#xa;", "\n").strip()
        scripts.append({"port": port_id, "id": script_id, "output": output})

with open("nmap_reports/scripts.json", "w") as f:
    json.dump(scripts, f, indent=2)
EOF

python3 "$OUTPUT_DIR/extract_scripts.py"

# Étape 4: Fusionner les résultats
echo "[*] Fusion des résultats..."
jq --slurp '.[0] * {scripts: (.[1] | group_by(.port) | map({port: .[0].port, scripts: map({id: .id, output: .output})}))}' "$OUTPUT_DIR/test_ports.json" "$OUTPUT_DIR/scripts.json" > "$OUTPUT_DIR/results.json"

# Étape 5: Générer le rapport Markdown
echo "[*] Génération du rapport Markdown..."
jq -r '
  "### Rapport Nmap pour " + .target + "\n\n" +
  "**Date**: '"$(date +"%Y-%m-%d %H:%M:%S")"' \n" +
  "**Ports ouverts**\n" +
  (.ports | map(" - " + .port + "/tcp - " + .service + " (" + .version + ") - " + .state) | join("\n")) + "\n\n" +
  "**Scripts NSE**\n" +
  (.scripts | map(
    "#### Port " + .port + "\n" +
    (.scripts | map(
      " - **" + .id + "**:\n" +
      ("   " + (.output | split("\n") | map(select(length > 0)) | join("\n   ")))
    ) | join("\n"))
  ) | join("\n\n"))
' "$OUTPUT_DIR/results.json" > "$OUTPUT_DIR/report.md"

# Étape 6: Afficher le rapport généré
echo "[*] Rapport généré dans $OUTPUT_DIR/report.md"
cat "$OUTPUT_DIR/report.md"

# Étape 7: Envoyer à Ollama (optionnel)
read -p "[?] Voulez-vous envoyer ce rapport à Ollama pour analyse ? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "[*] Envoi à Ollama..."
    curl -s -X POST http://192.168.0.220:11434/api/generate \
      -H "Content-Type: application/json" \
      -d '{
        "model": "mistral:latest",
        "prompt": "Analyse ce rapport Nmap et propose un plan d\'action détaillé. Pour chaque vulnérabilité identifiée, indique : 1. Le port concerné, 2. La vulnérabilité, 3. Le niveau de risque (Critique/Élevé/Moyen/Faible), 4. Une recommandation technique pour la corriger. Voici le rapport: '"$(jq -c . "$OUTPUT_DIR/results.json")"'",
        "stream": false
      }' | jq '.response'
fi
