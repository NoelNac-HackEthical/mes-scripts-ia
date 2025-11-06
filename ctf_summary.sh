#!/bin/bash

# 1. Extraire l'essentiel pour le CTF
echo "🔍 [CTF Summary] Target: valentine.htb"
echo "----------------------------------------"

# 2. Ports ouverts + services vulnérables
echo "[+] Ports Ouverts (Services Vulnérables *):"
grep -E "^[0-9]+/tcp.*open" nmap_full.txt | awk '
{
  split($1, p, "/"); port=p[1]; service=$3; version="";
  for (i=4; i<=NF; i++) if ($i !~ /open|filtered|closed/) version=version " "$i;
  gsub(/^[ \t]+|[ \t]+$/, "", version);

  # Marquer les versions vulnérables connues
  vulnerable=0;
  if (version ~ /Apache.*2\.2\.22/ || version ~ /OpenSSH.*5\.9/) vulnerable=1;
  if (version ~ /vsftpd.*2\.3\.4/ || version ~ /Samba.*3\.0/) vulnerable=1;

  printf " - %s/tcp  %s %s", port, service, version;
  if (vulnerable) printf " *";
  printf "\n";
}'
echo ""

# 3. Vulnérabilités exploitables (CVE + exploits)
echo "[!] Vulnérabilités Exploitables:"
grep -A2 -B2 -E "VULNERABLE|CVE-[0-9]{4}-[0-9]+|EXPLOIT" 6-nse-vuln.txt | awk '
/^[0-9]+\/tcp/ {port=$1; split(port, p, "/"); port=p[1]}
/VULNERABLE|CVE|EXPLOIT/ {
  gsub(/^\|_ /, "", $0);
  gsub(/^[ \t]+|[ \t]+$/, "", $0);
  if ($0 ~ /CVE-[0-9]{4}-[0-9]+/) {
    print "💥 [CRITICAL] Port " port ": " $0;
    print "    → Recherche: searchsploit " $0;
    print "    → Metasploit: msfconsole -q -x \"use exploit/...; set RHOSTS valentine.htb; set RPORT " port "; exploit\"";
  }
  else if ($0 ~ /VULNERABLE/) {
    print "⚠️  [HIGH]    Port " port ": " $0;
  }
}'
echo ""

# 4. Scripts NSE intéressants (pour investigation manuelle)
echo "[?] Scripts NSE Utile (à investiguer):"
grep -E "^\|_" nmap_full.txt | grep -v "Couldn't find\|No vulnerabilities\|not vulnerable" | awk -F'|_' '
{
  gsub(/^[ \t]+|[ \t]+$/, "", $2);
  if ($2 ~ /http-|ssl-|smb-|ftp-/) {
    print " - " $1 ": " $2;
  }
}'
echo ""

# 5. Résumé des actions recommandées
echo "[>] Résumé des Actions CTF:"
echo "  1. Vérifier les ports marqués * (versions vulnérables connues)"
echo "  2. Rechercher les exploits pour les CVE identifiées"
echo "  3. Investiguer les scripts NSE listés ci-dessus"
echo "  4. Tester les services web (port 80/443) avec:"
echo "     - nikto -h http://valentine.htb"
echo "     - gobuster dir -u http://valentine.htb -w /usr/share/wordlists/dirb/common.txt"
echo "     - sqlmap -u http://valentine.htb/..."
