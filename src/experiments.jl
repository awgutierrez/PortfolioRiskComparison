# ================================================================
# EXPERIMENT ENGINE
# ================================================================

function run_model(
    model::ModelConfig,
    train_returns::DataFrame,
    config::ResearchConfig,
)

    if model.objective == :minvar

        Σ =
            ewma_covariance(
                train_returns;
                half_life =
                    config.ewma_halflife
            )

        Σ =
            shrink_covariance(
                Σ;
                alpha =
                    config.shrinkage_alpha
            )

        Σ =
            make_positive_definite(Σ)

        weights =
            minvar_weights(
                Σ;
                max_weight =
                    model.max_weight
            )

    elseif model.objective == :semideviation

        weights =
            semideviation_weights(
                train_returns;
                mar =
                    config.semideviation_mar,

                max_weight =
                    model.max_weight
            )

        Σ =
            ewma_covariance(
                train_returns;
                half_life =
                    config.ewma_halflife
            )

        Σ =
            shrink_covariance(
                Σ;
                alpha =
                    config.shrinkage_alpha
            )

        Σ =
            make_positive_definite(Σ)

    else

        error(
            "Unknown portfolio objective: " *
            "$(model.objective)"
        )

    end

    return (
        weights = weights,
        covariance = Σ
    )

end


function _run_universe_from_prices(
    universe_name,
    prices::DataFrame,
    tickers,
    config::ResearchConfig,
)

    println()
    println("================================================")
    println("UNIVERSE: ", universe_name)
    println("================================================")

    aligned_prices = align_prices(prices)

    expected_assets = length(tickers)

    actual_assets = length(names(aligned_prices, Not(:date)))

    if actual_assets != expected_assets
        error(
            "$universe_name contains $expected_assets tickers, " *
            "but aligned data contains $actual_assets asset columns."
        )
    end

    println("Aligned observations: ", nrow(aligned_prices) ) 
    println( "Aligned period: ", first(aligned_prices.date), " → ", last(aligned_prices.date) )

    returns =
        calculate_log_returns(
            aligned_prices
        )

    T = size(returns, 1)

    required =
        config.min_training_observations +
        config.oos_observations

    if T < required

        error(
            "$universe_name has only $T " *
            "return observations; " *
            "need at least $required."
        )
    end

    split = T - config.oos_observations

    train_returns = returns[1:split, :]

    oos_returns =
        returns[
            split+1:end,
            :
        ]

    println(
        "Training observations: ",
        size(train_returns, 1)
    )

    println(
        "OOS observations: ",
        size(oos_returns, 1)
    )

    models = default_models(config)

    metric_rows = DataFrame()

    weight_rows = DataFrame()

    for model in models

        model_name = model.name

        println()
        println("Running ", model_name)

        result =
            run_model(
                model,
                train_returns,
                config
            )

        weights = result.weights

        asset_names =
            names(train_returns, Not(:date))

        println(
            "Ticker count: ",
            length(tickers),
            " | Return asset count: ",
            length(asset_names),
            " | Weight count: ",
            length(weights)
        )

        if length(weights) != length(asset_names)
            error(
                "Weight dimension mismatch for $model_name in $universe_name: " *
                "$(length(weights)) weights for $(length(asset_names)) assets."
            )
        end

        oos_portfolio_returns =
            portfolio_returns(
                oos_returns,
                weights
            )

        metrics =
            portfolio_metrics(
                oos_portfolio_returns;
                periods_per_year =
                    config.periods_per_year,
                mar =
                    config.semideviation_mar,
                cvar_confidence =
                    config.cvar_confidence
            )

        concentration =
            concentration_metrics(
                weights
            )

        # -------------------------------
        # Performance row
        # -------------------------------

        push!(
            metric_rows,
            (
                universe =
                    universe_name,

                model =
                    model_name,

                assets =
                    length(asset_names),

                training_observations =
                    size(
                        train_returns,
                        1
                    ),

                oos_observations =
                    length(
                        oos_portfolio_returns
                    ),

                annual_return =
                    metrics.annual_return,

                volatility =
                    metrics.volatility,

                downside_deviation =
                    metrics.downside_deviation,

                max_drawdown =
                    metrics.max_drawdown,

                cvar95_daily =
                    metrics.cvar95_daily,

                sharpe =
                    metrics.sharpe,

                max_weight =
                    concentration.max_weight,

                effective_holdings =
                    concentration.effective_holdings,

                herfindahl =
                    concentration.herfindahl,

                number_holdings =
                    concentration.number_holdings
            )
        )

        # -------------------------------
        # Weight rows
        # -------------------------------

        for j in eachindex(asset_names)

            push!(
                weight_rows,
                (
                    universe =
                        universe_name,

                    ticker =
                        asset_names[j],

                    model =
                        model_name,

                    weight =
                    weights[j]
                )
            )
        end  
    end

    return (
        metrics = metric_rows,
        weights = weight_rows
    )
end

function run_universe(
    universe_name,
    tickers,
    config::ResearchConfig,
)

    if isempty(tickers)
        error(
            "Cannot run universe '$universe_name': " *
            "ticker list is empty."
        )
    end

    prices =
        download_prices(
            tickers;
            startdt = config.start_date,
            enddt = config.end_date
        )

    return _run_universe_from_prices(
        universe_name,
        prices,
        tickers,
        config
    )
end

function compare_universes(
    requested_tickers,
    config::ResearchConfig;
    output_directory = "output",
)

    mkpath(output_directory)

    println()
    println("================================================")
    println("UNIVERSE DATA DIAGNOSTICS")
    println("================================================")

    prices =
        download_prices(
            requested_tickers;
            startdt = config.start_date,
            enddt = config.end_date
        )

    diagnostics =
        ticker_history_diagnostics(
            prices;
            start_date = config.start_date,
            end_date = config.end_date,
            max_gap_days = config.max_gap_days
        )

    println()
    println("Requested securities: ", length(requested_tickers))

    eligible_tickers =
        select_long_history_tickers(
            diagnostics
        )

    if isempty(eligible_tickers)
        error(
            "No securities satisfy the long-history data requirements. " *
            "Check universe_diagnostics.csv and the requested date range."
        )
    end

    println("Long-history eligible securities: ", length(eligible_tickers))

    excluded =
        diagnostics[
            .!diagnostics.long_history_eligible,
            :
        ]

    println("Excluded securities: ", nrow(excluded))

    if nrow(excluded) > 0

        println()
        println("Exclusions:")

        for row in eachrow(excluded)

            println(
                "  ",
                row.ticker,
                " → ",
                row.exclusion_reason
            )

        end
    end

    CSV.write(
        joinpath(
            output_directory,
            "universe_diagnostics.csv"
        ),
        diagnostics
    )

    
    long_prices =
        select(
            prices,
            :date,
            eligible_tickers...
        )

    full_prices =
        select(
            prices,
            :date,
            requested_tickers...
        )

    # ------------------------------------------------------------
    # Long-history universe
    # ------------------------------------------------------------

    long_result =
        _run_universe_from_prices(
            "LongHistory_$(length(eligible_tickers))",
            long_prices,
            eligible_tickers,
            config
        )
 
    # ------------------------------------------------------------
    # Full requested universe
    # ------------------------------------------------------------

    full_result =
        _run_universe_from_prices(
            "FullUniverse_$(length(requested_tickers))",
            full_prices,
            requested_tickers,
            config
        )


    metrics =
        vcat(
            long_result.metrics,
            full_result.metrics
        )

    weights =
        vcat(
            long_result.weights,
            full_result.weights
        )

    CSV.write(
        joinpath(
            output_directory,
            "portfolio_comparison.csv"
        ),
        metrics
    )

    CSV.write(
        joinpath(
            output_directory,
            "portfolio_weights.csv"
        ),
        weights
    )

    return (
        metrics = metrics,
        weights = weights,
        diagnostics = diagnostics,
        eligible_tickers = eligible_tickers
    )
end