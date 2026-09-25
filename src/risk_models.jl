# ================================================================
# RISK / COVARIANCE MODELS
# ================================================================

"""
EWMA covariance matrix.

The half-life determines how quickly historical observations
lose influence.
"""
function ewma_covariance(
    returns::DataFrame;
    half_life::Float64=252.0,
)

    tickers = names(returns, Not(:date))
    X = Matrix{Float64}(returns[:, tickers])

    T, N = size(X)

    if T < 2
        error("At least two return observations are required.")
    end

    if half_life <= 0
        error("half_life must be positive.")
    end

    # EWMA decay parameter.
    lambda = exp(-log(2) / half_life)

    # Most recent observation receives the largest weight.
    raw_weights = [
        lambda^(T - t)
        for t in 1:T
    ]

    weights = raw_weights ./ sum(raw_weights)

    # Weighted mean return.
    μ = vec(
        sum(
            weights[t] .* X[t, :]
            for t in 1:T
        )
    )

    # Weighted covariance matrix.
    Σ = zeros(N, N)

    for t in 1:T
        x = X[t, :] .- μ
        Σ .+= weights[t] .* (x * x')
    end

    return Σ
end


"""
Constant-correlation covariance target.
"""
function constant_correlation_target(Σ)

    N =
        size(Σ, 1)

    σ =
        sqrt.(
            max.(diag(Σ), 0.0)
        )

    correlations =
        zeros(N, N)

    for i in 1:N
        for j in 1:N

            if σ[i] > 0 && σ[j] > 0

                correlations[i, j] =
                    Σ[i, j] /
                    (σ[i] * σ[j])

            end
        end
    end

    ρ =
        sum(
            correlations[i, j]
            for i in 1:N
            for j in 1:N
            if i != j
        ) /
        (N * (N - 1))

    target =
        Matrix(
            Diagonal(σ.^2)
        )

    for i in 1:N
        for j in 1:N

            if i != j

                target[i, j] =
                    ρ * σ[i] * σ[j]

            end
        end
    end

    return Symmetric(target)
end


"""
Shrink covariance toward a constant-correlation target.
"""
function shrink_covariance(
    Σ;
    alpha::Float64 = 0.25
)

    target =
        constant_correlation_target(Σ)

    return Symmetric(
        (1 - alpha) .* Matrix(Σ) .+
        alpha .* Matrix(target)
    )
end


"""
Project a symmetric covariance matrix onto the positive-definite
cone by clipping small eigenvalues.
"""
function make_positive_definite(
    Σ;
    minimum_eigenvalue::Float64 = 1e-8
)

    S =
        Symmetric(
            (
                Matrix(Σ) +
                Matrix(Σ)'
            ) / 2
        )

    eig =
        eigen(S)

    values =
        max.(
            eig.values,
            minimum_eigenvalue
        )

    return Symmetric(
        eig.vectors *
        Diagonal(values) *
        eig.vectors'
    )
end
