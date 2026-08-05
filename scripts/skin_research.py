#!/usr/bin/env python3
"""
Skin Care Research - تحقیقات پوست با PubMed API
"""
import json
import urllib.request
import urllib.parse
import sys

def search_pubmed(query, max_results=5):
    """جستجو در PubMed"""
    base_url = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/"
    
    # جستجوی شناسه‌ها
    search_url = base_url + "esearch.fcgi?" + urllib.parse.urlencode({
        "db": "pubmed",
        "term": query,
        "retmode": "json",
        "retmax": max_results
    })
    
    with urllib.request.urlopen(search_url) as response:
        data = json.loads(response.read())
        ids = data.get("esearchresult", {}).get("idlist", [])
    
    if not ids:
        return "مقاله‌ای پیدا نشد!"
    
    # خواندن جزئیات
    summary_url = base_url + "esummary.fcgi?" + urllib.parse.urlencode({
        "db": "pubmed",
        "id": ",".join(ids),
        "retmode": "json"
    })
    
    with urllib.request.urlopen(summary_url) as response:
        data = json.loads(response.read())
    
    results = []
    for uid in ids:
        article = data.get("result", {}).get(uid, {})
        title = article.get("title", "بدون عنوان")
        pub_date = article.get("pubdate", "نامشخص")
        authors = article.get("authors", [{}])
        first_author = authors[0].get("name", "نامشخص") if authors else "نامشخص"
        
        results.append({
            "title": title,
            "date": pub_date,
            "author": first_author,
            "url": f"https://pubmed.ncbi.nlm.nih.gov/{uid}/"
        })
    
    return results

if __name__ == "__main__":
    query = sys.argv[1] if len(sys.argv) > 1 else "skincare dermatology"
    results = search_pubmed(query)
    
    if isinstance(results, list):
        for i, r in enumerate(results, 1):
            print(f"{i}. {r['title']}")
            print(f"   Author: {r['author']}")
            print(f"   Date: {r['date']}")
            print(f"   URL: {r['url']}")
            print()
    else:
        print(results)
