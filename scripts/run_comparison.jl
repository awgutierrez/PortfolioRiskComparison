# ================================================================
# PORTFOLIO RISK COMPARISON
# ================================================================

using Pkg

Pkg.activate(
    joinpath(
        @__DIR__,
        ".."
    )
)

using PortfolioRiskComparison
using Dates

# ================================================================
# REQUESTED STOCK UNIVERSE
# ================================================================

FULL_UNIVERSE = [
    "ABBN.SW",
    "SREN.SW",
    "ENR.DE",
    "DBK.DE",
    "SCANFL.HE",
    "CBK.DE",
    "BNP.PA",
    "SIE.DE",
    "KCR.HE",
    "GLE.PA",
    "KEMIRA.HE",
    "KALMAR.HE",
    "VAIAS.HE",
    "COFA.PA",
    "WRT1V.HE",
    "ATRAV.HE",
    "ORNBV.HE",
    "DB1.DE",
    "ALV.DE",
    "DTE.DE",
    "EOAN.DE",
    "SAP.DE",
    "UNI.MI",
    "HNR1.DE",
    "TEL.OL",
    "ODF.OL",
    "ORK.OL",
    "VEI.OL",
    "STB.OL",
    "VVL.OL",
    "PROT.OL",
    "MING.OL",
    "TEL2-B.ST",

#    "PANW",
#    "HOOD",
#    "GWO.TO",
#    "POW.TO",
#    "TRGP",
#    "MFC.TO",
#    "MSFT",
#    "FLEX",
#    "ETN",
#    "NVDA",
#    "APH",
#    "CSCO",
#    "CLH",
#    "V",
#    "EMR",
#    "CVSA",
#    "LAUR",
#    "NA.TO",
#    "CRCL",
#    "NDAQ",
#    "C",
#    "GLW",
#    "BAC",
#    "AFL",
#    "RSG",
#    "GOOGL",
#    "L.TO",
#    "WRB",
#    "RTX",
#    "AJG",
#    "PGR",
#    "MLI",
#    "ETR",
#    "WM",
#    "WMT",
#    "HWM",
#    "KKR",
#    "BRO",
#    "IBM",
#    "VST",
#    "TLN",
#    "FSLR",
#    "EFN.TO",
#    "GIL.TO",
#    "BSX",
]

# ================================================================
# RESEARCH CONFIGURATION
#
# Changing ResearchConfig changes the default methodology 
# for the entire package.
#
# For sensitivity analysis, create a new 
# ResearchConfig and pass it to compare_universes.
# e.g. baseline_config = ResearchConfig()
#      short_halflife_config = ResearchConfig(
#           ewma_halflife = 126.0)
#      ten_percent_cap_config = ResearchConfig(
#           capped_max_weight = 0.10)
# ================================================================

config = ResearchConfig()
validate_config(config)

# ================================================================
# RUN EXPERIMENTS
#
# The package automatically determines which securities have
# sufficient long-history coverage.
# ================================================================

results =
    compare_universes(
        FULL_UNIVERSE,
        config;
        output_directory =
            joinpath(
                @__DIR__,
                "..",
                "output"
            )
    )

println()

println("================================================")

println("PORTFOLIO COMPARISON COMPLETE")

println("================================================")

println()

println(results.metrics)

println()

println("Output files:")

println("  output/universe_diagnostics.csv")

println("  output/portfolio_comparison.csv")

println("  output/portfolio_weights.csv")

println("  output/research_config.toml")
