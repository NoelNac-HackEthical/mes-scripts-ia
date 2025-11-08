#!/usr/bin/env python3
import xml.etree.ElementTree as ET
import re
import sys

def parse_nmap_xml(xml_file):
    try:
        tree = ET.parse(xml_file)
        root = tree.getroot()
    except ET.ParseError:
        # Si le XML est mal formé, on utilise un parser plus tolérant
        from lxml import etree
        parser = etree.XMLParser(recover=True)
        tree = etree.parse(xml_file, parser=parser)
        root = tree.getroot()

    vulnerabilities = []
    for host in root.findall('.//host'):
        ip = host.find(".//address[@addrtype='ipv4']").get('addr') if host.find(".//address[@addrtype='ipv4']") is not None else "unknown"
        for port in host.findall('.//port'):
            port_id = port.get('portid')
            service_name = port.find('.//service').get('name') if port.find('.//service') is not None else "unknown"
            for script in port.findall('.//script'):
                if script.get('id') == 'vulners':
                    output = script.get('output', '')
                    # Extraire les CVE et CVSS avec des regex
                    cves = re.findall(r'(CVE-\d{4}-\d+)', output)
                    cvss_scores = re.findall(r'CVSS: (\d+\.\d+)', output)
                    exploits = re.findall(r'is_exploit">(true|false)', output)

                    for i, cve in enumerate(cves):
                        cvss = cvss_scores[i] if i < len(cvss_scores) else "unknown"
                        exploit = exploits[i] if i < len(exploits) else "false"
                        vulnerabilities.append({
                            'ip': ip,
                            'port': port_id,
                            'service': service_name,
                            'cve': cve,
                            'cvss': cvss,
                            'exploit': exploit
                        })
    return vulnerabilities

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python3 parse_nmap_xml.py <nmap_xml_file>")
        sys.exit(1)

    xml_file = sys.argv[1]
    vulnerabilities = parse_nmap_xml(xml_file)

    # Afficher les vulnérabilités triées par CVSS (descendant)
    sorted_vulns = sorted(vulnerabilities, key=lambda x: float(x['cvss']) if x['cvss'] != "unknown" else 0, reverse=True)
    for vuln in sorted_vulns:
        print(f"IP: {vuln['ip']} | Port: {vuln['port']} | Service: {vuln['service']} | CVE: {vuln['cve']} | CVSS: {vuln['cvss']} | Exploit: {vuln['exploit']}")
