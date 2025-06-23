# parabox-editor
Missing features:
- floatinspace (use special effect 9 instead)
- epsilon
- other floor types

Levels with references to fillwithwalls blocks will not load correctly.

# Building
Use zig 0.14.x  
`zig build --release=safe -p . --prefix-exe-dir .`
