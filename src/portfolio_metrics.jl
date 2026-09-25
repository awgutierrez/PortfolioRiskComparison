# ================================================================
# PORTFOLIO METRICS
# ================================================================

"""
    portfolio_returns(returns, weights)

Calculate portfolio returns from an asset-return DataFrame and
portfolio weights.

The `date` column is excluded automatically.
"""
function portfolio_returns(
    returns::DataFrame,
    weights::Vector{Float64},
)

    tickers = names(returns, Not(:date))
    X = Matrix{Float64}(returns[:, tickers])

    if size(X, 2) != length(weights)
        error(
            "Number of portfolio weights ($(length(weights))) " *
            "does not match number of assets ($(size(X, 2)))."
        )
    end

    if any(!isfinite, weights)
        error("Portfolio weights contain non-finite values.")
    end

    return X * weights
end


"""
    annualized_volatility(returns; periods_per_year=252)

Annualized standard deviation of periodic returns.
"""
function annualized_volatility(
    returns;
    periods_per_year::Int=252,
)

    r = Float64.(collect(returns))

    if isempty(r)
        return NaN
    end

    return std(r) * sqrt(periods_per_year)
end


"""
    downside_deviation(returns; mar=0.0, periods_per_year=252)

Annualized downside deviation relative to the minimum acceptable
return (MAR).
"""
function downside_deviation(
    returns;
    mar::Float64=0.1,
    periods_per_year::Int=252,
)

    r = Float64.(collect(returns))

    if isempty(r)
        return NaN
    end

    downside = min.(r .- mar, 0.0)

    return sqrt(mean(downside.^2)) * sqrt(periods_per_year)
end


"""
    maximum_drawdown(returns)

Maximum drawdown calculated from a sequence of periodic returns.
"""
function maximum_drawdown(returns)

    r = Float64.(collect(returns))

    if isempty(r)
        return NaN
    end

    if any(r .<= -1.0)
        error(
            "Returns contain a value <= -100%, " *
            "so cumulative wealth cannot be calculated."
        )
    end

    wealth =
        cumprod(1.0 .+ r)

    running_max =
        accumulate(max, wealth)

    drawdowns =
        wealth ./ running_max .- 1.0

    return minimum(drawdowns)
end


"""
    historical_cvar(returns; confidence=0.95)

Historical daily CVaR (expected shortfall) calculated from the
empirical loss distribution.

The result is deliberately reported on a DAILY basis. It is not
multiplied by sqrt(252), because CVaR does not scale with time in
the same way as volatility.
"""
function historical_cvar(
    returns;
    confidence::Float64=0.95,
)

    if !(0.0 < confidence < 1.0)
        error("confidence must be between 0 and 1.")
    end

    r = Float64.(collect(returns))

    if isempty(r)
        return NaN
    end

    losses =
        sort(-r, rev=true)

    n_tail =
        max(
            1,
            ceil(
                Int,
                (1.0 - confidence) * length(losses),
            ),
        )

    return mean(losses[1:n_tail])
end


"""
    annualized_return(returns; periods_per_year=252)

Geometric annualized return based on realized cumulative wealth.
"""
function annualized_return(
    returns;
    periods_per_year::Int=252,
)

    r = Float64.(collect(returns))

    if isempty(r)
        return NaN
    end

    if any(r .<= -1.0)
        error(
            "Returns contain a value <= -100%, " *
            "so annualized return cannot be calculated."
        )
    end

    cumulative_growth =
        prod(1.0 .+ r)

    return cumulative_growth^(periods_per_year / length(r)) - 1.0
end


"""
    portfolio_metrics(returns)

Calculate the main OOS portfolio performance metrics.
"""
function portfolio_metrics(
    returns;
    periods_per_year::Int=252,
    mar::Float64=0.01,     
)

    r = Float64.(collect(returns))

    if isempty(r)
        error("Cannot calculate portfolio metrics from empty returns.")
    end

    annual_return =
        annualized_return(
            r;
            periods_per_year=periods_per_year,
        )

    volatility =
        annualized_volatility(
            r;
            periods_per_year=periods_per_year,
        )

    downside =
        downside_deviation(
            r;
            mar=mar,
            periods_per_year=periods_per_year,
        )

    max_drawdown =
        maximum_drawdown(r)

    cvar95 =
        historical_cvar(
            r;
            confidence=0.95,
        )

    # With risk-free rate = 0, Sharpe is annualized return divided
    # by annualized volatility.

    sharpe =
        volatility > 0.0 ?
        annual_return / volatility :
        NaN

    return (
        annual_return=annual_return,
        volatility=volatility,
        downside_deviation=downside,
        max_drawdown=max_drawdown,
        cvar95_daily=cvar95,
        sharpe=sharpe,
    )
end


"""
    risk_contributions(weights, Σ)

Variance-based percentage risk contributions:

    RC_i = w_i * (Σw)_i / (w'Σw)

The resulting vector sums to approximately one when portfolio
variance is positive.

For semideviation portfolios this is a variance-based diagnostic;
it should not be interpreted as a decomposition of semideviation
risk.
"""
function risk_contributions(
    weights,
    Σ,
)

    w = Float64.(collect(weights))
    covariance = Matrix{Float64}(Σ)

    n = length(w)

    if size(covariance) != (n, n)
        error(
            "Covariance matrix dimensions " *
            "$(size(covariance)) do not match " *
            "the $(n) portfolio weights."
        )
    end

    portfolio_variance =
        w' * covariance * w

    if portfolio_variance <= 0.0
        return fill(NaN, n)
    end

    marginal =
        covariance * w

    contribution =
        w .* marginal

    percentage =
        contribution ./ portfolio_variance

    return percentage
end


"""
    concentration_metrics(weights)

Portfolio concentration diagnostics.
"""
function concentration_metrics(weights)

    w = Float64.(collect(weights))

    if isempty(w)
        error("Cannot calculate concentration metrics for empty weights.")
    end

    if any(!isfinite, w)
        error("Portfolio weights contain non-finite values.")
    end

    return (
        max_weight=maximum(w),
        effective_holdings=1.0 / sum(w.^2),
        herfindahl=sum(w.^2),
        number_holdings=count(>(1e-6), w),
    )
end