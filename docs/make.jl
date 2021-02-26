using SearchModels
using Documenter

makedocs(;
    modules=[SearchModels],
    authors="Eric S. Tellez",
    repo="https://github.com/sadit/SearchModels.jl/blob/{commit}{path}#L{line}",
    sitename="SearchModels.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://sadit.github.io/SearchModels.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
        "Example" => "example.md",
        "API" => "api.md"
    ],
)

deploydocs(;
    repo="github.com/sadit/SearchModels.jl",
    devbranch="main",
    branch = "gh-pages",
    versions = ["stable" => "v^", "v#.#.#"]
)
