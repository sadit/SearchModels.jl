# SearchModels

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://sadit.github.io/SearchModels.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://sadit.github.io/SearchModels.jl/dev)
[![Build Status](https://github.com/sadit/SearchModels.jl/workflows/CI/badge.svg)](https://github.com/sadit/SearchModels.jl/actions)
[![Coverage](https://codecov.io/gh/sadit/SearchModels.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/sadit/SearchModels.jl)


Provides a generic method for minimizing model errors using stochastic search, which is often used whenever the problem has no concept of derivative. This kind of problems rely on large exploration of combinatorial spaces based on error function.

SearchModels rely on basic exploration functions that can be specified for many applications.

Due to its generic specification, other kind of optimization problems can be also solved, however, it could be easier and better to use other approaches, like `Optim.jl`.

## Installing

```julia
] add https://github.com/sadit/SearchModels.jl
```


