#!/bin/bash
set -eu
IFS=$'\n\t'

#set -vx # Uncomment for debug

# Script to download all FAQs from gamefaqs.com

HOST="https://gamefaqs.gamespot.com"

WAIT_TIME=2
LIVE=true # false will prevent live http calls

WD=".work"      && mkdir -p $WD     # keep temporary files tidy in a Working Directory
OUTPUT="output" && mkdir -p $OUTPUT # keep output files in one place

# Fetch list of systems
$LIVE && wget -O $WD/systems.html "$HOST/games/systems"
sleep $WAIT_TIME
cat $WD/systems.html | grep 'href' | sed 's#.\+href="/\([^"]\+\)".\+#\1#' | grep -Ev '^(user|games|a/|new|http)' | grep -v '<' | sort | uniq > systems_list.txt

# Loop over systems
cat systems_list.txt | head -1 | while read line
do
    system=$line

    # Fetch first page of games
    $LIVE && wget -O $WD/games0.html $HOST/"$system"/category/999-all
    sleep $WAIT_TIME

    # Extract number of pages of games
    maxpage=$(cat $WD/games0.html | grep "<option value" | awk -F= 'BEGIN { max = -1 } { if ($3 > max) { max = $3; line = $0 } } END { print $line }' | grep -o '".*"' | sed 's/"//g')
    echo maxpage = '$maxpage'

    # Extract game links from first page
    cat $WD/games0.html | grep "/$system/" | grep "Guides" | grep "<td class=" | awk '{$1=$1};1' | cut -c28- | sed 's/faqs.*/faqs/' | awk '$0="'$HOST'"$0' >> game_links.txt

    maxpage=1 # DEBUG
    # Loop over each page, collecting all game links
    for (( i=1; i<="$maxpage"; i++ ))
    do
        $LIVE && wget -O $WD/games"$i".html $HOST/"$system"/category/999-all?page="$i"
        sleep $WAIT_TIME
        cat $WD/games"$i".html | grep "/$system/" | grep "Guides" | grep "<td class=" | awk '{$1=$1};1' | cut -c28- | sed 's/faqs.*/faqs/' | awk '$0="'$HOST'"$0' >> game_links.txt
    done

    # Loop over each game, collecting all FAQs
    cat game_links.txt | head -1 | while read line
    do
        $LIVE && wget -O $WD/game.html "$line"
        sleep $WAIT_TIME
        cat $WD/game.html | grep "<li data-url=" | sed -n '/<div class/q;p' | awk '{$1=$1};1' | cut -c15- | sed 's/..$//' | awk '$0="'$HOST'"$0' >> faq_links.txt
    done

    # Loop over each FAQ, download it
    # Notes:
    # - Example URL: https://gamefaqs.gamespot.com/3do/314778-the-11th-hour/faqs/6221
    # - The system (3do) is just a label; The same FAQ content may be found labelled with each system for which it is valid.
    #   ...this means there will be duplicate content downloaded.
    #   ...this is tolerated for now, only because we need to maintain the system labels somehow.
    # - The first number (314778) uniquely identifies the game.
    # - The second number (6221) uniquely identifies the FAQ document.
    cat faq_links.txt | head -1 | while read line
    do
        $LIVE && wget -O $WD/faq.html "$line"
        sleep $WAIT_TIME
        name=$(echo "$line" | sed 's#'$HOST'/##' | sed 's#faqs/##' | sed 's#/#\_#g')
        cat $WD/faq.html | sed '/faqtext/,$!d' | sed '1d' | sed '/\/pre/,$d' >> "$OUTPUT/$name".txt
    done

    # Clean up
    rm -r .working
done
