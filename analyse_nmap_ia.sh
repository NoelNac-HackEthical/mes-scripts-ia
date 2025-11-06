#!/bin/bash

# analyse_nmap_final.sh - Version ultra-simplifiée et corrigée
# Utilisation: ./analyse_nmap_final.sh [fichier_nmap]

# Configuration basique
TARGET_FILE="${1:-nmap_full.txt}"
OUTPUT_FILE="analyse_result_$(date +%Y%m%d_%H%M%S).txt"

# 1. Vérification minimale
if [ ! -f "$TARGET_FILE" ]; then
    echo "❌ Erreur: Fichier $TARGET_FILE introuvable"
    exit 1
fi

# 2. Préparation des données
echo "📄 Préparation des données..."
grep -A3 -B1 "VULNERABLE\|CVE\|open" "$TARGET_FILE" > "$OUTPUT_FILE"

# 3. Analyse manuelle des vulnérabilités (solution de secours toujours disponible)
echo -e "\n=== Vulnérabilités détectées ===" >> "$OUTPUT_FILE"
grep -A3 "VULNERABLE\|CVE" "$TARGET_FILE" >> "$OUTPUT_FILE" 2>/dev/null

echo -e "\n=== Ports ouverts ===" >> "$OUTPUT_FILE"
grep -E "^[0-9]+/tcp.*open" "$TARGET_FILE" >> "$OUTPUT_FILE" 2>/dev/null

# 4. Analyse par IA (version ultra-simple)
echo -e "\n=== Analyse IA ===" >> "$OUTPUT_FILE"

# On découpe le fichier en petits morceaux pour éviter les problèmes
SPLIT_FILE=$(mktemp)
split -l 20 "$OUTPUT_FILE" "$SPLIT_FILE"

for part in "${SPLIT_FILE}"*; do
    # Utilisation d'un fichier temporaire pour le prompt
    PROMPT_FILE=$(mktemp)
    echo "Analyse cette partie de rapport Nmap en français et identifie les vulnérabilités exploitables avec leurs commandes d'investigation:

$(cat "$part")

Format de réponse:
1. Vulnérabilité (CVE-XXXX) - Port X
   - Description: [détails]
   - Commande: [investigation]

Si aucune vulnérabilité n'est détectée, réponds: 'Aucune vulnérabilité détectée dans cette partie'" > "$PROMPT_FILE"

    # Appel à l'API avec un prompt simple
    response=$(curl -s "http://192.168.0.220:11434/api/generate" \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"llama3:8b\",
            \"prompt\": \"$(cat "$PROMPT_FILE" | jq -Rs .)\",
            \"stream\": false,
            \"options\": {
                \"temperature\": 0.1
            }
        }" 2>/dev/null)

    # Affichage des résultats
    echo "$response" | jq -r '.response' 2>/dev/null >> "$OUTPUT_FILE"
    echo "---" >> "$OUTPUT_FILE"

    # Nettoyage
    rm -f "$PROMPT_FILE"
done

# 5. Commandes générales
echo -e "\n=== Commandes d'investigation ===" >> "$OUTPUT_FILE"
echo "Heartbleed: openssl s_client -connect <IP>:443 -tlsextdebug" >> "$OUTPUT_FILE"
echo "Web: nikto -h http://<IP>" >> "$OUTPUT_FILE"
echo "SSH: hydra -l user -P /usr/share/wordlists/rockyou.txt <IP> ssh" >> "$OUTPUT_FILE"

# 6. Affichage des résultats
echo "✅ Analyse terminée. Résultats sauvegardés dans $OUTPUT_FILE"
cat "$OUTPUT_FILE"

# Nettoyage
rm -f "${SPLIT_FILE}"*
