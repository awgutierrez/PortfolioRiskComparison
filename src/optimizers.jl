# ================================================================
# PORTFOLIO OPTIMIZERS
# ================================================================

"""
Long-only minimum-variance optimization.

max_weight = 0.08 gives an 8% position limit.

max_weight = 1.0 gives the effectively uncapped case.
"""
function minvar_weights(
    Σ;
    max_weight::Float64 = 0.08
)

    N =
        size(Σ, 1)

    model =
        Model(OSQP.Optimizer)

    set_silent(model)

    @variable(
        model,
        0 <= w[1:N] <= max_weight
    )

    @constraint(
        model,
        sum(w) == 1
    )

    @objective(
        model,
        Min,
        w' * Matrix(Σ) * w
    )

    optimize!(model)

    status =
        termination_status(model)

    if status != MOI.OPTIMAL &&
       status != MOI.LOCALLY_SOLVED

        error(
            "Minimum-variance optimization failed: $status"
        )
    end

    return value.(w)
end


"""
    semideviation_weights(
        returns;
        mar=0.0,
        max_weight=1.0
    )

Calculate long-only, fully invested portfolio weights that minimize
squared downside deviation relative to the MAR.

The `date` column is excluded automatically.
"""
function semideviation_weights(
    returns::DataFrame;
    mar::Float64=0.0,
    max_weight::Float64=1.0,
)

    tickers = names(returns, Not(:date))
    X = Matrix{Float64}(returns[:, tickers])

    T, N = size(X)

    if T < 1
        error("At least one return observation is required.")
    end

    if max_weight <= 0.0
        error("max_weight must be positive.")
    end

    if max_weight * N < 1.0
        error(
            "max_weight=$max_weight is infeasible for " *
            "$N assets because the weights must sum to 1."
        )
    end

    if any(x -> !isfinite(x), X)
        error("Return matrix contains non-finite values.")
    end

    model = Model(OSQP.Optimizer)

    set_silent(model)

    @variable(
        model,
        0.0 <= w[1:N] <= max_weight
    )

    @variable(
        model,
        u[1:T] >= 0.0
    )

    @constraint(
        model,
        sum(w[j] for j in 1:N) == 1.0
    )

    for t in 1:T

        portfolio_return =
            sum(
                X[t, j] * w[j]
                for j in 1:N
            )

        @constraint(
            model,
            u[t] >= mar - portfolio_return
        )
    end

    @objective(
        model,
        Min,
        sum(u[t]^2 for t in 1:T) / T
    )

    optimize!(model)

    status = termination_status(model)

    if !(
        status == MOI.OPTIMAL ||
        status == MOI.LOCALLY_SOLVED
    )
        error(
            "Semideviation optimization failed. " *
            "Termination status: $status"
        )
    end

    weights = value.(w)

    # Clean tiny numerical values and normalize.
    weights[
        abs.(weights) .< 1e-10
    ] .= 0.0

    weights ./= sum(weights)

    return weights
end