#!/bin/sh

IFS=$'\n'

CONTENT=$(grep -v '^#' $1)


if [ ${#CONTENT} -gt 0 ]
then
  echo "          env:" >> $2
fi

for line in $CONTENT; do
  key=$(echo "$line" | cut -d '=' -f 1)
  echo "            - name: $key" >> $2

  value=$(echo "$line" | cut -d '=' -f 2-)
  echo "              value: $value" >> $2
done

unset IFS
