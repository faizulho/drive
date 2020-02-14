# Fission Drive

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://github.com/fission-suite/drive/blob/master/LICENSE)
[![Built by FISSION](https://img.shields.io/badge/⌘-Built_by_FISSION-purple.svg)](https://fission.codes)
[![Discord](https://img.shields.io/discord/478735028319158273.svg)](https://discord.gg/zAQBDEq)
[![Discourse](https://img.shields.io/discourse/https/talk.fission.codes/topics)](https://talk.fission.codes)

The Drive application that lives on your `fission.name` domain.

# Quickstart

```shell
# 🍱
# 1. Install programming languages
#    (or install manually, see .tool-versions)
#    (https://asdf-vm.com)
# Install asdf https://asdf-vm.com/#/core-manage-asdf-vm
# `asdf plugin-add elm`
# `asdf plugin-add nodejs` and `bash ~/.asdf/plugins/nodejs/bin/import-release-team-keyring`
asdf install

# 2. Install https://github.com/casey/just
# 3. Install https://github.com/watchexec/watchexec -- `brew install watchexec` or download from Github releases tab
# 4. Install https://github.com/pnpm/pnpm -- if you already have npm installed, `npm add -g pnpm`

# 5. Install dependencies
just install-deps

# 🛠
# Build, watch & start server
just
```
