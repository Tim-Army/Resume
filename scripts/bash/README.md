# Bash automation

This directory is the canonical location for all repository Bash automation.

## Current build script

- `create-tim-fox-resume.sh` — Generates the master and targeted Markdown resumes, validates bullet punctuation, and migrates shell scripts from `~/Downloads` into this directory.

## Policy

- Do not run permanent repository scripts from `~/Downloads`.
- Move `.sh` and `.bash` files into this directory before committing them.
- Run `bash -n scripts/bash/<script>.sh` before execution.
- Make committed scripts executable with `chmod +x`.
- Do not store credentials, tokens, private keys, or controlled information in scripts.
