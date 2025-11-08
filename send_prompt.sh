#!/bin/bash

PROMPT_FILE="/mnt/kvm-md0/HTB/valentine-ai1/prompt_llama.txt"
OUTPUT_FILE="/mnt/kvm-md0/HTB/valentine-ai1/vulnerabilities_extracted.json"
OLLAMA_URL="http://192.168.0.220:11434/api/generate"

# Nettoyage du prompt : supprime les --- et les backticks, échappe les guillemets
CLEAN_PROMPT=$(sed -e 's/---//g' -e 's/```//g' -e 's/"/\\"/g' "\$PROMPT_FILE" | tr -d '\r')

# Construction du JSON valide
REQUEST_JSON=\$(jq -n --arg prompt "\$CLEAN_PROMPT" '{
  model: "mistral:7b-instruct",
  prompt: \$prompt,
  stream: false,
  options: {
    temperature: 0.0,
    num_predict: 4096
  }
}')

echo "🔍 Envoi du prompt nettoyé à Llama3.8B..."

response=\$(curl -s -X POST "\$OLLAMA_URL" \
  -H "Content-Type: application/json" \
  -d "\$REQUEST_JSON" 2>&1)

if echo "\$response" | jq -e '.response' >/dev/null 2>&1; then
    echo "\$response" | jq -r '.response' > "\$OUTPUT_FILE"
    echo "✅ Succès ! Résultat enregistré dans \$OUTPUT_FILE"
    echo "--- Extrait du résultat ---"
    jq . "\$OUTPUT_FILE"
else
    echo "❌ Erreur lors de la requête :"
    echo "\$response" | jq .
    exit 1
fi
