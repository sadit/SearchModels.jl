```@meta
CurrentModule = SearchModels
```

# SearchModels


Provides a generic method for minimizing model errors using stochastic search, which is often used whenever the problem has no concept of derivative. This kind of problems rely on large exploration of combinatorial spaces based on error function.

`SearchModels` rely on basic exploration functions that can be specified for many applications.

Due to its generic specification, other kind of optimization problems can be also solved, however, it could be easier and better to use other approaches.

## Using SearchModels

The code idea is to describe a configuration space (solution space) for some model, that controls how the space is explored. The model is evaluated using an error function, and the resulting errors are used to navigate the solution space.

For this purpose SearchModels expect that some methods to work. As described below.

- All configuration spaces should be an specialization of the abstract type `AbstractSolutionSpace`.
- `random_configuration(space::AbstractSolutionSpace)`: Creates a random configuration sampling the given space
- `combine_configurations(a, L::AbstractVector)`: Combines the a solution 'a' with the list of solutions `L` (an array of pairs `solution => error`). By default it samples `L` for a compatible solution with  `a` and calls [`combine_configurations(c1, c2)`](@ref). A compatible solution is defined to share the same `config_type(a)`.
- `combine_configurations(c1, c2)`: Combines two configurations into a single one; most applications should override this method.
- `mutate_configuration(space::AbstractSolutionSpace, config, iter::Integer)`: Mutates `config` (a small perturbation, commonly following the `space` description). The `iter` value contains the iteration counter, it could be used to adjust the perturbation level.
- `mutate_configuration(space::AbstractVector, c, iter)`: Dispatch of the applicable mutation function whenever space defines heterogeneous types.
- `config_type(::T)` describes the type of T, it defaults to `Base.typename(T)` but it could be any other value that makes sense for the application.
- `eltype(::AbstractSolutionSpace)`: Defines what kind of objects are expected to be sampled from the solution space; it requires an specialization of `eltype` (i.e., to add `import Base: eltype`).

For complex enough configurations (solutions) you may need to define specialize `hash`, and `isequal` since the search process uses it to keep a track of the evalauted configurations.

Most of the work is made in [`search_models`](@ref) function. 

