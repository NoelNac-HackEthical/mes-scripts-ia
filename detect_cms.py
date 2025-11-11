#!/usr/bin/env python3
import requests
import re
from urllib.parse import urljoin

TARGET = "http://sea.htb"

def check_signatures():
    signatures = {
        "WordPress": ["wp-content", "wp-includes", "wp-json"],
        "Drupal": ["sites/default", "CHANGELOG.txt", "core/misc/drupal.js"],
        "Joomla": ["administrator", "media/system/js", "templates/system"],
        "Magento": ["app/etc", "skin/", "var/"],
        "PrestaShop": ["modules/", "themes/", "img/cms"],
        "OctoberCMS": ["themes/", "storage/cms"],
    }

    print("[+] Recherche de signatures CMS...")
    for cms, paths in signatures.items():
        for path in paths:
            url = urljoin(TARGET, path)
            try:
                r = requests.head(url, timeout=5, allow_redirects=True)
                if r.status_code == 200:
                    print(f"🔍 {cms} possible : {url} (code {r.status_code})")
            except requests.RequestException:
                continue

def check_headers():
    print("\n[+] Analyse des en-têtes HTTP...")
    try:
        r = requests.get(TARGET, timeout=5)
        headers = r.headers
        for key, value in headers.items():
            if "server" in key.lower() or "x-" in key.lower() or "generator" in key.lower():
                print(f"{key}: {value}")
    except requests.RequestException as e:
        print(f"Erreur : {e}")

def check_robots():
    print("\n[+] Analyse de robots.txt...")
    try:
        r = requests.get(urljoin(TARGET, "robots.txt"), timeout=5)
        if r.status_code == 200:
            print(r.text)
        else:
            print("robots.txt introuvable.")
    except requests.RequestException as e:
        print(f"Erreur : {e}")

if __name__ == "__main__":
    check_signatures()
    check_headers()
    check_robots()
