using SearchModels
using Test

struct PolyModelSpace <: AbstractConfigSpace
    degree::Vector{Int}
end

struct PolyModel <: AbstractConfig
    coeff::Vector{Float64}
end

Base.eltype(::PolyModelSpace) = PolyModel

function SearchModels.random_configuration(space::PolyModelSpace)
    PolyModel(rand(rand(space.degree) + 1))
end

function SearchModels.combine_configurations(a::PolyModel, b::PolyModel)
    PolyModel([(a.coeff[i] + b.coeff[i]) / 2.0 for i in eachindex(a.coeff)])
end

function SearchModels.combine_configurations(a::PolyModel, L::AbstractVector)
    i = findfirst(p -> length(p.first.coeff) == length(a.coeff), L)
    combine_configurations(a, L[i].first)
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

    space = PolyModelSpace([1,2,3,4])
    B = search_models(space, error_function, 1000,
        bsize=16,
        mutbsize=16,
        crossbsize=16,
        tol=-1.0,
        maxiters=300,
        verbose=true,
        distributed=false
    )

    println("===== PolyModel -- poly: $(coeff__)")
    for (i, p) in enumerate(B[1:15])
        @info i p
    end
end
