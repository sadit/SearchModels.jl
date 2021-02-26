```@meta
CurrentModule = SearchModels
```

# Example: Solving a polynomial regresión

This is a toy example that help us to select and fit a polynomial model for an input data. You may realize that threre are better ways to solve this example, but here we want to show how to use it succinctly. `SearchModels` is indended on problems without a definition of derivatives, and in particular, on solving model selection for different kinds of structures.

The approach of `SearchModels` consists on modeling our solution space defining a struct type and three related methods: `random_configuration`, `combine_configuration`, and `mutate_configuration`. We also may need to define `config_type` and `eltype`. In particular, `config_type` needs to be defined here to put the type as the polynomial's degree to be able to distinguish among different degrees. The `eltype` should be defined to use concrete types internally on several queues.

```@example Poly
using SearchModels, Random
import SearchModels: random_configuration, combine_configurations, mutate_configuration, config_type

Random.seed!(0) # fixing seed

struct PolyModelSpace <: AbstractSolutionSpace
    degree
end

const PolyModel = Vector{Float64}

Base.eltype(::PolyModelSpace) = PolyModel
config_type(c::PolyModel) = length(c)  # polynomial degree

```

The precise definitions of the exploration methods may differ, but they are used to randomly sample the solution space, combine two configurations into a single one, and mutate one based (or not) on the space definition. Please notice that a polynomial is simply represented by its coefficients.

```@example Poly
function random_configuration(space::PolyModelSpace)
    randn(rand(space.degree) + 1)
end

function combine_configurations(a::PolyModel, b::PolyModel)
    [(a[i] + b[i]) / 2.0 for i in eachindex(a)]
end

function mutate_configuration(space::PolyModelSpace, c::PolyModel, iter)
    step = 1.0 + 1 / (1 + iter)
    [SearchModels.scale(c[i], s=step) for i in eachindex(c)]
end

```

 
## Evaluation of a polynomial
For illustrative purposes, we need to generate synthetic example, firstly, we need to define how to evaluate a polynomial.

```@example Poly
function poly(coeff, x)::Float64
    s = coeff[1]
    @inbounds @simd for i in 2:length(coeff)
        m = coeff[i]
        s += coeff[i] * x^(i-1)
    end

    s
end
```

## A synthetic example

We will create a dataset with a random polynomial, here we also define the error function

```@example Poly
function create_model_1(n)
    X = collect(-10:0.1:10)
    coeff = rand(n + 1)
    X, [poly(coeff, x) for x in X], coeff
end


X, y, coeff__ = create_model_1(4)

function error_function(c)::Float64
    s = zero(Float64)
    @inbounds @simd for i in eachindex(X)
        m = poly(c, X[i]) - y[i]
        s += m * m
    end

    s / length(X)
end
```


## Search process

Even when our target polynomial's degree is 4, we allow polynomials of different degrees, the search procedure must minimize the error and this includes selecting the best degree and its coefficients.

```@example Poly
space = PolyModelSpace(2:5)
B = search_models(space, error_function, 300,
    maxpopulation=64,
    bsize=64,
    mutbsize=32,
    crossbsize=32,
    tol=0.0,
    maxiters=300,
    verbose=true
)

length(B)
```

Here, we indicte that the search process must `error_function` as error (it receives a configuration), starts sampling `300` random solutions generated with `random_configuration`. Note that the search will store atmost `maxpopulation` individuals, those achieving the lower errors. If not specified `maxpopulation` is set to the number of initial population.
The iterative process consists on explore the solution space using combination and mutation, using top `bsize` items. The combination and mutation generate `crossbsize` and `mutbisize` new configurations at each iteration (using top `bsize` configurations). The search is stoppend when two iterations do not improve atleast by `tol` the error (of the worst error in the entire population) or the number of maximum allowed iterations are reached. 

```@example Poly
println(stderr, "target polynomial: ", coeff__)
for b in B[1:10]
    println(stderr, "score=$(b.second), coeffs: $(b.first)")
end
```
