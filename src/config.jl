# ================================================================
# RESEARCH CONFIGURATION
# ================================================================

Base.@kwdef struct ModelConfig
    name::String
    objective::Symbol
    max_weight::Float64
end


Base.@kwdef struct ResearchConfig

    # ------------------------------------------------------------
    # Data window
    # ------------------------------------------------------------

    start_date::Date = Date("2021-09-23")
    end_date::Date = Date("2026-09-23")


    # ------------------------------------------------------------
    # Out-of-sample design
    # ------------------------------------------------------------

    oos_observations::Int = 252
    min_training_observations::Int = 250


    # ------------------------------------------------------------
    # Risk model
    # ------------------------------------------------------------

    ewma_halflife::Float64 = 252.0
    shrinkage_alpha::Float64 = 0.25


    # ------------------------------------------------------------
    # Portfolio optimization
    # ------------------------------------------------------------

    semideviation_mar::Float64 = 0.0
    capped_max_weight::Float64 = 0.08
    uncapped_max_weight::Float64 = 1.0


    # ------------------------------------------------------------
    # Data-quality rules
    # ------------------------------------------------------------

    max_gap_days::Int = 5


    # ------------------------------------------------------------
    # Metric conventions
    # ------------------------------------------------------------

    periods_per_year::Int = 252
    cvar_confidence::Float64 = 0.95

end

function validate_config(
    config::ResearchConfig,
)

    if config.start_date >= config.end_date
        error(
            "start_date must be before end_date."
        )
    end

    if config.oos_observations <= 0
        error(
            "oos_observations must be positive."
        )
    end

    if config.min_training_observations <= 0
        error(
            "min_training_observations must be positive."
        )
    end

    if config.ewma_halflife <= 0
        error(
            "ewma_halflife must be positive."
        )
    end

    if !isfinite(config.shrinkage_alpha) ||
       !(0.0 <= config.shrinkage_alpha <= 1.0)

        error(
            "shrinkage_alpha must be finite and between 0 and 1."
        )
    end

    if !isfinite(config.semideviation_mar)
        error(
            "semideviation_mar must be finite."
        )
    end

    if !isfinite(config.capped_max_weight) ||
       !(0.0 < config.capped_max_weight <= 1.0)

        error(
            "capped_max_weight must be in (0, 1]."
        )
    end

    if !isfinite(config.uncapped_max_weight) ||
       !(0.0 < config.uncapped_max_weight <= 1.0)

        error(
            "uncapped_max_weight must be in (0, 1]."
        )
    end

    if config.max_gap_days < 0
        error(
            "max_gap_days must be non-negative."
        )
    end

    if config.periods_per_year <= 0
        error(
            "periods_per_year must be positive."
        )
    end

    if !isfinite(config.cvar_confidence) ||
       !(0.0 < config.cvar_confidence < 1.0)

        error(
            "cvar_confidence must be between 0 and 1."
        )
    end

    return nothing
end


# ------------------------------------------------------------
# Portfolio models
# ------------------------------------------------------------

function default_models(
    config::ResearchConfig,
)
    return [
            ModelConfig(
                name = "MinVar_8pct",
                objective = :minvar,
                max_weight = config.capped_max_weight,
            ),

            ModelConfig(
                name = "MinVar_Uncapped",
                objective = :minvar,
                max_weight = config.uncapped_max_weight,
            ),

            ModelConfig(
                name = "Semideviation_8pct",
                objective = :semideviation,
                max_weight = config.capped_max_weight,
            ),

            ModelConfig(
                name = "Semideviation_Uncapped",
                objective = :semideviation,
                max_weight = config.uncapped_max_weight,
            ),
        ]

end

