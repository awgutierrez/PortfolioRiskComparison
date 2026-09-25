# ================================================================
# DATA HANDLING
# ================================================================

"""
    download_prices(tickers; startdt, enddt)

Download daily adjusted-close prices from Yahoo Finance.

YFinance.jl's `get_prices` operates on one ticker at a time, so the
requests are broadcast across `tickers`. The result is assembled into
a DataFrame with one column per ticker.

`autoadjust=false` is intentional: we explicitly use Yahoo's `adjclose`
field rather than the adjusted `close` field.
"""
function download_prices(
    tickers::Vector{String};
    startdt::Date,
    enddt::Date,
)

    raw = get_prices.(
        tickers;
        startdt=startdt,
        enddt=enddt,
        interval="1d",
        autoadjust=false,
        exchange_local_time=true,
        throw_error=true,
    )

    # Validate that every request returned data.
    for (ticker, result) in zip(tickers, raw)
        if isempty(result)
            error("YFinance returned no data for ticker $ticker")
        end

        required_fields = ("timestamp", "adjclose")

        for field in required_fields
            if !haskey(result, field)
                error(
                    "YFinance response for $ticker does not contain " *
                    "required field '$field'"
                )
            end
        end
    end

    # Build a union of all timestamps returned by Yahoo.
    all_dates = sort!(
        unique(
            reduce(
                vcat,
                [
                    Date.(result["timestamp"])
                    for result in raw
                ],
            ),
        ),
    )

    prices = DataFrame(date=all_dates)

    # Add one adjusted-close column per ticker.
    for (ticker, result) in zip(tickers, raw)

        dates = Date.(result["timestamp"])
        values = Float64.(result["adjclose"])

        # Map Yahoo observations onto the common date index.
        lookup = Dict(
            d => v
            for (d, v) in zip(dates, values)
            if isfinite(v) && v > 0
        )

        prices[!, Symbol(ticker)] = [
            get(lookup, d, NaN)
            for d in all_dates
        ]
    end

    sort!(prices, :date)

    return prices
end


"""
    align_prices(prices; max_fill_days=5)

Align price histories across assets.

The procedure is intentionally conservative:

1. Determine the genuine common-history window using the latest first
   valid observation and earliest last valid observation.
2. Restrict all assets to that window.
3. Forward-fill only short gaps.
4. Never backfill.
5. Keep only dates where every asset has a finite positive price.

The short forward-fill allowance is intended for exchange-calendar
differences and isolated missing observations, not for filling long
historical gaps.
"""
function align_prices(
    prices::DataFrame;
    max_fill_days::Int=5,
)

    tickers = names(prices, Not(:date))

    # Determine first and last valid observation for each asset.
    first_valid = Date[]
    last_valid = Date[]

    for ticker in tickers
        values = prices[!, ticker]

        valid_indices = findall(
            x -> !ismissing(x) && isfinite(Float64(x)) && Float64(x) > 0,
            values,
        )

        if isempty(valid_indices)
            error("No valid price observations found for $ticker")
        end

        push!(first_valid, prices.date[first(valid_indices)])
        push!(last_valid, prices.date[last(valid_indices)])
    end

    common_start = maximum(first_valid)
    common_end = minimum(last_valid)

    if common_start >= common_end
        error(
            "No common price-history window exists. " *
            "Common start=$common_start, common end=$common_end."
        )
    end

    # Restrict to the genuine common-history interval.
    aligned = filter(
        row -> common_start <= row.date <= common_end,
        prices,
    )

    # Forward-fill only short gaps.
    #
    # We use actual calendar-day distance rather than row count because
    # different exchanges have different holiday calendars.
    for ticker in tickers

        values = aligned[!, ticker]

        last_value = NaN
        last_date = nothing

        for i in eachindex(values)

            value = values[i]
            current_date = aligned.date[i]

            valid =
                !ismissing(value) &&
                isfinite(Float64(value)) &&
                Float64(value) > 0

            if valid
                last_value = Float64(value)
                last_date = current_date
                values[i] = last_value

            elseif last_date !== nothing

                gap_days = Dates.value(current_date - last_date)

                if gap_days <= max_fill_days
                    values[i] = last_value
                end
            end
        end

        aligned[!, ticker] = values
    end

    # Keep only dates on which every asset has a valid price.
    keep = trues(nrow(aligned))

    for ticker in tickers
        values = aligned[!, ticker]

        keep .&= [
            !ismissing(x) &&
            isfinite(Float64(x)) &&
            Float64(x) > 0
            for x in values
        ]
    end

    aligned = aligned[keep, :]

    if nrow(aligned) < 2
        error(
            "Price alignment produced fewer than two observations. " *
            "Check ticker histories and missing-data handling."
        )
    end

    return aligned
end


"""
    calculate_log_returns(prices)

Calculate daily log returns from an aligned price DataFrame.
"""
function calculate_log_returns(prices::DataFrame)

    tickers = names(prices, Not(:date))

    n = nrow(prices)

    if n < 2
        error("At least two price observations are required.")
    end

    returns = DataFrame(
        date=prices.date[2:end],
    )

    for ticker in tickers

        p = Float64.(prices[!, ticker])

        if any(!isfinite, p) || any(p .<= 0)
            error(
                "Invalid price encountered in $ticker. " *
                "Prices must be finite and strictly positive."
            )
        end

        returns[!, ticker] = diff(log.(p))
    end

    return returns
end


# ================================================================
# UNIVERSE DIAGNOSTICS
# ================================================================

"""
    ticker_history_diagnostics(
        prices;
        start_date,
        end_date,
        max_gap_days=5
    )

Inspect the historical coverage of every ticker in a downloaded
price DataFrame.

A ticker is considered long-history eligible when:

1. It has at least one valid price on or before `start_date`.
2. It has at least one valid price on or after `end_date`.
3. It has no internal missing-price gap longer than `max_gap_days`.

This function does not fill or modify the price data.
"""
function ticker_history_diagnostics(
    prices::DataFrame;
    start_date::Date,
    end_date::Date,
    max_gap_days::Int=5,
)
    if start_date > end_date
        error("start_date must be on or before end_date.")
    end

    if max_gap_days < 0
        error("max_gap_days must be non-negative.")
    end

    tickers = names(prices, Not(:date))

    rows = DataFrame(
        ticker=String[],
        first_valid_date=Union{Missing, Date}[],
        last_valid_date=Union{Missing, Date}[],
        observations=Int[],
        longest_gap_days=Float64[],
        long_history_eligible=Bool[],
        exclusion_reason=String[],
    )

    dates = Date.(prices.date)

    # Allow for weekends, exchange holidays, and small endpoint
    # differences between the requested dates and actual trading dates.
    start_tolerance = Day(max_gap_days)
    end_tolerance = Day(max_gap_days)

    for ticker in tickers

        values = prices[!, ticker]

        valid = [
            !ismissing(v) &&
            isfinite(Float64(v)) &&
            Float64(v) > 0.0
            for v in values
        ]

        valid_dates = dates[valid]

        # Only inspect observations inside the requested research window.
        valid_dates = valid_dates[
            (valid_dates .>= start_date) .&
            (valid_dates .<= end_date)
        ]

        observations = length(valid_dates)

        if isempty(valid_dates)

            push!(
                rows,
                (
                    ticker,
                    missing,
                    missing,
                    0,
                    Inf,
                    false,
                    "no_valid_history"
                )
            )

            continue
        end

        first_date = first(valid_dates)
        last_date = last(valid_dates)

        longest_gap =
            if length(valid_dates) >= 2
                maximum(
                    Dates.value.(diff(valid_dates))
                )
            else
                Inf
            end

        reasons = String[]

        # Endpoint checks use a tolerance because requested dates
        # do not necessarily fall on trading days.
        if first_date > start_date + start_tolerance
            push!(
                reasons,
                "history_starts_$(first_date)"
            )
        end

        if last_date < end_date - end_tolerance
            push!(
                reasons,
                "history_ends_$(last_date)"
            )
        end

        # A difference of 6 calendar days means there are at least
        # 5 calendar days between observations.
        if longest_gap > max_gap_days + 1
            push!(
                reasons,
                "internal_gap_$(longest_gap)_days"
            )
        end

        eligible = isempty(reasons)

        exclusion_reason =
            eligible ? "" : join(reasons, "; ")

        push!(
            rows,
            (
                ticker,
                first_date,
                last_date,
                observations,
                Float64(longest_gap),
                eligible,
                exclusion_reason
            )
        )
    end

    return rows
end

"""
    select_long_history_tickers(diagnostics)

Return tickers that satisfy the long-history data-quality
requirements.
"""
function select_long_history_tickers(
    diagnostics::DataFrame,
)
    return String[
        row.ticker
        for row in eachrow(diagnostics)
        if row.long_history_eligible
    ]
end