#!/bin/bash
system="pinball"
wget https://gamefaqs.gamespot.com/"$system"/category/999-all
sleep 2
cat 999-all | grep "/$system/" | grep "Guides" | grep "<td class=" | awk '{$1=$1};1' | cut -c28- | sed 's/faqs.*/faqs/' | awk '$0="https://gamefaqs.gamespot.com"$0' >> game_links.txt
maxpage=$(cat 999-all | grep "<option value" | awk -F= 'BEGIN { max = -1 } { if ($3 > max) { max = $3; line = $0 } } END { print $line }' | grep -o '".*"' | sed 's/"//g')
rm 999-all
for (( i=1; i<="$maxpage"; i++ ))
  do
    wget https://gamefaqs.gamespot.com/"$system"/category/999-all?page="$i"
    cat 999-all@page="$i" | grep "/$system/" | grep "Guides" | grep "<td class=" | awk '{$1=$1};1' | cut -c28- | sed 's/faqs.*/faqs/' | awk '$0="https://gamefaqs.gamespot.com"$0' >> game_links.txt
    rm  999-all@page="$i"
    sleep 2
  done
cat game_links.txt | while read line
do
   wget "$line"
   cat faqs | grep "<li data-url=" | sed -n '/<div class/q;p' | awk '{$1=$1};1' | cut -c15- | sed 's/..$//' | awk '$0="https://gamefaqs.gamespot.com"$0' >> faq_links.txt
   rm faqs
   sleep 2
done
cat faq_links.txt | while read line
do
   wget -O faqs "$line"
   name=$(echo "$line" | cut -c30- | sed 's#/#\_#g' | cut -c2-)
   cat faqs | sed '/faqtext/,$!d' | sed '1d' | sed '/\/pre/,$d' >> "$name".txt
   rm faqs
   sleep 2
done
