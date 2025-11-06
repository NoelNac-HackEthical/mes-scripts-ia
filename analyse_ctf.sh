#!/bin/bash

# Script final simplifié pour analyse CTF avec Llama3:8b

# Configuration
OUTPUT_FILE="analyse_ctf_resultat.txt"
TEMP_FILE=$(mktemp)

# 1. Préparation des données
echo "🔧 Préparation des données..."
grep -A5 -B2 "VULNERABLE\|CVE\|open\|Apache\|OpenSSH\|ssl" nmap_full.txt > "$TEMP_FILE"

# Vérification
if [ ! -s "$TEMP_FILE" ]; then
  echo "❌ Erreur: Aucune donnée pertinente trouvée dans nmap_full.txt"
  exit 1
fi

# 2. Analyse directe avec prompt simple
echo "🔍 Analyse en cours par Llama3:8b..."
echo "Résultats de l'analyse CTF - Valentine.htb" > "$OUTPUT_FILE"
echo "==========================================" >> "$OUTPUT_FILE"

# Utilisation d'un fichier temporaire pour le prompt
PROMPT_FILE=$(mktemp)
cat > "$PROMPT_FILE" <<EOF
Analyse ce rapport Nmap pour un CTF et identifie TOUTES les vulnérabilités exploitables en français:

$(cat "$TEMP_FILE")

Format de réponse strict:
[Ports Ouverts]
- Port X: Service Version

[Vulnérabilités]
1. [Nom] (CVE-XXXX) - Port X
   * Description: [détails techniques]
   * Commande: [investigation légale]

[Recommandations]
- Outil: commande (objectif)
EOF

# Appel à l'API
curl -s "http://192.168.0.220:11434/api/generate" \
  -H "Content-Type: application/json" \
  -d "{
    \"model\": \"llama3:8b\",
    \"prompt\": \"$(cat "$PROMPT_FILE" | jq -Rs .)\",
    \"stream\": false,
    \"options\": {
      \"temperature\": 0.1
    }
  }" | jq -r '.response' >> "$OUTPUT_FILE" 2>/dev/null

# 3. Affichage des résultats
echo -e "\n📄 Résultats sauvegardés dans $OUTPUT_FILE:"
cat "$OUTPUT_FILE"

# 4. Extraction des vulnérabilités critiques
echo -e "\n💡 Vulnérabilités critiques détectées:"
grep -A3 -B1 "VULNERABLE\|CVE-2014-0160\|Heartbleed" "$OUTPUT_FILE"

# Nettoyage
rm -f "$TEMP_FILE" "$PROMPT_FILE"

# 5. Commandes utiles
echo -e "\n🚀 Commandes d'exploitation recommandées:"
echo "Heartbleed: openssl s_client -connect valentine.htb:443 -tlsextdebug"
echo "Apache: nikto -h http://valentine.htb"
echo "SSH: hydra -l user -P /usr/share/wordlists/rockyou.txt valentine.htb ssh"

