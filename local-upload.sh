#!/usr/bin/env bash

rsync -av --exclude=.git --exclude=ogg --exclude=freqmap --delete-excluded --delete ./ www.isid.ac.in:public_html/gitabitan/


