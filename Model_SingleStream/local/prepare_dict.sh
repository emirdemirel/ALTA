#!/bin/bash

#adapted from ami and chime5 dict preparation script
#Author: Gerardo Roa

# Begin configuration section.
words=5000
# End configuration section

echo "$0 $@"  # Print the command line for logging

if [ -f path.sh ]; then . ./path.sh; fi
. utils/parse_options.sh || exit 1;

# The parts of the output of this that will be needed are
# [in data/local/dict/ ]
# lexicon.txt
# extra_questions.txt
# nonsilence_phones.txt
# optional_silence.txt
# silence_phones.txt

mkdir -p data



dir=data/local/dict
mkdir -p $dir

cp -r conf/dict/* $dir/

echo "$0: Preparing files in $dir"
# Silence phones
for w in SIL SPN; do echo $w; done > $dir/silence_phones.txt
echo SIL > $dir/optional_silence.txt



# Add prons for laughter, noise, oov
for w in `grep -v sil $dir/silence_phones.txt`; do
  echo "[$w] $w"
done | cat - $dir/lexicon_raw.txt > $dir/lexicon2_raw.txt || exit 1;


# we keep all words from the cmudict in the lexicon
# might reduce OOV rate on dev and test
cat $dir/lexicon2_raw.txt  \
   <( echo "MM M"
      echo "<UNK> SPN" \
    )  | sed 's/[\t ]/\t/' | tr a-z A-Z  | sort -u > $dir/iv_lexicon.txt


cat data/local/corpus.txt  | \
  awk '{for (n=1;n<=NF;n++){ count[$n]++; } } END { for(n in count) { print count[n], n; }}' | \
  sort -nr > $dir/word_counts_b


# Select the N numbers of words increasingly in order to select all the words with same count

vocab_size=0
start_line=3  #  first two are <s> and </s>
touch $dir/word_list

while [ "$vocab_size" -le "$words" ]; do
    current_count=`sed "${start_line}q;d" $dir/word_counts_b | awk '{print $1}'`
    cat $dir/word_counts_b | grep "^$current_count " | awk '{print $2}' >> $dir/word_list
    vocab_size=`cat $dir/word_list | wc -l`
    start_line=$((vocab_size + 1 ))
done


head -n $vocab_size $dir/word_counts_b > $dir/word_counts
sort -u $dir/word_list > $dir/word_list_sorted


awk '{print $1}' $dir/iv_lexicon.txt | \
  perl -e '($word_counts)=@ARGV;
   open(W, "<$word_counts")||die "opening word-counts $word_counts";
   while(<STDIN>) { chop; $seen{$_}=1; }
   while(<W>) {
     ($c,$w) = split;
     if (!defined $seen{$w}) { print; }
   } ' $dir/word_counts > $dir/oov_counts.txt


echo "*Highest-count OOVs (including fragments) are:"
head -n 10 $dir/oov_counts.txt
echo "*Highest-count OOVs (excluding fragments) are:"
grep -v -E '^-|-$' $dir/oov_counts.txt | head -n 10 || true
tail -n +4 $dir/oov_counts.txt | awk '{print $2}' > $dir/oov_words.txt

echo "Extend lexicon using a G2P model."
./steps/dict/apply_g2p_phonetisaurus.sh --nbest 3 \
    data/local/dict/oov_words.txt conf/g2p data/local/dict/
cut -d$'\t' -f1,3 data/local/dict/lexicon.lex > data/local/dict/lex
sed -e 's/\t/ /g' data/local/dict/lex > data/local/dict/oov_lexicon.txt
cat data/local/dict/oov_lexicon.txt data/local/dict/lexicon_raw.txt | sort -u > data/local/dict/lexicon.txt
sed -e 's/ / 1.0\t/' data/local/dict/lexicon.txt > data/local/dict/lexiconp.txt



echo "<UNK> SPN" >> $dir/lexicon.txt

## The next section is again just for debug purposes
## to show words for which the G2P failed
rm -f $dir/lexiconp.txt 2>null; # can confuse later script if this exists.
awk '{print $1}' $dir/lexicon.txt | \
  perl -e '($word_counts)=@ARGV;
   open(W, "<$word_counts")||die "opening word-counts $word_counts";
   while(<STDIN>) { chop; $seen{$_}=1; }
   while(<W>) {
     ($c,$w) = split;
     if (!defined $seen{$w}) { print; }
   } ' $dir/word_counts > $dir/oov_counts.g2p.txt

echo "*Highest-count OOVs (including fragments) after G2P are:"
head -n 10 $dir/oov_counts.g2p.txt

utils/validate_dict_dir.pl $dir
exit 0;
