#!/bin/sh

set -eu

rsync -avrlt --progress --delete  /home/ktrushin \
    /media/ktrushin/ktrushin_backup/home
