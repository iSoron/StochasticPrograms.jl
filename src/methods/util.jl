# Utility #
# ========================== #
function evaluate_objective(objective::JuMP.GenericAffExpr, x::AbstractVector)
    val = objective.constant
    for (var, coeff) in objective.terms
        val += coeff*x[index(var).value]
    end
    return val
end

# function calculate_objective_value!(stochasticprogram::StochasticProgram)
#     first_stage = get_stage_one(stochasticprogram)
#     objective_value = eval_objective(first_stage.obj, first_stage.colVal)
#     objective_value += calculate_subobjectives(scenarioproblems(stochasticprogram))
#     first_stage.objVal = objective_value
#     return nothing
# end
# function calculate_subobjectives(scenarioproblems::ScenarioProblems)
#     return sum([(probability(scenario)*eval_objective(subprob.obj,subprob.colVal))::Float64 for (scenario,subprob) in zip(scenarios(scenarioproblems),subproblems(scenarioproblems))])
# end
# function calculate_subobjectives(scenarioproblems::DScenarioProblems)
#     partial_subobjectives = Vector{Float64}(undef, nworkers())
#     @sync begin
#         for (i,w) in enumerate(workers())
#             @async partial_subobjectives[i] = remotecall_fetch((sp) -> calculate_subobjectives(fetch(sp)),
#                                                                w,
#                                                                scenarioproblems[w-1])
#         end
#     end
#     return sum(partial_subobjectives)
# end

function invalidate_cache!(stochasticprogram::StochasticProgram)
    cache = problemcache(stochasticprogram)
    delete!(cache, :evp)
    delete!(cache, :dep)
    return nothing
end

function remove_scenarios!(stochasticprogram::StochasticProgram, s::Integer = 2)
    remove_scenarios!(scenarioproblems(stochasticprogram, s))
    return nothing
end

function remove_decision_variables!(stochasticprogram::StochasticProgram, s::Integer)
    remove_decision_variables!(scenarioproblems(stochasticprogram, s))
    return nothing
end

function remove_subproblems!(stochasticprogram::StochasticProgram, s::Integer = 2)
    remove_subproblems!(scenarioproblems(stochasticprogram, s))
    return nothing
end

function transfer_model!(dest::StochasticProgram, src::StochasticProgram)
    empty!(dest.generator)
    merge!(dest.generator, src.generator)
    return dest
end

function Base.copy(src::StochasticProgram{N}; optimizer = nothing) where N
    stages = ntuple(Val(N)) do i
        Stage(stage_parameters(src, i))
    end
    scenario_types = ntuple(Val(N-1)) do i
        scenariotype(src, i+1)
    end
    dest = StochasticProgram(stages, scenario_types, UnspecifiedInstantiation(), optimizer)
    merge!(dest.generator, src.generator)
    return dest
end

function supports_zero(types::Vector, provided_def::Bool)
    for vartype in types
        if !hasmethod(zero, (Type{vartype}, ))
            !provided_def && @warn "Zero not defined for $vartype. Cannot generate zero function."
            return false
        end
    end
    return true
end

function supports_expected(types::Vector, provided_def::Bool)
    for vartype in types
        if !hasmethod(+, (vartype, vartype))
            !provided_def && @warn "Addition not defined for $vartype. Cannot generate expectation function."
            return false
        end
        if !hasmethod(*, (Float64, vartype)) || Base.code_typed(*, (Float64, vartype))[1].second != vartype
            !provided_def && @warn "Scalar multiplication with Float64 not defined for $vartype. Cannot generate expectation function."
            return false
        end
    end
    return true
end

problemcache(stochasticprogram::StochasticProgram) = stochasticprogram.problemcache
function get_problem(stochasticprogram::StochasticProgram, key::Symbol)
    haskey(stochasticprogram.problemcache, key)|| error("No $key in problem cache")
    return stochasticprogram.problemcache[key]
end
function get_stage_one(stochasticprogram::StochasticProgram)
    haskey(stochasticprogram.problemcache, :stage_1) || error("First-stage problem not generated.")
    return stochasticprogram.problemcache[:stage_1]
end
function get_stage(stochasticprogram::StochasticProgram, stage::Integer)
    stage_key = Symbol(:stage_, stage)
    haskey(stochasticprogram.problemcache, stage_key) || error("Stage problem $stage not generated.")
    return stochasticprogram.problemcache[stage_key]
end

function pick_optimizer(stochasticprogram::StochasticProgram, supplied_optimizer)
    if supplied_optimizer == nothing
        return moi_optimizer(stochasticprogram)
    end
    return supplied_optimizer
end

internal_optimizer(optimizer::MOI.AbstractOptimizer) = optimizer

optimizerstr(optimizer::MOI.AbstractOptimizer) = JuMP._try_get_solver_name(optimizer)

typename(dtype::UnionAll) = dtype.body.name.name
typename(dtype::DataType) = dtype.name.name

function add_subscript(src::AbstractString, subscript::Integer)
    return @sprintf("%s%s", src, unicode_subscript(subscript))
end
add_subscript(src::Symbol, subscript::Integer) = add_subscript(String(src), subscript)

function unicode_subscript(subscript::Integer)
    if subscript < 0
        error("$subscript is negative")
    end
    return join('₀'+d for d in reverse(digits(subscript)))
end
# ========================== #
