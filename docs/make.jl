# Use
#
#     DOCUMENTER_DEBUG=true julia --color=yes make.jl local [nonstrict] [fixdoctests]
#
# for local builds.

using Documenter
using Juleana

# Doctest setup
DocMeta.setdocmeta!(
    Juleana,
    :DocTestSetup,
    :(using Juleana);
    recursive = true
)

makedocs(
    sitename = "Juleana",
    modules = [Juleana],
    format = Documenter.HTML(
        prettyurls = !("local" in ARGS),
        canonical = "https://legend-exp.github.io/Juleana.jl/stable/"
    ),
    pages = [
        "Home" => "index.md",
        "Processors" => [
            "DSP Phy" => [
                "Processor Flow" => "process_dsp_phy/processor_flow.md",
                "Analysis Functions" => [
                    "dsp_icpc_compressed" => "process_dsp_phy/analysis_functions/dsp_icpc_compressed.md",
                ]
            ]
        ],
        "API" => "api.md",
        "LICENSE" => "LICENSE.md"
    ],
    doctest = ("fixdoctests" in ARGS) ? :fix : true,
    linkcheck = !("nonstrict" in ARGS),
    warnonly = ("nonstrict" in ARGS)
)

deploydocs(
    repo = "github.com/legend-exp/Juleana.jl.git",
    forcepush = true,
    push_preview = true
)
