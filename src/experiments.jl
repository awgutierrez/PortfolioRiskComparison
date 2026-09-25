# ================================================================
# EXPERIMENT ENGINE
# ================================================================

function run_model(
    model_name,
    train_returns;
    max_weight::Float64 = 0.08,
    semideviation_mar::Float64 = 0.05,
    ewma_halflife::Float64 = 252.0,
    shrinkage_alpha::Float64 = 0.25
)

    if startswith(
        model_name,
        "MinVar"
    )

        Σ =
            ewma_covariance(
                train_returns;
                half_life =
                    ewma_halflife
            )

        Σ =
            shrink_covariance(
                Σ;
                alpha =
                    shrinkage_alpha
            )

        Σ =
            make_positive_definite(Σ)

        weights =
            minvar_weights(
                Σ;
                max_weight =
                    max_weight
            )

    elseif startswith(
        model_name,
        "Semideviation"
    )

        weights =
            semideviation_weights(
                train_returns;
                mar =
                    semideviation_mar,
                max_weight =
                    max_weight
            )

        Σ =
            ewma_covariance(
                train_returns;
                half_life =
                    ewma_halflife
            )

        Σ =
            shrink_covariance(
                Σ;
                alpha =
                    shrinkage_alpha
            )

        Σ =
            make_positive_definite(Σ)

    else

        error(
            "Unknown model: $model_name"
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
    tickers;

    start_date::Date =
        Date("2013-09-23"),

    end_date::Date =
        Date("2026-09-23"),

    oos_observations::Int =
        252,

    min_training_observations::Int =
        250,

    ewma_halflife::Float64 =
        252.0,

    shrinkage_alpha::Float64 =
        0.25,

    semideviation_mar::Float64 =
        0.05
)

    println()
    println(
        "================================================"
    )
    println(
        "UNIVERSE: ",
        universe_name
    )
    println(
        "================================================"
    )


    aligned_prices =
        align_prices(
            prices
        )

    expected_assets =
        length(tickers)

    actual_assets =
        length(names(aligned_prices, Not(:date)))

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

    T =
        size(returns, 1)

    required =
        min_training_observations +
        oos_observations

    if T < required

        error(
            "$universe_name has only $T " *
            "return observations; " *
            "need at least $required."
        )
    end

    split =
        T - oos_observations

    train_returns =
        returns[1:split, :]

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

    models = [
        (
            "MinVar_8pct",
            0.08
        ),
        (
            "MinVar_Uncapped",
            1.0
        ),
        (
            "Semideviation_8pct",
            0.08
        ),
        (
            "Semideviation_Uncapped",
            1.0
        )
    ]

    metric_rows =
        DataFrame()

    weight_rows =
        DataFrame()

    for (
        model_name,
        max_weight
    ) in models

        println()
        println(
            "Running ",
            model_name
        )

        result =
            run_model(
                model_name,
                train_returns;
                max_weight =
                    max_weight,

                semideviation_mar =
                    semideviation_mar,

                ewma_halflife =
                    ewma_halflife,

                shrinkage_alpha =
                    shrinkage_alpha
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
                oos_portfolio_returns
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
    tickers;
    start_date::Date =
        Date("2021-09-23"),

    end_date::Date =
        Date("2026-09-23"),

    oos_observations::Int =
        252,

    min_training_observations::Int =
        250,

    ewma_halflife::Float64 =
        252.0,

    shrinkage_alpha::Float64 =
        0.25,

    semideviation_mar::Float64 =
        0.0
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
            startdt = start_date,
            enddt = end_date
        )

    return _run_universe_from_prices(
        universe_name,
        prices,
        tickers;
        start_date = start_date,
        end_date = end_date,
        oos_observations = oos_observations,
        min_training_observations = min_training_observations,
        ewma_halflife = ewma_halflife,
        shrinkage_alpha = shrinkage_alpha,
        semideviation_mar = semideviation_mar
    )
end

function compare_universes(
    requested_tickers;
    start_date::Date =
        Date("2021-09-23"),

    end_date::Date =
        Date("2026-09-23"),

    oos_observations::Int =
        252,

    min_training_observations::Int =
        250,

    ewma_halflife::Float64 =
        252.0,

    shrinkage_alpha::Float64 =
        0.25,

    semideviation_mar::Float64 =
        0.0,

    max_gap_days::Int =
        5,

    output_directory =
        "output"
)

    mkpath(output_directory)

    println()
    println("================================================")
    println("UNIVERSE DATA DIAGNOSTICS")
    println("================================================")

    prices =
        download_prices(
            requested_tickers;
            startdt = start_date,
            enddt = end_date
        )

    diagnostics =
        ticker_history_diagnostics(
            prices;
            start_date = start_date,
            end_date = end_date,
            max_gap_days = max_gap_days
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
            eligible_tickers;
            start_date = start_date,
            end_date = end_date,
            oos_observations = oos_observations,
            min_training_observations = min_training_observations,
            ewma_halflife = ewma_halflife,
            shrinkage_alpha = shrinkage_alpha,
            semideviation_mar = semideviation_mar
        )
 
    # ------------------------------------------------------------
    # Full requested universe
    # ------------------------------------------------------------

    full_result =
        _run_universe_from_prices(
            "FullUniverse_$(length(requested_tickers))",
            full_prices,
            requested_tickers;
            start_date = start_date,
            end_date = end_date,
            oos_observations = oos_observations,
            min_training_observations = min_training_observations,
            ewma_halflife = ewma_halflife,
            shrinkage_alpha = shrinkage_alpha,
            semideviation_mar = semideviation_mar
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