using SearchModels
using Documenter

makedocs(;
    modules=[SearchModels],
    authors="Eric S. Tellez",
    devbranch = "main",
    repo="https://github.com/sadit/SearchModels.jl/blob/{commit}{path}#L{line}",
    sitename="SearchModels.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://sadit.github.io/SearchModels.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/sadit/SearchModels.jl",
)
