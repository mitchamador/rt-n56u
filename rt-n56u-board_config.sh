#!/bin/bash

function validate_board(){
  if [[ `wget -S --spider $1  2>&1 | grep 'HTTP/1.1 200 OK'` ]]; then echo "true"; fi
}

name=$1
namel=$(echo "$name" | tr '[:upper:]' '[:lower:]')

if [ -z $name ]; then
  echo "usage: $0 (MI-R3G|NEWIFI-D2)" && exit
fi

result=$(validate_board https://github.com/mitchamador/rt-n56u/raw/master/$name)

if [ -z $result ]; then
  echo "no board $name found" && exit
fi

if [ -d ./configs/boards/$name ]; then
  rm -rf ./configs/boards/$name
fi

mkdir -p ./configs/boards/$name
wget -q -O ./configs/boards/$name/board.h https://github.com/mitchamador/rt-n56u/raw/master/$name/board.h
wget -q -O ./configs/boards/$name/board.mk https://github.com/mitchamador/rt-n56u/raw/master/$name/board.mk
wget -q -O ./configs/boards/$name/kernel-3.4.x.config https://github.com/mitchamador/rt-n56u/raw/master/$name/kernel-3.4.x.config
ln -sf ../uclibc-mipsel.config ./configs/boards/$name/libc.config
wget -q -O ./configs/templates/$namel.config https://github.com/mitchamador/rt-n56u/raw/master/$name/$namel.config
cp ./configs/templates/$namel.config .config

echo "edit .config if needed"
