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
# RUN EXPERIMENTS
#
# The package automatically determines which securities have
# sufficient long-history coverage.
# ================================================================

results =
    compare_universes(
        FULL_UNIVERSE;
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
