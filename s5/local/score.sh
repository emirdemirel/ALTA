#!/bin/bash

echo "scoring starts"

KALDI_ROOT='/homes/ed308/kaldi'

./steps/scoring/score_kaldi_wer.sh "$@"
