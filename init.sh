#!/bin/sh

set -eu

echo "==> Checking required tools..."

if ! command -v git >/dev/null 2>&1; then
  echo "Error: git is not installed. Please install git first."
  exit 1
fi

if ! command -v brew >/dev/null 2>&1; then
  echo "Error: Homebrew is not installed."
  echo "Install Homebrew first: https://brew.sh/"
  exit 1
fi

if ! command -v node >/dev/null 2>&1; then
  echo "Error: node is not installed. Please install Node.js first."
  exit 1
fi

if ! command -v npm >/dev/null 2>&1; then
  echo "Error: npm is not installed. Please install npm first."
  exit 1
fi

echo "==> Updating submodules..."
git submodule update --init --recursive

echo "==> Checking Hugo..."
if ! command -v hugo >/dev/null 2>&1; then
  echo "Hugo not found. Installing with Homebrew..."
  brew install hugo
else
  echo "Hugo already installed: $(hugo version | head -n 1)"
fi

echo "==> Installing npm dependencies..."
npm install

echo "==> Starting Hugo server..."
hugo server -D
