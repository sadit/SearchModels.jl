# This file is a part of SearchModels.jl
# License is Apache 2.0: https://www.apache.org/licenses/LICENSE-2.0.txt

using Test

using SearchModels

struct PolyModelSpace <: AbstractConfigSpace
    degree::Vector{Int}
end

struct PolyModel{T<:AbstractVector} <: AbstractConfig
    coeff::T
end

Base.eltype(::PolyModelSpace) = PolyModel
SearchModels.config_type(c::PolyModel) = length(c.coeff)  # polynomial degree

function SearchModels.random_configuration(space::PolyModelSpace)
    PolyModel(rand(rand(space.degree) + 1))
end

function SearchModels.combine_configurations(a::PolyModel, b::PolyModel)
    PolyModel([(a.coeff[i] + b.coeff[i]) / 2.0 for i in eachindex(a.coeff)])
end

function SearchModels.mutate_configuration(space::PolyModelSpace, c::PolyModel, iter)
    pert(x) = if rand() < 0.3
        rand() < 0.5 ? x * 1.1 : x / 1.1
    else
        x
    end

    PolyModel([pert(c.coeff[i]) for i in eachindex(c.coeff)])
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
            m = poly(c.coeff, X[i]) - y[i]
            s += m * m
        end

        s / length(X)
    end

    space = PolyModelSpace([3, 4, 5, 6])
    B = search_models(space, error_function, 300,
        bsize=64,
        mutbsize=32,
        crossbsize=32,
        tol=0.0,
        maxiters=300,
        verbose=true
    )

    println("===== PolyModel -- poly: $(coeff__)")
    for (i, p) in enumerate(B[1:15])
        println(stderr, i => p)
    end
end
