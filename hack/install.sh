#!/usr/bin/env bash

function install() {
 if ! [ -x "$(command -v gum)" ]; then
   go install github.com/charmbracelet/gum@latest
 fi
}