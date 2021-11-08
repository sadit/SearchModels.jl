# This file is a part of SearchModels.jl

export AbstractSolutionSpace, search_models, SearchParams, rand, combine_select, combine, mutate
using Distributed, Random, StatsBase, Parameters

abstract type AbstractSolutionSpace end
## NOTE: all configuratons must define hash, and isequal

"""
    config_type(::T)

Config type identifier, it may or not be a type
"""
config_type(::T) where T = Symbol(Base.typename(T))

#function rand(space::AbstractSolutionSpace) end
#function combine(a, b) end

"""
    rand(space::AbstractSolutionSpace)

Creates a random configuration sampling the given space
"""

"""
    compatible_space(space::AbstractVector, c)

Selects the compatible space for configuration c
"""
function compatible_space(space::AbstractVector, c)
    for s in space
        if c isa eltype(s)
            return s
        end
    end
    error("uncompatible space for $(typeof(c)) in space list $(typeof(space))")
end

compatible_space(space::AbstractSolutionSpace, c) = space

function compatible_config(c, L::AbstractVector)
    t_ = config_type(c)

    for p in L
        x = p.first
        if config_type(x) == t_
            return x
        end
    end

    error("uncompatible configuration for $(typeof(c))")
end

"""
    combine(space::AbstractSolutionSpace, c1, c2)
    combine(c1, c2)

Combines two configurations into a single configuration. The three argument functions defaults to two argument function.

"""
function combine end

"""
    combine_select(a, L::AbstractVector)

Combines `a` configuration with some compatible configuation in the given list of pairs (config => score),
The `a` config is always at the end of `L` and also `L` is always shuffled.
If you are in doubt, use the higher level interface `combine(c1, c2)`.
"""
function combine_select(a::T, L::AbstractVector) where T
    # L is a vector of pairs config => score
    # L should be shuffled before combining
    combine(a, compatible_config(a, L))
end

function mutate end
"""
    mutate(space::AbstractSolutionSpace, c, iter)
    mutate(space::AbstractVector, c, iter)

Mutates configuration. If space is a list of spaces, then the proper space is determined.
"""
function mutate(space::AbstractVector, c, iter)
    mutate(compatible_space(space, c), c, iter)
end

"""
    evaluate_queue(errfun, evalqueue, config_and_perf, parallel)

Evaluates queue of using errfun; the resulting `config => performances` are stored in `config_and_perf`

"""
function evaluate_queue(errfun::Function, evalqueue, config_and_perf, parallel)
    while length(evalqueue) > 0
        c = pop!(evalqueue)
        if parallel == :distributed
            perf = Distributed.@spawn errfun(c)
            push!(config_and_perf, c => perf)
        elseif parallel == :threads
            perf = Threads.@spawn errfun(c)
            push!(config_and_perf, c => perf)
        else
            error("Unknown parallel option")
        end
    end
end

function fetch_queue(config_and_perf, population)
    f = fetch(first(config_and_perf))
    if population === nothing
        [k => fetch(v) for (k, v) in config_and_perf]
    else
        for (k, v) in config_and_perf
            push!(population, k => fetch(v))
        end

        population
    end
end


"""
    queue_config!(accept_config, conf, evalqueue, observed)

Pushes `conf` into the evaluation queue. It checks if was already observed and if it is accepted by the `accept_config` predicate.
"""
function queue_config!(accept_config, conf, evalqueue, observed)
    if !(conf in observed) && accept_config(conf)
        push!(evalqueue, conf)
        push!(observed, conf)
    end
end

"""
    SearchParams(;
        maxpopulation::Int = 32
        bsize::Int = 16
        mutbsize::Int = 8
        crossbsize::Int = 8
        maxiters::Int = 300
        tol::Float64 = 0.001
        verbose::Bool = true
    )

reates a mutable list of search parameters, it can be changed online via `inspect_population`.

- `maxpopulation`: the maximum number of configurations to be kept at each iteration (based on its minimum error)
- `bsize`: number of best items to be used for mutation and crossing procedures
- `mutbsize`: number of new configurations per iteration from a mutation procedure
- `crossbsize`: number of new configurations per iteration from a crossing procedure
- `maxiters`: maximum iterations of the search procedure
- `tol`: stop search tolerance to population errors on the best `maxpopulation` configurations; negative values will force to evaluate `maxiters`
- `verbose`: controls if the verbosity of the search iterations

"""
@with_kw mutable struct SearchParams
    maxpopulation::Int = 16
    bsize::Int = 8
    mutbsize::Int = 8
    crossbsize::Int = 8
    maxiters::Int = 300
    tol::Float64 = 0.001
    verbose::Bool = true
end

"""
    search_models(
        errfun::Function,  # error function, it can be used with `do conf ... end` block
        space::AbstractSolutionSpace,
        initialpopulation=32,
        params::SearchParams=SearchParams();
        geterr::Function=identity,
        accept_config::Function=config->true,
        inspect_population::Function=(space, params, population) -> nothing,
        parallel=:none, # :none, :threads, :distributed
    )

Explores the search space trying to minimize the given error function. The procedure consists on an iterative stochastic method
based on an evolutionary algorithm. It is starts with `initialpopulation` configurations, evaluate them mutate and cross them;
it selects at most `maxpopulation` configurations at any iteration (best ones).
- `errfun`: the function to minimize (receives the configuration as argument)
- `space`: Search space definition
- `params`: search parameters
- `geterr` a function to compute or fetch the cost (a single floating point) on the output of `errfun`
- `initialpopulation`: initial number of configurations to conform the population, or an initial list of configurations
- `accept_config`: an alternative way to deny some configuration to be evaluated (receives the configuration as argument)
- `inspect_population`: observes the population after evaluating a beam of solutions
- `parallel`: controls if the search is made with some kind of parallel strategy (only used for evaluation errors). Valid values are:
  - `:none`: there is no parallelization, the default value
  - `:threads`: evaluates error functions using threads
  - `:distributed`: evaluates error functions using a distributed environment (using the available workers)
"""
function search_models(
        errfun::Function,
        space::AbstractSolutionSpace,
        initialpopulation=32, # it can alos be a list of config seeds
        params::SearchParams=SearchParams();
        geterr::Function=identity,
        accept_config::Function=config -> true,
        inspect_population::Function=(space, params, population) -> nothing,
        parallel=:none, # :none, :threads, :distributed
    )

    ConfigType = eltype(space)
    evalqueue = ConfigType[]
    observed = Set{ConfigType}() # solutions should override hash and isqual functions

    if initialpopulation isa Integer
        for i in 1:initialpopulation
            queue_config!(accept_config, rand(space), evalqueue, observed)
        end
    else
        for c in initialpopulation
            queue_config!(accept_config, c, evalqueue, observed)
        end
    end
    prev = 0.0
    iter = 0

    population = nothing
    config_and_perf = Pair[]
    params.verbose && println(stderr, "SearchModels> search params iter=$iter, tol=$(params.tol), initialpopulation=$initialpopulation, maxpopulation=$(params.maxpopulation), bsize=$(params.bsize), mutbsize=$(params.mutbsize), crossbsize=$(params.crossbsize)")

    while iter <= params.maxiters
        iter += 1

        if parallel == :none
            if population === nothing
                population = [c => errfun(c) for c in evalqueue]
            else
                for c in evalqueue
                    push!(population, c => errfun(c))
                end
            end
            
            empty!(evalqueue)
        else
            empty!(config_and_perf)
            evaluate_queue(errfun, evalqueue, config_and_perf, parallel)
            population = fetch_queue(evalqueue, population)    
        end

        sort!(population, by=x->geterr(x.second))    
        inspect_population(space, params, population)

        if params.maxpopulation < length(population)
            resize!(population, params.maxpopulation)
        end

        if iter >= params.maxiters
            params.verbose && println("SearchModels> reached maximum number of iterations $(params.maxiters)")
            return population
        end

        curr = geterr(population[end].second)
        if abs(curr - prev) <= params.tol
            params.verbose && println("SearchModels> stop by convergence error=$curr, tol=$(params.tol)")
            return population
        end

        prev = curr
        ## params.verbose && println(stderr, "SearchModels> *** generating extra indivuals bsize=$bsize, mutbsize=$mutbsize, crossbsize=$crossbsize")
        best_error, worst_error = population[1].second, population[end].second ## the top configurations will be shuffled
        L = @view population[1:min(params.bsize, length(population))]
        for i in 1:params.mutbsize
            conf = mutate(space, rand(L).first, iter)
            queue_config!(accept_config, conf, evalqueue, observed)
        end

        for i in 1:params.crossbsize
            shuffle!(L) # the way this procedure is designed is to support heterogeneous options
            i = rand(1:length(L))
            L[end], L[i] = L[end], L[i]
            conf = combine_select(L[end].first, L)
            queue_config!(accept_config, conf, evalqueue, observed)
        end

        params.verbose && println(stderr, "SearchModels iteration $iter> population: $(length(population)), bsize: $(params.bsize), queue: $(length(evalqueue)), observed: $(length(observed)), best-error: $(best_error) worst-error: $(worst_error)")
    end

    sort!(population, by=x->geterr(x.second))
end
