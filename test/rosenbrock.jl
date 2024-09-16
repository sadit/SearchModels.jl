# This file is a part of SearchModels.jl

using Test

using SearchModels
import SearchModels: combine, mutate

mutable struct RosenbrockSpace <: AbstractSolutionSpace
    xrange
    yrange
end

RosenbrockSpace() = RosenbrockSpace(-3.0:0.1:10.0, -10.0:0.1:3.0)

const RoseParams = Tuple{Float64, Float64}

Base.eltype(::RosenbrockSpace) = RoseParams

function Base.rand(space::RosenbrockSpace)
    rand(space.xrange), rand(space.yrange)
end

function combine(a::RoseParams, b::RoseParams)
    if rand() < 0.5
        a[1], b[2]
    else
        (a[1] + b[1])/2, (a[2] + b[2])/2
    end
end

function mutate(space::RosenbrockSpace, c::RoseParams, iter)
    if rand() < 0.5
        c[1], rand(space.yrange)
    else
        rand(space.xrange), c[2]
    end
end

function rosenbrock(x)::Float64
    (1-x[1])^2+100*(x[2]-x[1]^2)^2
end

@testset "SearchModels.jl" begin
    function inspect_population(space, params, population)
        xmin = ymin = typemax(Float64)
        xmax = ymax = typemin(Float64)

        for p in population
            c = p[1]
            xmin = min(xmin, c[1])
            ymin = min(ymin, c[2])
            xmax = max(xmax, c[1])
            ymax = max(ymax, c[2])
        end

        st = 0.1
        e = 10
        space.xrange = xmin-st*e:st:xmax+st*e
        space.yrange = ymin-st*e:st:ymax+st*e
    end

    println("===== RoseParams without inspect_population")

    space = RosenbrockSpace()
    params = SearchParams(
        bsize=32,
        mutbsize=100,
        crossbsize=100,
        maxiters=300,
        verbose=true
    )

    B = search_models(rosenbrock, space, 1000, params)

    for (i, p) in enumerate(B[1:15])
        println(stderr, i => p)
    end

    println("===== RoseParams using inspect_population")

    space = RosenbrockSpace()

    B = search_models(rosenbrock, space, 1000, params, inspect_population=inspect_population)

    for (i, p) in enumerate(B[1:15])
        println(stderr, i => p)
    end
end
