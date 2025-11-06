#!/bin/bash

# nmap_vuln_extractor_final.sh - Extrait REELLEMENT les vulnérabilités du rapport
# Utilisation: ./nmap_vuln_extractor_final.sh [fichier_nmap]

INPUT_FILE="${1:-nmap_full.txt}"
TARGET_IP=$(grep -oP '\d+\.\d+\.\d+\.\d+' "$INPUT_FILE" | head -n 1)
OUTPUT_FILE="vulnerabilities_$(date +%Y%m%d_%H%M%S).txt"

# Fonction pour extraire les vulnérabilités de manière intelligente
extract_real_vulnerabilities() {
    echo "🔍 Extraction REELLE des vulnérabilités depuis $INPUT_FILE"
    echo "Cible: $TARGET_IP" > "$OUTPUT_FILE"
    echo "Date: $(date)" >> "$OUTPUT_FILE"
    echo "==========================================" >> "$OUTPUT_FILE"

    # 1. Ports ouverts (uniques)
    echo -e "\n[+] Ports ouverts:" >> "$OUTPUT_FILE"
    grep -E "^[0-9]+/tcp.*open" "$INPUT_FILE" | awk '{print $1 "/" $2 " " $3}' | sort -u >> "$OUTPUT_FILE"

    # 2. Services et versions (uniques)
    echo -e "\n[+] Services et versions:" >> "$OUTPUT_FILE"
    grep -A1 "open.*[0-9]+/tcp" "$INPUT_FILE" | grep -E "open|_" | grep -v "^$" | awk '{$1=""; print $0}' | sort -u >> "$OUTPUT_FILE"

    # 3. Extraction REELLE des vulnérabilités avec leurs CVE
    echo -e "\n[!] Vulnérabilités détectées:" >> "$OUTPUT_FILE"

    # Extraction des sections de vulnérabilités
    awk '
    /VULNERABLE:/ {
        vuln_name = "Vulnérabilité non nommée";
        cve = "Non spécifié";
        port = "Non spécifié";
        risk = "Non spécifié";
        in_vuln = 1;
        print "\n--- Nouvelle vulnérabilité détectée ---";
    }
    /State: VULNERABLE/ { risk = "Élevé"; }
    /Risk factor: (High|Medium|Low)/ { risk = $3; }
    /CVE-/ { cve = $0; gsub(/.*CVE-|[^0-9].*/, "", cve); cve = "CVE-" cve; }
    /Port [0-9]+/ { port = $2; }
    /^\[/ { if (in_vuln) { in_vuln = 0; } }
    in_vuln {
        if ($0 ~ /^[[:space:]]*[^[:space:]]/) {
            if ($0 !~ /VULNERABLE:|State:|Risk factor:|IDs:|Port/) {
                desc = desc $0 "\n";
            }
        }
    }
    /^$/ {
        if (in_vuln) {
            print "Nom: " vuln_name;
            print "CVE: " cve;
            print "Port: " port;
            print "Risque: " risk;
            print "Description:";
            print desc;
            in_vuln = 0;
        }
    }
    ' "$INPUT_FILE" | sed 's/^|/  /' >> "$OUTPUT_FILE"

    # Extraction des CVE directs
    echo -e "\n[+] CVE détectés:" >> "$OUTPUT_FILE"
    grep -oP "CVE-\d+-\d+" "$INPUT_FILE" | sort -u | while read -r cve; do
        echo "  - $cve: https://cve.mitre.org/cgi-bin/cvename.cgi?name=$cve" >> "$OUTPUT_FILE"
    done

    # 4. Répertoires intéressants
    echo -e "\n[+] Répertoires web intéressants:" >> "$OUTPUT_FILE"
    grep "/dev/" "$INPUT_FILE" | head -n 1 | sed 's/^|/  /' >> "$OUTPUT_FILE"

    # 5. Commandes d'exploitation
    echo -e "\n[>] Commandes recommandées:" >> "$OUTPUT_FILE"
    echo "  Heartbleed: openssl s_client -connect $TARGET_IP:443 -tlsextdebug" >> "$OUTPUT_FILE"
    echo "  POODLE: nmap --script ssl-poodle -p 443 $TARGET_IP" >> "$OUTPUT_FILE"
    echo "  Web: gobuster dir -u http://$TARGET_IP/dev/ -w /usr/share/wordlists/dirb/common.txt" >> "$OUTPUT_FILE"

    echo "✅ Extraction terminée. Résultats dans $OUTPUT_FILE"
    cat "$OUTPUT_FILE"
}

extract_real_vulnerabilities
