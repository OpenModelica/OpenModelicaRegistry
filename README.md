# OpenModelicaRegistry
A Julia registry for OpenModelica and associate tooling

## How to use
use LocalRegistry.jl 
https://github.com/GunnarFarneback/LocalRegistry.jl

```
(@v1.6) pkg> registry add https://github.com/OpenModelica/OpenModelicaRegistry.git
```

```
using LocalRegistry; register("<package-name>", registry = "OpenModelicaRegistry")
```
