abstract type AbstractStochasticStructure{N} end

# Auxilliary type for selecting structure of stochastic program
abstract type StochasticInstantiation end
struct UnspecifiedInstantiation <: StochasticInstantiation end
struct Deterministic <: StochasticInstantiation end
struct BlockVertical <: StochasticInstantiation end
struct BlockHorizontal <: StochasticInstantiation end
struct DistributedBlockVertical <: StochasticInstantiation end
struct DistributedBlockHorizontal <: StochasticInstantiation end

# Constructor of stochastic structure. Should dispatch on instantiation type
function StochasticStructure end

# Always prefer user-provided instantiation type
function default_structure(instantiation::StochasticInstantiation, ::Any)
    return instantiation
end

# Otherwise, switch on provided optimizer
function default_structure(::UnspecifiedInstantiation, optimizer)
    if optimizer isa MOI.AbstractOptimizer
        # Default to DEP structure if standard MOI optimizer is given
        return Deterministic()
    else
        # In other cases, default to block-vertical structure
        if nworkers() > 1
            # Distribute in memory if Julia processes are available
            return DistributedBlockVertical()
        else
            return BlockVertical()
        end
    end
end

# Optimization #
# ========================== #
struct UnsupportedStructure{Opt <: StochasticProgramOptimizerType, S <: AbstractStochasticStructure} <: Exception end

function Base.showerror(io::IO, err::UnsupportedStructure{Opt, S}) where {Opt <: StochasticProgramOptimizerType, S <: AbstractStochasticStructure}
    print(io, "The stochastic structure $S is not supported by the optimizer $Opt")
end

"""
    supports_structure(optimizer::StochasticProgramOptimizerType, structure::AbstractStochasticStructure)

Return a `Bool` indicating whether `optimizer` supports the stochastic `structure`. That is, `load_structure!(optimizer, structure)` will not throw `UnsupportedStructure`
"""
function supports_structure(optimizer::StochasticProgramOptimizerType, structure::AbstractStochasticStructure)
    return false
end

# Getters #
# ========================== #
function structure_name(structure::AbstractStochasticStructure)
    return "Unknown"
end
function scenariotype(structure::AbstractStochasticStructure, s::Integer = 2)
    return _scenariotype(scenarios(structure, s))
end
function _scenariotype(::Vector{S}) where S <: AbstractScenario
    return S
end
function num_scenarios(structure::AbstractStochasticStructure, s::Integer = 2)
    return length(scenarios(structure, s))
end
function probability(structure::AbstractStochasticStructure, i::Integer, s::Integer = 2)
    return probability(scenario(structure, i, s))
end
function stage_probability(structure::AbstractStochasticStructure, s::Integer = 2)
    return probability(scenarios(structure, s))
end
function expected(structure::AbstractStochasticStructure, s::Integer = 2)
    return expected(scenarios(dep, s))
end
function distributed(structure::AbstractStochasticStructure, s)
    return false
end
# ========================== #

# Printing #
# ========================== #
function _print(io::IO, ::AbstractStochasticStructure)
    # Just give summary as default
    show(io, stochasticprogram)
end
# ========================== #
