# This file is a part of SearchModels.jl
# License is Apache 2.0: https://www.apache.org/licenses/LICENSE-2.0.txt

module SearchModels

export AbstractSolutionSpace, config_type, search_models, random_configuration, combine_configurations, mutate_configuration
using Distributed, Random, StatsBase

abstract type AbstractSolutionSpace end

"""
    scale(x, s=1.1; p1=0.5, p2=0.5, lower=typemin(T), upper=typemax(T))

With probability `p1` ``x``` is scaled by `s`; if ``x`` is going to be scaled, then with probability `p2` ``x`` is growth (or reduced otherwise).
Minimum and maximum values can be specified.
"""
function scale(x::T, s=1.1; p1=0.5, p2=0.5, lower=typemin(T), upper=typemax(T))::T where {T<:Real}
    if rand() < p1
        min(upper, max(lower, rand() < p2 ? x * s : x / s))
    else
        x
    end
end

"""
    translate(x::T, s=2; p1=0.5, p2=0.5, lower=typemin(T), upper=typemax(T)) where {T<:Real}

With probability `p1` ``x``` is modified; if ``x`` is modified, then with probability `p2` returns ``x+s`` or ``x-s`` otherwise.
Minimum and maximum values can be specified.
"""
function translate(x::T, s=2; p1=0.5, p2=0.5, lower=typemin(T), upper=typemax(T))::T where {T<:Real}
    if rand() < p1
        min(upper, max(lower, rand() < p2 ? x + s : x - s))
    else
        x
    end
end

"""
    config_type(::T)

Config type identifier, it may or not be a type
"""
config_type(::T) where T = Base.typename(T)

#function random_configuration(space::AbstractSolutionSpace) end
#function combine_configurations(a, b) end

"""
    random_configuration(space::AbstractSolutionSpace)

Creates a random configuration sampling the given space
"""
function random_configuration end

"""
    combine_configurations(c1, c2)

Combines two configurations into a single one.

"""
function combine_configurations end

"""
    combine_configurations(a, L::AbstractVector)

Combines the first configuration (1st argument) with some of the given list of pairs (config => score),
The `a` config is always at the end of `L` and also `L` is always shuffled.
If you are in doubt, use the higher level interface `combine_configurations(c1, c2)`.
"""
function combine_configurations(a::T, L::AbstractVector) where T
    # L is a vector of pairs config => score
    # L should be shuffled before combining
    t_ = config_type(a)

    for p in L
        c = p.first
        if config_type(c) == t_
            return combine_configurations(a, c)
        end
    end

    a
end


"""
    mutate_configuration(space::AbstractSolutionSpace, config, iter::Integer)
    mutate_configuration(space::AbstractVector, c, iter)

Mutates configuration. If space is a list of spaces, then the proper space is determined.
"""
function mutate_configuration(space::AbstractSolutionSpace, c, iter)
    combine_configurations(c, random_configuration(space))
end

function mutate_configuration(space::AbstractVector, c, iter)
    for s in space
        if c isa eltype(s)
            return mutate_configuration(s, c, iter)
        end
    end
end


"""
    evaluate_queue(error_function, evalqueue, population, config_and_errors, parallel)

Evaluates queue of using error_function; the resulting `config => errors` pairs are pushed into the population.

"""
function evaluate_queue(error_function::Function, evalqueue, population, config_and_errors, parallel)
    while length(evalqueue) > 0
        c = pop!(evalqueue)
        if parallel == :distributed
            perf = Distributed.@spawn error_function(c)
            push!(config_and_errors, c => perf)
        elseif parallel == :threads
            perf = Threads.@spawn error_function(c)
            push!(config_and_errors, c => perf)
        elseif parallel == :none
            push!(population, c => error_function(c))
        else
            error("Unknown parallel option")
        end
    end
    
    # fetching all results
    if parallel !== :none
        for s in config_and_errors
            push!(population, s.first => fetch(s.second))
        end
    end
    ## verbose && println(stderr, "SearchModels> *** iteration $iter finished")

    sort!(population, by=x->x.second)
end

"""
    push_config!(accept_config, conf, evalqueue, observed)

Pushes `conf` into the evaluation queue. It checks if was already observed and if it is accepted by the `accept_config` predicate.
"""
function push_config!(accept_config, conf, evalqueue, observed)
    if !(conf in observed) && accept_config(conf)
        push!(evalqueue, conf)
        push!(observed, conf)
    end
end

"""
    search_models(
        space::AbstractSolutionSpace,
        error_function::Function,  # receives only the configuration to be population
        initialpopulation=32;
        maxpopulation=initialpopulation,
        accept_config::Function=config->true,
        inspect_population::Function=(space, population) -> nothing,
        bsize=initialpopulation,
        mutbsize=4,
        crossbsize=4,
        maxiters=300,
        tol=0.001,
        verbose=true,
        parallel=:none # :none, :threads, :distributed
    )

Explores the search space trying to minimize the given error function. The procedure consists on an iterative stochastic method
based on an evolutionary algorithm. It is starts with `initialpopulation` configurations, evaluate them mutate and cross them;
it selects at most `maxpopulation` configurations at any iteration (best ones).
- `space`: Search space definition
- `error_function`: the function to minimize (receives the configuration as argument)
- `initialpopulation`: initial number of configurations to conform the population
- `maxpopulation`: the maximum number of configurations to be kept at each iteration (based on its minimum error)
- `accept_config`: an alternative way to deny some configuration to be evaluated (receives the configuration as argument)
- `inspect_population`: observes the population after evaluating a beam of solutions
- `bsize`: number of best items to be used for mutation and crossing procedures
- `mutbsize`: number of new configurations per iteration from a mutation procedure
- `crossbsize`: number of new configurations per iteration from a crossing procedure
- `maxiters`: maximum iterations of the search procedure
- `tol`: stop search tolerance to population errors on the best `maxpopulation` configurations; negative values will force to evaluate `maxiters`
- `verbose`: controls if the verbosity of the search iterations
- `parallel`: controls if the search is made with some kind of parallel strategy (only used for evaluation errors). Valid values are:
  - `:none`: there is no parallelization, the default value
  - `:threads`: evaluates error functions using threads
  - `:distributed`: evaluates error functions using a distributed environment (using the available workers)
"""
function search_models(
        space::AbstractSolutionSpace,
        error_function::Function,  # receives only the configuration to be population
        initialpopulation=32;
        maxpopulation=initialpopulation,
        accept_config::Function=config -> true,
        inspect_population::Function=(space, population) -> nothing,
        bsize=initialpopulation,
        mutbsize=16,
        crossbsize=16,
        maxiters=300,
        tol=0.001,
        verbose=true,
        parallel=:none # :none, :threads, :distributed
    )
    
    ConfigType = eltype(space)
    population = Pair{ConfigType,Float64}[]
    evalqueue = ConfigType[]
    observed = Set{ConfigType}()

    for i in 1:initialpopulation
        push_config!(accept_config, random_configuration(space), evalqueue, observed)
    end
    
    prev = 0.0
    iter = 0
    config_and_errors = Pair[]
    verbose && println(stderr, "SearchModels> search params iter=$iter, tol=$tol, initialpopulation=$initialpopulation, maxpopulation=$maxpopulation, bsize=$bsize, mutbsize=$mutbsize, crossbsize=$crossbsize")

    while iter <= maxiters
        iter += 1
        empty!(config_and_errors)
        evaluate_queue(error_function, evalqueue, population, config_and_errors, parallel)
        if maxpopulation < length(population)
            resize!(population, maxpopulation)
        end

        inspect_population(space, population)
        if iter >= maxiters
            verbose && println("SearchModels> reached maximum number of iterations $maxiters")
            return population
        end

        curr = population[end].second
        if abs(curr - prev) <= tol
            verbose && println("SearchModels> stop by convergence error=$curr, tol=$tol")
            return population
        end

        prev = curr
        ## verbose && println(stderr, "SearchModels> *** generating extra indivuals bsize=$bsize, mutbsize=$mutbsize, crossbsize=$crossbsize")

        L = @view population[1:min(bsize, length(population))]
        for i in 1:mutbsize
            conf = mutate_configuration(space, rand(L).first, iter)
            push_config!(accept_config, conf, evalqueue, observed)
        end

        for i in 1:crossbsize
            shuffle!(L) # the way this procedure is designed is to support heterogeneous options
            i = rand(1:length(L))
            L[end], L[i] = L[end], L[i]
            conf = combine_configurations(L[end].first, L)
            push_config!(accept_config, conf, evalqueue, observed)
        end

        verbose && println(stderr, "SearchModels iteration $iter> population: $(length(population)), queue: $(length(evalqueue)), observed: $(length(observed)), best-error: $(population[1].second) worst-error: $(population[end].second)")
    end

    sort!(population, by=x->x.second)
end

end
