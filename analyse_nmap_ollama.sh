#!/bin/bash

# ============================
# analyse_nmap_ollama.sh
# ============================
# Usage :
#   ./analyse_nmap_ollama.sh             → analyse mes_scans/aggressive_vuln_scan.txt (modèle par défaut)
#   ./analyse_nmap_ollama.sh fichier.txt → analyse un fichier spécifique
#   ./analyse_nmap_ollama.sh mistral-small3.2:24b → fichier par défaut + modèle précisé
#   ./analyse_nmap_ollama.sh fichier.txt mistral-small3.2:24b → fichier + modèle
# ============================

DEFAULT_SCAN_FILE="mes_scans/aggressive_vuln_scan.txt"
DEFAULT_MODEL="llama3.1:8b"
OLLAMA_HOST="${OLLAMA_HOST:-192.168.0.220:11434}"

# ----------------------------
# 1) Déterminer si l'argument 1 est un modèle ou un fichier
# ----------------------------

if [ -z "$1" ]; then
    # Aucun argument → fichier par défaut
    SCAN_FILE="$DEFAULT_SCAN_FILE"
    MODEL="$DEFAULT_MODEL"
    echo "ℹ️ Aucun argument fourni : utilisation du scan par défaut + modèle par défaut"

elif [[ "$1" =~ : ]] || [[ "$1" =~ ^mistral ]] || [[ "$1" =~ ^llama ]] || [[ "$1" =~ ^qwen ]]; then
    # Si l'argument 1 ressemble à un modèle (mistral:* / llama:* / qwen:*)
    MODEL="$1"
    SCAN_FILE="$DEFAULT_SCAN_FILE"
    echo "ℹ️ Modèle détecté : $MODEL"
    echo "ℹ️ Utilisation du fichier par défaut : $SCAN_FILE"

else
    # Sinon → argument 1 = fichier
    SCAN_FILE="$1"
    MODEL="${2:-$DEFAULT_MODEL}"
fi

# Vérifier que le fichier existe
if [ ! -f "$SCAN_FILE" ]; then
    echo "❌ Fichier introuvable : $SCAN_FILE"
    exit 1
fi

echo "📄 Fichier analysé : $SCAN_FILE"
echo "🧠 Modèle utilisé : $MODEL"
echo "🔗 Ollama : http://$OLLAMA_HOST/api/generate"
echo

# ----------------------------
# 2) Prompt Markdown CTF-réaliste
# ----------------------------

INSTRUCTIONS="Tu es un assistant spécialisé en CTF (HackTheBox, TryHackMe).
Analyse le scan Nmap suivant et réponds en français, en Markdown clair et réaliste pour un CTF.

Réponse attendue :

## 1. Vulnérabilités réellement exploitables en CTF
- Liste uniquement les vulnérabilités crédibles.
- Ne propose jamais de brute force SSH sauf indice clair.
- Pour chaque vuln exploitable :
  - Nom / CVE
  - Port / service
  - Pourquoi c'est exploitable en CTF
  - Idée d'exploitation réaliste.

## 2. Faux positifs et bruit
- Liste ce qui est non pertinent pour un CTF :
  - erreurs NSE
  - vulnérabilités SSL cryptographiques complexes
  - bruits ou résultats non exploitables
- Expliquer en une phrase pourquoi c'est du bruit.

## 3. Résumé de la surface d'attaque
Présente un tableau Markdown :

| Port | Service / Version | Infos utiles | Idées de tests CTF |
|------|------------------|--------------|---------------------|

- Basé strictement sur les données du scan.
- Aucune invention."

# ----------------------------
# 3) Construction du JSON pour l'API Ollama
# ----------------------------

REQUEST_JSON=$(jq -n \
  --arg model "$MODEL" \
  --arg instruct "$INSTRUCTIONS" \
  --rawfile scan "$SCAN_FILE" \
  '{model:$model, prompt: ($instruct + "\n\nScan Nmap :\n\n" + $scan), stream:false}')

# ----------------------------
# 4) Envoi à l’IA Ollama
# ----------------------------

curl -s "http://$OLLAMA_HOST/api/generate" \
  -H "Content-Type: application/json" \
  -d "$REQUEST_JSON" | jq -r '.response'
