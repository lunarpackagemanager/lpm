---
title: lpm-init
section: 1
description: Create a package.toml file
---

### Synopsis

```bash
lpm init

alias: create
```

### Description

`lpm init` can be used to set up a new package.

### Examples

Generate a plain old package.toml using legacy init:

```bash
$ mkdir my-lpm-pkg && cd my-lpm-pkg
$ git init
$ lpm init
```

Generate it without having it ask any questions:

```bash
$ lpm init -y
```
### Configuration

#### `yes`

* Default: null

* Type: nil or boolean

Automatically answer "yes" to any prompts that lpm might print on the
command line.
