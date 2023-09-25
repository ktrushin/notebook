#!/bin/sh

set -eu

rsync -avrlt --progress --delete \
  --exclude /ktrushin/Downloads \
  /home/ktrushin /media/ktrushin/ktrushin_backup/home
