module PortfolioRiskComparison

using Dates
using LinearAlgebra
using Statistics
using DataFrames
using CSV
using JuMP
using MathOptInterface
using OSQP
using YFinance

const MOI = MathOptInterface

include("data.jl")
include("risk_models.jl")
include("optimizers.jl")
include("portfolio_metrics.jl")
include("experiments.jl")

export
    download_prices,
    align_prices,
    calculate_log_returns,

    ticker_history_diagnostics,
    select_long_history_tickers,

    ewma_covariance,
    constant_correlation_target,
    shrink_covariance,
    make_positive_definite,

    minvar_weights,
    semideviation_weights,

    portfolio_returns,
    portfolio_metrics,
    risk_contributions,
    concentration_metrics,

    run_model,
    run_universe,
    compare_universes
end
