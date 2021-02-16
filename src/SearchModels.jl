# This file is a part of SearchModels.jl
# License is Apache 2.0: https://www.apache.org/licenses/LICENSE-2.0.txt

module SearchModels

export AbstractConfigSpace, AbstractConfig, search_models, random_configuration, combine_configurations
using Distributed, Random, StatsBase
abstract type AbstractConfigSpace end
abstract type AbstractConfig end

Base.hash(a::AbstractConfig) = hash(repr(a))
Base.isequal(a::AbstractConfig, b::AbstractConfig) = isequal(repr(a), repr(b))
#function Base.eltype(space) => kind of configuration

#function random_configuration(space::AbstractConfigSpace) end
#function combine_configurations(a::AbstractConfig, b::AbstractConfig) end

function random_configuration end
function combine_configurations end

function combine_configurations(a::T, L::AbstractVector) where T
    # L is a vector of pairs config => score
    # L should be shuffled before combining
    type_ = Base.typename(T)

    for p in L
        c = p.first
        if Base.typename(typeof(c)) == type_
            return combine_configurations(a, c)
        end
    end

    a
end

function search_models(
        configspace::AbstractConfigSpace,
        error_function::Function,  # receives only the configuration to be population
        initialpopulation=32;
        maxpopulation=initialpopulation,
        bsize=initialpopulation,
        mutbsize=4,
        crossbsize=4,
        maxiters=300,
        tol=0.001,
        verbose=true,
        distributed=false
    )
    
    population = Pair{AbstractConfig,Float64}[]
    evalqueue = AbstractConfig[]
    observed = Set{AbstractConfig}()

    for i in 1:initialpopulation
        c = random_configuration(configspace)
        if !(c in observed)
            push!(evalqueue, c)
            push!(observed, c)
        end
    end
    
    prev = 0.0
    iter = 0
    config_and_scores = Pair[]

    while iter <= maxiters
        iter += 1

        verbose && println(stderr, "SearchModels> ==== search params iter=$iter, tol=$tol, initialpopulation=$initialpopulation, maxpopulation=$maxpopulation, bsize=$bsize, mutbsize=$mutbsize, crossbsize=$crossbsize, prev=$prev")
        empty!(config_and_scores)
        while length(evalqueue) > 0
            c = pop!(evalqueue)
            perf = if distributed
                @spawn error_function(c)
            else
                error_function(c)
            end

            push!(config_and_scores, c => perf)
        end
        
        # fetching all results
        for s in config_and_scores
            push!(population, s.first => fetch(s.second))
        end

        ## verbose && println(stderr, "SearchModels> *** iteration $iter finished")

        sort!(population, by=x->x.second)
        if maxpopulation < length(population)
            resize!(population, maxpopulation)
        end

        iter >= maxiters && return population

        curr = population[1].second
        if abs(curr - prev) <= tol     
            verbose && println(stderr, "SearchModels> *** stopping on iteration $iter due to a possible convergence ($curr ≃ $prev, tol: $tol)")
            return population
        end

        prev = curr
        ## verbose && println(stderr, "SearchModels> *** generating extra indivuals bsize=$bsize, mutbsize=$mutbsize, crossbsize=$crossbsize")

        L = @view population[1:min(bsize, length(population))]
        for i in 1:mutbsize
            c = rand(L)
            conf = combine_configurations(c.first, [random_configuration(configspace) => 0.0, c])
            if !(conf in observed)
                push!(evalqueue, conf)
                push!(observed, conf)
            end
        end

        for i in 1:crossbsize
            shuffle!(L) # the way this procedure is designed is to support heterogeneous options
            i = rand(1:length(L))
            L[end], L[i] = L[end], L[i]  
            conf = combine_configurations(L[end].first, L)
            if !(conf in observed)
                push!(evalqueue, conf)
                push!(observed, conf)
            end
        end

        verbose && println(stderr, "SearchModels> *** configurations population=$(length(population)), queue=$(length(evalqueue)), observed=$(length(observed))")    
    end

    sort!(population, by=x->x.second)
end

end
