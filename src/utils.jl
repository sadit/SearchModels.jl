# This file is a part of SearchModels.jl
# License is Apache 2.0: https://www.apache.org/licenses/LICENSE-2.0.txt

using Random

## NOTE: all configuratons must define hash, and isequal

"""
    scale(x, s=1.1; p1=0.5, p2=0.5, lower=typemin(T), upper=typemax(T))::T

With probability `p1` ``x``` is scaled by `s`; if ``x`` is going to be scaled, then with probability `p2` ``x`` is growth (or reduced otherwise).
Minimum and maximum values can be specified.
"""
function scale(x::T; s=1.1, p1=0.5, p2=0.5, lower=typemin(T), upper=typemax(T))::T where {T<:AbstractFloat}
    if rand() < p1
        min(upper, max(lower, rand() < p2 ? x * s : x / s))
    else
        x
    end
end

function scale(x::T; s=1.1, p1=0.5, p2=0.5, lower=typemin(T), upper=typemax(T))::T where {T<:Integer}
    if rand() < p1
        x = min(upper, max(lower, rand() < p2 ? x * s : x / s))
        ceil(T, x)
    else
        x
    end
end

"""
    translate(x::T; s=2, p1=0.5, p2=0.5, lower=typemin(T), upper=typemax(T)) where {T<:Real}

With probability `p1` ``x`` is modified; if ``x`` is modified, then with probability `p2` returns ``x+s`` or ``x-s`` otherwise.
Minimum and maximum values can be specified.
"""
function translate(x::T; s=2, p1=0.5, p2=0.5, lower=typemin(T), upper=typemax(T))::T where {T<:Real}
    if rand() < p1
        min(upper, max(lower, rand() < p2 ? x + s : x - s))
    else
        x
    end
end

"""
    change(x, choices; p1=0.5)

With prob `p1` `x` is changed by some element in `choices`. Please note that if ``x \\in choices`` then the actual `p1` is modified.
"""
function change(x, choices; p1=0.5)
    rand() < p1 ? rand(choices) : x
end