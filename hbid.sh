#!/bin/bash

DOMAIN_LIST=$1
OUTPUT_FILE="hbid.txt"

if [[ -z "$DOMAIN_LIST" ]]; then
    echo "Kullanım: ./check_http_https.sh domain_list.txt"
    exit 1
fi

if [[ ! -f "$DOMAIN_LIST" ]]; then
    echo "Hata: $DOMAIN_LIST dosyası bulunamadı!"
    exit 1
fi

# Önceki çıktıyı temizle
> "$OUTPUT_FILE"

while IFS= read -r domain; do
    if [[ -z "$domain" ]]; then
        continue
    fi

    # Domaini temizle (boşlukları ve hatalı karakterleri kaldır)
    clean_domain=$(echo "$domain" | tr -d '\r' | tr -d '[:space:]')

    echo -e "\nChecking: $clean_domain"

    # HTTPS Testi
    echo "HTTPS test ediliyor: https://$clean_domain"
    https_response=$(curl -I -s --connect-timeout 5 "https://$clean_domain")

    if [[ $? -eq 0 ]]; then
        https_server_header=$(echo "$https_response" | grep -i "^Server:")
        https_powered_header=$(echo "$https_response" | grep -i "^X-Powered-By:")

        if [[ ! -z "$https_server_header" || ! -z "$https_powered_header" ]]; then
            echo "HTTPS Başlıklar:"
            [[ ! -z "$https_server_header" ]] && echo "  $https_server_header"
            [[ ! -z "$https_powered_header" ]] && echo "  $https_powered_header"
            echo "https://$clean_domain - $https_server_header $https_powered_header" >> "$OUTPUT_FILE"
        else
            echo "HTTPS başlıklar bulunamadı."
        fi
    else
        echo "HTTPS başarısız: $clean_domain"
    fi

    # HTTP Testi
    echo "HTTP test ediliyor: http://$clean_domain"
    http_response=$(curl -I -s --connect-timeout 5 "http://$clean_domain")

    if [[ $? -eq 0 ]]; then
        http_server_header=$(echo "$http_response" | grep -i "^Server:")
        http_powered_header=$(echo "$http_response" | grep -i "^X-Powered-By:")

        if [[ ! -z "$http_server_header" || ! -z "$http_powered_header" ]]; then
            echo "HTTP Başlıklar:"
            [[ ! -z "$http_server_header" ]] && echo "  $http_server_header"
            [[ ! -z "$http_powered_header" ]] && echo "  $http_powered_header"
            echo "http://$clean_domain - $http_server_header $http_powered_header" >> "$OUTPUT_FILE"
        else
            echo "HTTP başlıklar bulunamadı."
        fi
    else
        echo "HTTP başarısız: $clean_domain"
    fi

done < "$DOMAIN_LIST"

echo -e "\nTamamlandı! Sonuçlar $OUTPUT_FILE içinde."
