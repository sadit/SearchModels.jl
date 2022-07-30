# This file is a part of SearchModels.jl

module SearchModels

struct InvalidSetupError <: Exception
    cfg::Any
    msg::String
end

export InvalidSetupError

Base.showerror(io::IO, e::InvalidSetupError) = print(io, e.msg, e.cfg)
 
include("utils.jl")
include("search.jl")

end
