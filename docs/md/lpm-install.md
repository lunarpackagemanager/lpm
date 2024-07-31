---
title: lpm-install
description: Install a package
section: 1
---

### Synopsis

```bash
lpm install [package-spec...]

aliases: i, add
```

### Description

This command installs a package and any packages that it depends on.

### Flags

* `-D, --save-dev`: Package will appear in your `devDependencies`.

### Algorithm

Given a `package{dep}` structure: `A{B,C}, B{C}, C{D}`,
the npm install algorithm produces:

```bash
A
+-- B
+-- C
+-- D
```

That is, the dependency from B to C is satisfied by the fact that A already
caused C to be installed at a higher level. D is still installed at the top
level because nothing conflicts with it.

For `A{B,C}, B{C,D@1}, C{D@2}`, this algorithm produces:

```bash
A
+-- B
+-- C
   `-- D@2
+-- D@1
```

Because B's D@1 will be installed in the top-level, C now has to install
D@2 privately for itself. This algorithm is deterministic, but different
trees may be produced if two dependencies are requested for installation in
a different order.
