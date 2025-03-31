#!/bin/bash

DOMAIN_LIST=$1
OUTPUT_FILE="headers.txt"

if [[ -z "$DOMAIN_LIST" ]]; then
    echo "Kullanım: ./check_http_headers.sh domain_list.txt"
    exit 1
fi

if [[ ! -f "$DOMAIN_LIST" ]]; then
    echo "Hata: $DOMAIN_LIST dosyası bulunamadı!"
    exit 1
fi

# Önceki çıktıyı temizle
> "$OUTPUT_FILE"

# Başlıkları sırayla test et
declare -A HEADERS
HEADERS["Server"]="Server"
HEADERS["X-Powered-By"]="X-Powered-By"
HEADERS["X-Frame-Options"]="X-Frame-Options"
HEADERS["Access-Control-Allow-Origin"]="Access-Control-Allow-Origin"

for header in "${!HEADERS[@]}"; do
    echo "${HEADERS[$header]}:" >> "$OUTPUT_FILE"

    while IFS= read -r url; do
        if [[ -z "$url" ]]; then
            continue
        fi

        clean_url=$(echo "$url" | tr -d '\r' | tr -d '[:space:]')

        echo -e "\nChecking: $clean_url ($header)"

        response=$(curl -I -s --connect-timeout 5 "$clean_url")

        if [[ $? -eq 0 ]]; then
            header_value=$(echo "$response" | grep -i "^${HEADERS[$header]}:" | cut -d' ' -f2- | tr -d '\r')

            if [[ -n "$header_value" ]]; then
                echo "$clean_url - $header_value"
                echo "$clean_url - $header_value" >> "$OUTPUT_FILE"
            fi
        else
            echo "Erişim başarısız: $clean_url"
        fi

    done < "$DOMAIN_LIST"

    echo "" >> "$OUTPUT_FILE"
done

echo -e "\nTamamlandı! Sonuçlar $OUTPUT_FILE içinde."
