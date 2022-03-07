#!/bin/bash

# Script to download all text files from gamefaqs.com

# TODO:
# - s/999-all/games_page.html/g
# - wget -O games_page${i}.html http://...etc...page=$i
# - s/"$i"/${i}/

WAIT_TIME=2

mkdir -p .working # to keep temporary files tidy

# Fetch list of systems
wget -O systems.html 'https://gamefaqs.gamespot.com/games/systems'
cat systems.html | grep 'href' | sed 's/.\+href="\([^"]\+\)".\+/\1/' | grep -Ev '^(/user|/games|/a/|/new|http)' | sort | uniq > systems_list.txt
mv systems.html .working

# Loop over systems
cat systems_list.txt | head -1 | while read system
do

    # Fetch list of games
    wget -O games0.html https://gamefaqs.gamespot.com/"$system"/category/999-all
    sleep $WAIT_TIME

    # Extract number of pages of games
    maxpage=$(cat games0.html | grep "<option value" | awk -F= 'BEGIN { max = -1 } { if ($3 > max) { max = $3; line = $0 } } END { print $line }' | grep -o '".*"' | sed 's/"//g')
    mv games0.html .working

    # Extract game links from first page
    cat games0.html | grep "/$system/" | grep "Guides" | grep "<td class=" | awk '{$1=$1};1' | cut -c28- | sed 's/faqs.*/faqs/' | awk '$0="https://gamefaqs.gamespot.com"$0' >> game_links.txt

    maxpage=1 # DEBUG
    # Loop over each page, collecting all game links
    for (( i=1; i<="$maxpage"; i++ ))
    do
        wget https://gamefaqs.gamespot.com/"$system"/category/999-all?page="$i"
        cat 999-all@page="$i" | grep "/$system/" | grep "Guides" | grep "<td class=" | awk '{$1=$1};1' | cut -c28- | sed 's/faqs.*/faqs/' | awk '$0="https://gamefaqs.gamespot.com"$0' >> game_links.txt
        rm  999-all@page="$i"
        sleep $WAIT_TIME
    done

    # Loop over each game, collecting all FAQs
    cat game_links.txt | head -1 | while read line
    do
        wget "$line"
        cat faqs | grep "<li data-url=" | sed -n '/<div class/q;p' | awk '{$1=$1};1' | cut -c15- | sed 's/..$//' | awk '$0="https://gamefaqs.gamespot.com"$0' >> faq_links.txt
        rm faqs
        sleep $WAIT_TIME
    done

    # Download each FAQ
    cat faq_links.txt | head -1 | while read line
    do
        wget -O faqs "$line"
        name=$(echo "$line" | cut -c30- | sed 's#/#\_#g' | cut -c2-)
        cat faqs | sed '/faqtext/,$!d' | sed '1d' | sed '/\/pre/,$d' >> "$name".txt
        rm faqs
        sleep $WAIT_TIME
    done

done
