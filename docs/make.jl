using JSPEC
using Documenter

DocMeta.setdocmeta!(JSPEC, :DocTestSetup, :(using JSPEC); recursive=true)

makedocs(;
    modules=[JSPEC],
    authors="Stefano Covino <stefano.covino@inaf.it> and contributors",
    sitename="JSPEC.jl",
    format=Documenter.HTML(;
        canonical="https://stefanocovino.github.io/JSPEC.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/stefanocovino/JSPEC.jl",
    devbranch="main",
)
