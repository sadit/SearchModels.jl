# This file is a part of SearchModels.jl
# License is Apache 2.0: https://www.apache.org/licenses/LICENSE-2.0.txt

using Test

using SearchModels
import SearchModels: combine, mutate, config_type

struct PolyModelSpace <: AbstractSolutionSpace
    degree
end

const PolyModel = Vector{Float64}

Base.eltype(::PolyModelSpace) = PolyModel
config_type(c::PolyModel) = length(c)  # polynomial degree

Base.rand(space::PolyModelSpace) = randn(rand(space.degree) + 1)

function combine(a::PolyModel, b::PolyModel)
    [(a[i] + b[i]) / 2.0 for i in eachindex(a)]
end

function mutate(space::PolyModelSpace, c::PolyModel, iter)
    step = 1.0 + 1 / (1 + iter)
    [SearchModels.scale(c[i], s=step) for i in eachindex(c)]
end

function poly(coeff, x)::Float64
    s = coeff[1]
    @inbounds @simd for i in 2:length(coeff)
        m = coeff[i]
        s += coeff[i] * x^(i-1)
    end

    s
end

function create_model_1(n)
    X = collect(-10:0.1:10)
    coeff = rand(n + 1)
    X, [poly(coeff, x) for x in X], coeff
end

@testset "SearchModels.jl" begin
    X, y, coeff__ = create_model_1(4)

    function error_function(c)::Float64
        s = zero(Float64)
        @inbounds @simd for i in eachindex(X)
            m = poly(c, X[i]) - y[i]
            s += m * m
        end

        s / length(X)
    end

    space = PolyModelSpace(2:5)
    B = search_models(space, error_function, 300,
        bsize=64,
        mutbsize=32,
        crossbsize=32,
        tol=0.0,
        maxiters=100,
        verbose=true
    )

    println("===== PolyModel -- poly: $(coeff__)")
    for (i, p) in enumerate(B[1:15])
        println(stderr, i => p)
    end
end
