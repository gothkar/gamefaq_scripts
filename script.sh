#!/bin/bash
set -eu
IFS=$'\n\t'
#set -vx

######################################################################
# Script to download all FAQs from gamefaqs.com
######################################################################

# INSTRUCTIONS
#   1. Run this script, it will ask you for the name of a system.
#      The system must be a valid one from the file `system_list.txt`
#      ...which comes from https://gamefaqs.gamespot.com/games/systems
#
#   2. The script will fetch pages from gamefaqs.gamespot.com and save
#      FAQ text files in the `output` directory.
#
# WARNING
#   - Be aware that Gamespot monitors HTTP requests, and will block
#     your IP if you go over their threshold (which will happen within
#     1-2 days with the default configuration of 2 seconds wait time).
#   - It should be possible to adjust the WAIT_TIME variable below
#     to a higher number in order to keep below their threshold.
#   - Luckily the script halts when it gets blocked and can't download
#     files anymore, which gives you a chance to visit the site in a
#     browser and get it unblocked before your IP is permanently banned.
#
# CREDITS
# - prograc, for initial idea and implementation
# - randmr, for some improvements (March 2022)
#
# REFERENCES
# - https://www.reddit.com/r/DataHoarder/comments/ftsdbs/gamespot_txt_gamefaqs_full_archive_32320/
# - https://github.com/gothkar/gamefaq_scripts
######################################################################

HOST="https://gamefaqs.gamespot.com"

WAIT_TIME=2  # Number of seconds to wait after each HTTP request
LIVE=true    # false will prevent live http calls
CLEANUP=true # false will prevent cleanup of temporary files
VERBOSE=true # true will display useful debug output

WD=".work"         ; mkdir -p $WD         # keep temporary files tidy in a Working Directory
OUTPUT_DIR="output"; mkdir -p $OUTPUT_DIR # keep output files in one place

SYSTEM_LIST="system_list.txt"
GAME_LINKS="game_links.txt"
FAQ_LINKS="faq_links.txt"

# Fetch list of systems
if [[ -e $SYSTEM_LIST ]]
then
    $VERBOSE && echo "Using local $SYSTEM_LIST"
else
    $LIVE && rm -f $WD/systems.html && wget -O $WD/systems.html "$HOST/games/systems"
    sleep $WAIT_TIME
    cat $WD/systems.html | grep 'href' | sed 's#.\+href="/\([^"]\+\)".\+#\1#' | grep -Ev '^(user|games|a/|new|http)' | grep -v '<' | sort | uniq > $SYSTEM_LIST
    $VERBOSE && echo "Parsed systems: " $(cat $SYSTEM_LIST | wc -l)
fi

# Ask user for system

# Loop over systems
#cat $SYSTEM_LIST | head -1 | while read line # TODO: replace this
#do
    line=pinball

    system=$line
    $VERBOSE && echo "System: $system"

    # Fetch first page of games
    $LIVE && rm -f $WD/games0.html && wget -O $WD/games0.html $HOST/"$system"/category/999-all
    sleep $WAIT_TIME

    # Extract number of pages of games
    maxpage=$(cat $WD/games0.html | grep ' of [[:digit:]]\+</li>' | sed 's/.*\([[:digit:]]\+\).\+/\1/')
    if [[ -z "$maxpage" ]]; then maxpage=0; fi
    $VERBOSE && echo "Number of pages: $maxpage"

    # Extract game links from first page
    mv $GAME_LINKS $WD/$GAME_LINKS.old
    cat $WD/games0.html | grep "/$system/" | grep "Guides" | grep "<td class=" | awk '{$1=$1};1' | cut -c28- | sed 's/faqs.*/faqs/' | awk '$0="'$HOST'"$0' >> $GAME_LINKS
    $VERBOSE && echo "Parsed game links from page 0: " $(cat $GAME_LINKS | wc -l) "(" $(tail -1 $GAME_LINKS) ")"

    # If there is more than one page
    if [[ "$maxpage" > 0 ]]
    then
        # Loop over all the other pages, collecting all game links
        for (( i=1; i<="$maxpage"; i++ ))
        do
            $LIVE && rm -f $WD/games"$i".html && wget -O $WD/games"$i".html $HOST/"$system"/category/999-all?page="$i"
            sleep $WAIT_TIME
            cat $WD/games"$i".html | grep "/$system/" | grep "Guides" | grep "<td class=" | awk '{$1=$1};1' | cut -c28- | sed 's/faqs.*/faqs/' | awk '$0="'$HOST'"$0' >> $GAME_LINKS
            $VERBOSE && echo "Parsed game links from page $i: " $(cat $GAME_LINKS | wc -l) "(" $(tail -1 $GAME_LINKS) ")"
        done
    else
        $VERBOSE && echo "There are no more pages"
    fi

    # Deduplicate game links
    mv $GAME_LINKS $WD/$GAME_LINKS.raw
    cat $WD/$GAME_LINKS.raw | sort | uniq > $GAME_LINKS

    # Loop over each game, collecting all FAQs
    mv $FAQ_LINKS $WD/$FAQ_LINKS.old
    cat $GAME_LINKS | while read line
    do
        $LIVE && rm -f $WD/game.html && wget -O $WD/game.html "$line"
        sleep $WAIT_TIME
        cat $WD/game.html | grep "<li data-url=" | sed -n '/<div class/q;p' | awk '{$1=$1};1' | cut -c15- | sed 's/..$//' | awk '$0="'$HOST'"$0' >> $FAQ_LINKS
        $VERBOSE && echo "Parsed FAQ links from $line: " $(cat $FAQ_LINKS | wc -l) "(" $(tail -1 $FAQ_LINKS) ")" 
    done

    # Deduplicate FAQ links
    mv $FAQ_LINKS $WD/$FAQ_LINKS.raw
    cat $WD/$FAQ_LINKS.raw | sort | uniq > $FAQ_LINKS

    # Loop over each FAQ, and download it
    # Notes:
    # - Example URL: https://gamefaqs.gamespot.com/3do/314778-the-11th-hour/faqs/6221
    # - Example saved filename: output/3do/314778-the-11th-hour_6221.txt
    # - The system (3do) is just a label; The same FAQ content may be found labelled with each system for which it is valid.
    #   ...this means if you scrape multiple systems, the same content may be downloaded more than once
    # - The first number (314778) uniquely identifies the game.
    # - The second number (6221) uniquely identifies the FAQ document.
    cat $FAQ_LINKS | while read line
    do
        $LIVE && rm -f $WD/faq.html && wget -O $WD/faq.html "$line"
        sleep $WAIT_TIME
        output_filename=$(echo "$line" | sed 's#'$HOST'/[^/]\+/##' | sed 's#faqs/##' | sed 's#/#_#g')".txt"
        output_path="$OUTPUT_DIR/$system"
        mkdir -p $output_path
        cat $WD/faq.html | sed '/faqtext/,$!d' | sed '1d' | sed '/\/pre/,$d' >> "$output_path/$output_filename"
        $VERBOSE & echo "Saved FAQ: $output_path/$output_filename"
    done

    # Clean up
    $CLEANUP && rm -r $WD
    $CLEANUP && rm -f $SYSTEMS_LIST $GAME_LINKS $FAQ_LINKS
#done
