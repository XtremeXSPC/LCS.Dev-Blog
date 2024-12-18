#!/usr/bin/env zsh

typeset -A mio_array

mio_array=(
  nome "Mario"
  cognome "Rossi"
)

for chiave valore in "${(@kv)mio_array}"; do
  echo "$chiave -> $valore"
done
