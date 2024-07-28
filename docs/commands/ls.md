# npm-ls

### List installed packages

### Synopsis
```sh
lpm ls <package-spec>

alias: list
```

### Description
This command will print to stdout all the versions of packages that are installed, as well as their dependencies when `--all` is specified, in a tree structure.

### Configuration
`json`
    - Default: false
    - Type: Boolean
    Whether or not to output JSON data, rather than the normal output.

`depth`
    - Default: `Infinity` if `--all` is set, otherwise 1
    - Type: nil or number
The depth to go when recursing packages for `lpm ls`.

If not set, `lpm ls` will show only the immediate dependencies of the root project. If `--all` is set, then npm will show all dependencies by default.
