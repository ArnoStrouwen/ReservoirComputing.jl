
struct ESN{I,S,N,T,O,M,IS} <: AbstractReservoirComputer
    res_size::I
    train_data::S
    nla_type::N
    input_matrix::T
    reservoir_driver::O 
    reservoir_matrix::M
    states_type::E
    states::IS
end

struct StandardStates <: AbstractStates end
struct ExtendedStates <: AbstractStates end
struct HybridStates{T,K,O,S,D} <: AbstractStates
    prior_model::T
    u0::K
    tspan::O
    datasize::S
    model_data::D
end

function Hybrid(prior_model, u0, tspan, datasize)
    trange = collect(range(tspan[1], tspan[2], length = datasize))
    dt = trange[2]-trange[1]
    tsteps = push!(trange, dt + trange[end])
    tspan_new = (tspan[1], dt+tspan[2])
    model_data = prior_model(u0, tspan_new, tsteps)
end

"""
    ESN(W::AbstractArray{T}, train_data::AbstractArray{T}, W_in::AbstractArray{T}
    [, activation::Any, alpha::T, nla_type::NonLinearAlgorithm, extended_states::Bool])

Build an ESN struct given the input and reservoir matrices.
"""
function ESN(input_res_size, train_data;
             input_init = WeightedInput(),
             reservoir_init = RandReservoir(),
             reservoir_driver = RNN(),
             nla_type = NLADefault(),
             states_type = StandardStates())

    states_type == Hybrid ? train_data = vcat(train_data, states_type.model_data[:, 1:end-1]) : nothing
    in_size = size(train_data, 1)
    input_matrix = create_layer(input_res_size, in_size, input_init)
    res_size = size(input_matrix, 1) #WeightedInput actually changes the res size
    reservoir_matrix = create_reservoir(res_size, reservoir_init)
    states = create_states(reservoir_driver, train_data, states_type, reservoir_matrix, input_matrix)

    ESN(res_size, train_data, nla_type, esn_type, input_matrix, reservoir_driver, 
        reservoir_matrix, states_type, states)
end

function (esn::ESN)(aut::Autonomous, output_layer::AbstractOutputLayer)

    output = obtain_autonomous_prediction(esn, output_layer, aut.prediction_len, 
                                          output_layer.training_method) #dispatch on prediction type -> just obtain_prediction()
    output
end

function (esn::ESN)(direct::Direct, output_layer::AbstractOutputLayer)

    output = obtain_direct_prediction(esn, output_layer, direct.prediction_data, 
                                      output_layer.training_method) 
    output
end

function (esn::ESN)(fitted::Fitted, output_layer::AbstractOutputLayer)
    if fitted.type == Direct
        output = obtain_direct_prediction(esn, output_layer, esn.train_data, 
                                          output_layer.training_method)
    elseif fitted.type == Autonomous #need to change actual starting state I think
        prediction_len = size(esn.states, 2)
        output = obtain_autonomous_prediction(esn, output_layer, prediction_len, 
                                              output_layer.training_method)
    end
    output
end
