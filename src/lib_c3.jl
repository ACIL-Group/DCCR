using AdaptiveResonance

using StatsBase
# using Statistics

using Logging
# using HDF5              # Loading .h5 activation files

using DelimitedFiles

using MLBase        # confusmat
# using DrWatson
using MLDataUtils   # stratifiedobs
using StatsPlots    # groupedbar
using DataFrames
using Printf

# Add the custom colors definitions
include("colors.jl")

# -----------------------------------------------------------------------------
# ALIASES
# -----------------------------------------------------------------------------
#   **Taken from StatsBase.jl**
#
#  These types signficantly reduces the need of using
#  type parameters in functions (which are often just
#  for the purpose of restricting the arrays to real)
#
# These could be removed when the Base supports
# covariant type notation, i.e. AbstractVector{<:Real}

# Real-numbered aliases
const RealArray{T<:Real, N} = AbstractArray{T, N}
const RealVector{T<:Real} = AbstractArray{T, 1}
const RealMatrix{T<:Real} = AbstractArray{T, 2}

# Integered aliases
const IntegerArray{T<:Integer, N} = AbstractArray{T, N}
const IntegerVector{T<:Integer} = AbstractArray{T, 1}
const IntegerMatrix{T<:Integer} = AbstractArray{T, 2}

# Specifically floating-point aliases
const RealFP = Union{Float32, Float64}

# System's largest native floating point variable
const Float = (Sys.WORD_SIZE == 64 ? Float64 : Float32)

# -----------------------------------------------------------------------------
# METHODS
# -----------------------------------------------------------------------------

"""
    sigmoid(x::Real)

Return the sigmoid function on x.
"""
function sigmoid(x::Real)
# return 1.0 / (1.0 + exp(-x))
    return one(x) / (one(x) + exp(-x))
end

"""
    collect_activations(data_dir::String)

Return the activations from a single directory
"""
function collect_activations(data_dir::String)
    data_full = readdlm(joinpath(data_dir, "average_features.csv"), ',')
    return data_full
end

"""
    collect_all_activations(data_dirs::Array, cell::Int)

Return just the yolo activations from a list of data directories.
"""
function collect_all_activations(data_dirs::Array, cell::Int)
    data_grand = []
    for data_dir in data_dirs
        data_dir_full = joinpath(data_dir, string(cell))
        data_full = collect_activations(data_dir_full)
        # If the full data struct is empty, initialize with the size of the data
        if isempty(data_grand)
            data_grand = Array{Float64}(undef, size(data_full)[1], 1)
        end
        data_grand = [data_grand data_full]
    end
    return data_grand
end

"""
    collect_all_activations_labeled(data_dirs::Vector{String}, cell::Int)

Return the yolo activations, training targets, and condensed labels list from a list of data directories.
"""
function collect_all_activations_labeled(data_dirs::Vector{String}, cell::Int)
    top_dim = 128*cell
    data_grand = Matrix{Float64}(undef, top_dim, 0)
    targets = Vector{Int64}()
    labels = Vector{String}()
    # for data_dir in data_dirs
    for i = 1:length(data_dirs)
        # Get the full local data directory
        data_dir = data_dirs[i]
        data_dir_full = joinpath(data_dir, string(cell))

        # Assign the directory as the label
        push!(labels, basename(data_dir))

        # Get all of the data from the full data directory
        data_full = collect_activations(data_dir_full)
        dim, n_samples = size(data_full)

        # If the full data struct is empty, initialize with the size of the data
        if isempty(data_grand)
            data_grand = Array{Float64}(undef, dim, 0)
        end

        # Set the labeled targets
        for j = 1:n_samples
            push!(targets, i)
        end

        # Concatenate the most recent batch with the grand dataset
        data_grand = [data_grand data_full]
    end
    return data_grand, targets, labels
end

"""
    get_dist(data::RealMatrix)

Get the distribution parameters for preprocessing.
"""
function get_dist(data::RealMatrix)
    return fit(ZScoreTransform, data, dims=2)
end

"""
    function_preprocess(dt::ZScoreTransform, scaling::Real, data::RealMatrix)

Preprocesses one dataset of features, scaling and squashing along the feature axes.
"""
function feature_preprocess(dt::ZScoreTransform, scaling::Real, data::RealMatrix)
    new_data = StatsBase.transform(dt, data)
    new_data = sigmoid.(scaling*new_data)
    return new_data
end

"""
    DataSplit

A basic struct for encapsulating the components of supervised training.
"""
mutable struct DataSplit

    train_x::RealMatrix
    train_y::IntegerVector
    train_labels::Vector{String}

    val_x::RealMatrix
    val_y::IntegerVector
    val_labels::Vector{String}

    test_x::RealMatrix
    test_y::RealVector
    test_labels::Vector{String}

    DataSplit(
        train_x,
        train_y,
        train_labels,
        val_x,
        val_y,
        val_labels,
        test_x,
        test_y,
        test_labels
    ) = new(
        train_x,
        train_y,
        train_labels,
        val_x,
        val_y,
        val_labels,
        test_x,
        test_y,
        test_labels
    )
end

"""
    DataSplitIndexed

A basic struct for encapsulating the components of supervised training.
"""
mutable struct DataSplitIndexed
    train_x::Vector{RealMatrix}
    train_y::Vector{IntegerVector}
    train_labels::Vector{String}

    val_x::Vector{RealMatrix}
    val_y::Vector{IntegerVector}
    val_labels::Vector{String}

    test_x::Vector{RealMatrix}
    test_y::Vector{IntegerVector}
    test_labels::Vector{String}
end

"""
    load_orbits(data_dir::String, scaling::Real)

Load the orbits data and preprocess the features.
"""
function load_orbits(data_dir::String, scaling::Real)
    train_dir = joinpath(data_dir, "LBs")
    val_dir = joinpath(data_dir, "Val")
    test_dir = joinpath(data_dir, "EBs")

    train_data_dirs = [joinpath(train_dir, data_dir) for data_dir in data_dirs]
    val_data_dirs = [joinpath(val_dir, data_dir) for data_dir in data_dirs]
    test_data_dirs = [joinpath(test_dir, data_dir) for data_dir in data_dirs]

    train_x, train_y, train_labels = collect_all_activations_labeled(train_data_dirs, 1)
    val_x, val_y, val_labels = collect_all_activations_labeled(train_data_dirs, 1)
    test_x, test_y, test_labels = collect_all_activations_labeled(test_data_dirs, 1)

    dt = get_dist(train_x)

    train_x = feature_preprocess(dt, scaling, train_x)
    test_x = feature_preprocess(dt, scaling, test_x)

    data_struct = DataSplit(
        train_x,
        train_y,
        train_labels,
        val_x,
        val_y,
        val_labels,
        test_x,
        test_y,
        test_labels
    )

    return data_struct
    # return X_train, y_train, train_labels, X_test, y_test, test_labels
end

"""
    get_indexed_data(data::DataSplit)

Create a DataSplitIndexed object from a DataSplit.
"""
function get_indexed_data(data::DataSplit)
    # Assume the same number of classes in each category
    n_classes = length(unique(data.train_y))

    # data_indexed =
    train_x = Vector{RealMatrix}()
    train_y = Vector{IntegerVector}()
    train_labels = Vector{String}()
    val_x = Vector{RealMatrix}()
    val_y = Vector{IntegerVector}()
    val_labels = Vector{String}()
    test_x = Vector{RealMatrix}()
    test_y = Vector{IntegerVector}()
    test_labels = Vector{String}()

    for i = 1:n_classes
        i_train = findall(x -> x == i, data.train_y)
        push!(train_x, data.train_x[:, i_train])
        push!(train_y, data.train_y[i_train])
        i_val = findall(x -> x == i, data.val_y)
        push!(val_x, data.val_x[:, i_val])
        push!(val_y, data.val_y[i_val])
        i_test = findall(x -> x == i, data.test_y)
        push!(test_x, data.test_x[:, i_test])
        push!(test_y, data.test_y[i_test])
    end

    train_labels = data.train_labels
    val_labels = data.val_labels
    test_labels = data.test_labels

    # Construct the indexed data split
    data_indexed = DataSplitIndexed(
        train_x,
        train_y,
        train_labels,
        val_x,
        val_y,
        val_labels,
        test_x,
        test_y,
        test_labels
    )
    return data_indexed
end

"""
    get_deindexed_data(data::DataSplitIndexed, order::IntegerVector)

Turn a DataSplitIndexed into a DataSplit with the given train/test order.
"""
function get_deindexed_data(data::DataSplitIndexed, order::IntegerVector)
    dim = 128
    train_x = Array{Float64}(undef, dim, 0)
    train_y = Array{Int}(undef, 0)
    train_labels = Vector{String}()

    val_x = Array{Float64}(undef, 128, 0)
    val_y = Array{Int}(undef, 0)
    val_labels = Vector{String}()

    test_x = Array{Float64}(undef, 128, 0)
    test_y = Array{Int}(undef, 0)
    test_labels = Vector{String}()

    for i in order
        train_x = hcat(train_x, data.train_x[i])
        train_y = vcat(train_y, data.train_y[i])
        val_x = hcat(val_x, data.val_x[i])
        val_y = vcat(val_y, data.val_y[i])
        test_x = hcat(test_x, data.test_x[i])
        test_y = vcat(test_y, data.test_y[i])
    end

    train_labels = data.train_labels[order]
    val_labels = data.val_labels[order]
    test_labels = data.test_labels[order]

    data_struct = DataSplit(
        train_x,
        train_y,
        train_labels,
        val_x,
        val_y,
        val_labels,
        test_x,
        test_y,
        test_labels
    )

    return data_struct
end

"""
    get_orbit_names(selection::Vector{String})

Map the experiment orbit names to their data directories and plotting class labels.
"""
function get_orbit_names(selection::Vector{String})
    # Data directory names
    data_dirs = Dict(
        "dot_dusk" => "dot_dusk",
        "dot_morning" => "dot_morning",
        "emahigh_dusk" => "emahigh_dusk",
        "emahigh_morning" => "emahigh_morning",
        "emalow_dusk" => "emalow_dusk",
        "emalow_morning" => "emalow_morning",
        "pr_dusk" => "pr_dusk",
        "pr_morning" => "pr_morning",
    )

    # Class labels for plotting
    class_labels = Dict(
        "dot_dusk" => "DOTD",
        "dot_morning" => "DOTM",
        "emahigh_dusk" => "EMAHD",
        "emahigh_morning" => "EMAHM",
        "emalow_dusk" => "EMALD",
        "emalow_morning" => "EMALM",
        "pr_dusk" => "PRD",
        "pr_morning" => "PRM",
    )

    # Create the output lists
    out_data_dirs = String[]
    out_class_labels = String[]
    for item in selection
        push!(out_data_dirs, data_dirs[item])
        push!(out_class_labels, class_labels[item])
    end

    return out_data_dirs, out_class_labels
end

"""
    get_confusion(y::IntegerVector, y_hat::IntegerVector, n_classes::Int)

Wrapper method for getting the raw confusion matrix.
"""
function get_confusion(y::IntegerVector, y_hat::IntegerVector, n_classes::Int)
    return confusmat(n_classes, y, y_hat)
end

"""
    get_normalized_confusion(y::IntegerVector, y_hat::IntegerVector, n_classes::Int)

Get the normalized confusion matrix.
"""
function get_normalized_confusion(y::IntegerVector, y_hat::IntegerVector, n_classes::Int)
    cm = get_confusion(y, y_hat, n_classes)
    total = sum(cm, dims=1)
    norm_cm = cm./total
    return norm_cm
end

"""
    get_accuracies(y::IntegerVector, y_hat::IntegerVector, n_classes::Int)

Get a list of the percentage accuracies.
"""
function get_accuracies(y::IntegerVector, y_hat::IntegerVector, n_classes::Int)
    cm = get_confusion(y, y_hat, n_classes)
    correct = [cm[i,i] for i = 1:n_classes]
    total = sum(cm, dims=1)
    accuracies = correct'./total

    return accuracies
end

"""
    get_tt_accuracies(data::DataSplit, y_hat_train::IntegerVector, y_hat::IntegerVector, n_classes::Int)

Get two lists of the training and testing accuracies
"""
function get_tt_accuracies(data::DataSplit, y_hat_train::IntegerVector, y_hat::IntegerVector, n_classes::Int)
    # TRAIN: Get the percent correct for each class
    train_accuracies = get_accuracies(data.train_y, y_hat_train, n_classes)

    # TEST: Get the percent correct for each class
    test_accuracies = get_accuracies(data.test_y, y_hat, n_classes)

    return train_accuracies, test_accuracies
end

"""
    get_n_categories(ddvfa::DDVFA)

Returns both the number of F2 categories and total number of weights per class as two lists.
"""
function get_n_categories(ddvfa::DDVFA)
    # Save the number of F2 nodes and total categories per class
    n_F2 = Int[]
    n_categories = Int[]

    # Iterate over every class
    for i = 1:n_classes
        # Find all of the F2 nodes that correspond to the class
        i_F2 = findall(x->x==i, ddvfa.labels)
        # Add the number of F2 nodes to the list
        push!(n_F2, length(i_F2))
        # Get the numbers of categories within each F2 node
        n_cat_list = [F2.n_categories for F2 in ddvfa.F2[i_F2]]
        # Sum those and add them to the list
        push!(n_categories, sum(n_cat_list))
    end

    return n_F2, n_categories
end

"""
    get_manual_split(data::RealMatrix, targets::IntegerVector)

Wrapper, returns a manual train/test x/y split from a data matrix and labels using MLDataUtils.
"""
function get_manual_split(data::RealMatrix, targets::IntegerVector)
    (X_train, y_train), (X_test, y_test) = stratifiedobs((data, targets))
    return (X_train, y_train), (X_test, y_test)
end

"""
    df_column_to_matrix(df::DataFrame, row::Symbol)

Convert a column of lists in a DataFrame into a matrix for analysis.
"""
function df_column_to_matrix(df::DataFrame, row::Symbol)
    lists = df[!, row]
    n_samples = length(lists)
    n_classes = length(lists[1])
    matrix = zeros(n_samples, n_classes)
    for i = 1:n_samples
        matrix[i, :] = lists[i]
    end
    return matrix
end

# -----------------------------------------------------------------------------
# PLOTTING
# -----------------------------------------------------------------------------

# """
#     create_confusion_heatmap_old(class_labels::Vector{String}, y::IntegerVector, y_hat::IntegerVector)

# Returns a handle to a labeled and annotated heatmap plot of the confusion matrix.
# """
# function create_confusion_heatmap_old(class_labels::Vector{String}, y::IntegerVector, y_hat::IntegerVector)
#     # Number of classes from the class labels
#     n_classes = length(class_labels)

#     # Normalized confusion
#     norm_cm = get_normalized_confusion(y, y_hat, n_classes)

#     # Transpose reflect
#     plot_cm = norm_cm'

#     # Create the heatmap
#     h = heatmap(
#         class_labels,
#         class_labels,
#         plot_cm,
#         fill_z = norm_cm,
#         aspect_ratio=:equal,
#         color = cgrad(GRADIENTSCHEME),
#         fontfamily=FONTFAMILY,
#         annotationfontfamily=FONTFAMILY,
#         size=SQUARE_SIZE,
#         dpi=DPI
#     )

#     # Create the annotations
#     fontsize = 10
#     nrow, ncol = size(norm_cm)
#     ann = [
#         (
#             i-.5,
#             j-.5,
#             text(
#                 round(plot_cm[i,j], digits=2),
#                 fontsize,
#                 FONTFAMILY,
#                 :white,
#                 :center,
#             )
#         )
#         for i in 1:nrow for j in 1:ncol
#     ]

#     # Add the cell annotations
#     annotate!(
#         ann,
#         linecolor=:white,
#         # linecolor=:black,
#         fontfamily=FONTFAMILY,
#     )

#     # Label truth and predicted axes
#     xlabel!("Predicted")
#     ylabel!("Truth")

#     # Return the plot handle for display or saving
#     return h
# end

"""
    create_confusion_heatmap(class_labels::Vector{String}, y::IntegerVector, y_hat::IntegerVector)

Returns a handle to a labeled and annotated heatmap plot of the confusion matrix.
"""
function create_confusion_heatmap(class_labels::Vector{String}, y::IntegerVector, y_hat::IntegerVector)
    # Number of classes from the class labels
    n_classes = length(class_labels)
    # Normalized confusion
    norm_cm = get_normalized_confusion(y, y_hat, n_classes)
    # Transpose reflect
    plot_cm = reverse(norm_cm', dims=1)
    # Convert to percentages
    plot_cm *= 100.0
    # Transpose the y labels
    x_labels = class_labels
    y_labels = reverse(class_labels)

    # Create the heatmap
    h = heatmap(
        x_labels,
        y_labels,
        plot_cm,
        fill_z = norm_cm,
        aspect_ratio=:equal,
        color = cgrad(GRADIENTSCHEME),
        fontfamily=FONTFAMILY,
        annotationfontfamily=FONTFAMILY,
        size=SQUARE_SIZE,
        dpi=DPI
    )

    # Create the annotations
    fontsize = 10
    nrow, ncol = size(norm_cm)
    ann = [
        (
            i-.5,
            j-.5,
            text(
                round(plot_cm[j,i], digits=2),
                fontsize,
                FONTFAMILY,
                :white,
                :center,
            )
        )
        for i in 1:nrow for j in 1:ncol
    ]

    # Add the cell annotations
    annotate!(
        ann,
        linecolor=:white,
        # linecolor=:black,
        fontfamily=FONTFAMILY,
    )

    # Label truth and predicted axes
    xlabel!("Predicted")
    ylabel!("Truth")

    # Return the plot handle for display or saving
    return h
end

"""
    create_accuracy_groupedbar(data, y_hat_train, y_hat, class_labels)

Return a grouped bar chart with class accuracies.
"""
function create_accuracy_groupedbar(data, y_hat_train, y_hat, class_labels ; percentages=false)
    # Infer the number of classes from the class labels
    n_classes = length(class_labels)

    # Get the training and testing accuracies
    train_accuracies, test_accuracies = get_tt_accuracies(data, y_hat_train, y_hat, n_classes)
    @info "Train Accuracies:" train_accuracies
    @info "Train Accuracies:" test_accuracies

    # Format the accuracy series for plotting
    combined_accuracies = [train_accuracies; test_accuracies]'

    # Convert to percentages
    y_formatter = percentages ? percentage_formatter : :auto

    # Create the accuracy grouped bar chart
    p = groupedbar(
        combined_accuracies,
        bar_position = :dodge,
        bar_width=0.7,
        color_palette=COLORSCHEME,
        fontfamily=FONTFAMILY,
        legend_position=:outerright,
        labels=["Training" "Testing"],
        dpi=DPI,
        yformatter = y_formatter,
        # yformatter = j -> @sprintf("%0.0f%%", 100*j),
        # show=true,
        # xticks=train_labels
    )

    ylabel!(p, "Class Accuracy")
    # yticklabels(j -> @sprintf("%0.0f%%", 100*j))
    xticks!(collect(1:n_classes), class_labels)
    # title!(p, "test")

    return p
end

"""
    create_boxplot(data::RealMatrix, class_labels::Vector{String})

Return a colored and formatted boxplot of the data.
"""
function create_boxplot(data::RealMatrix, class_labels::Vector{String} ; percentages=false)
    # Get the number of sample vectors
    n_samples = size(n_w_matrix)[1]
    # Vectorize the data along the columns
    new_matrix = vec(data)
    # Convert to percentages
    y_formatter = percentages ? percentage_formatter : :auto
    # Label each sample with an inner-repeated label list
    new_labels = repeat(class_labels, inner=n_samples)
    # Create a dataframe with each sample and class label
    df = DataFrame([new_matrix, new_labels], ["n_w", "class"])

    # Create a violin plot
    p = @df df violin(
        :class,
        :n_w,
        linewidth=0,
        color_palette=COLORSCHEME,
        fontfamily=FONTFAMILY,
        legend=false,
        dpi=DPI,
        yformatter=y_formatter,
    )

    # Overlay a transparent box plot
    @df df boxplot!(
        :class,
        :n_w,
        fillalpha=0.75,
        linewidth=2,
        color_palette=COLORSCHEME,
        # fontfamily=FONTFAMILY,
        legend=false,
        dpi=DPI
    )

    # Add the universal x-label
    xlabel!("Class")

    return p
end

"""
    create_condensed_plot(y_hat, class_labels)

Create and return a simplified condensed scenario plot.
"""
function create_condensed_plot(perfs, class_labels, percentages=true)
    # Add initial testing block to labels
    local_labels = cat("", class_labels, dims=1)
    println(local_labels)
    # local_labels = reshape(local_labels, 1, length(local_labels))

    # Convert to percentages
    # plot_perfs = perfs * 100.0;
    y_formatter = percentages ? percentage_formatter : :auto

    p = plot(
        # plot_perfs,
        perfs,
        linestyle = [:dot :dash :dashdot :solid :dot :dashdotdot],
        # linestyle = :auto,
        linewidth = 3,
        # thickness_scaling = 1,
        color_palette=COLORSCHEME,
        labels=reshape(class_labels, 1, length(class_labels)),
        # legend=:topleft,
        fontfamily=FONTFAMILY,
        legend=:outerright,
        yformatter=y_formatter,
        # legendlinewidth=10,
        dpi=DPI,
    )

    xlabel!("Training Class")
    ylabel!("Testing Accuracy")
    xticks!(collect(1:length(local_labels)), local_labels)

    return p
end

# -----------------------------------------------------------------------------
# EXPERIMENTS
# -----------------------------------------------------------------------------

"""
    shuffled_mc(d::Dict, data::DataSplit, opts::opts_DDVFA)

Runs a single Monte Carlo simulation of training/testing on shuffled samples.
"""
function shuffled_mc(d::Dict, data::DataSplit, opts::opts_DDVFA)
    # Infer the number of classes
    n_classes = length(unique(data.train_y))

    # Get the random seed for the experiment
    seed = d["seed"]

    # Create the DDVFA module and setup the config
    ddvfa = DDVFA(opts)
    ddvfa.opts.display = false
    ddvfa.config = DataConfig(0, 1, 128)

    # Shuffle the data with a new random seed
    Random.seed!(seed)
    i_train = randperm(length(data.train_y))
    data.train_x = data.train_x[:, i_train]
    data.train_y = data.train_y[i_train]

    # Train and test in batch
    y_hat_train = train!(ddvfa, data.train_x, y=data.train_y)
    y_hat = AdaptiveResonance.classify(ddvfa, data.test_x, get_bmu=true)

    # Calculate performance on training data, testing data, and with get_bmu
    train_perf = performance(y_hat_train, data.train_y)
    test_perf = performance(y_hat, data.test_y)

    # Save the number of F2 nodes and total categories per class
    n_F2, n_categories = get_n_categories(ddvfa)
    n_F2_sum = sum(n_F2)
    n_categories_sum = sum(n_categories)

    # Get the normalized confusion Matrix
    norm_cm = get_normalized_confusion(data.test_y, y_hat, n_classes)

    # Get the train/test accuracies
    train_accuracies, test_accuracies = get_tt_accuracies(data, y_hat_train, y_hat, n_classes)

    # Deepcopy the simulation dict and add results entries
    fulld = deepcopy(d)
    fulld["p_tr"] = train_perf
    fulld["p_te"] = test_perf
    fulld["n_F2"] = n_F2
    fulld["n_w"] = n_categories
    fulld["n_F2_sum"] = n_F2_sum
    fulld["n_w_sum"] = n_categories_sum
    fulld["norm_cm"] = norm_cm
    fulld["a_tr"] = train_accuracies
    fulld["a_te"] = test_accuracies

    # Save the results dictionary
    sim_save_name = sweep_results_dir(savename(d, "jld2"))
    @info "Worker $(myid()): saving to $(sim_save_name)"
    # wsave(sim_save_name, f)
    tagsave(sim_save_name, fulld)
end

"""
    permuted(d::Dict, data::DataSplit, opts::opts_DDVFA)

Runs a single Monte Carlo simulation of training/testing on shuffled samples.
"""
function permuted(d::Dict, data_indexed::DataSplitIndexed, opts::opts_DDVFA)
    # Get the train/test order for the experiment
    order = d["order"]

    # Create the DDVFA module and setup the config
    ddvfa = DDVFA(opts)
    ddvfa.opts.display = false
    ddvfa.config = DataConfig(0, 1, 128)

    # Get a deindexed dataset with the indexed order
    data = get_deindexed_data(data_indexed, order)

    # Train and test in batch
    y_hat_train = train!(ddvfa, data.train_x, y=data.train_y)
    y_hat = AdaptiveResonance.classify(ddvfa, data.test_x, get_bmu=true)

    # Calculate performance on training data, testing data, and with get_bmu
    train_perf = performance(y_hat_train, data.train_y)
    test_perf = performance(y_hat, data.test_y)

    # Save the number of F2 nodes and total categories per class
    n_F2, n_categories = get_n_categories(ddvfa)
    n_F2_sum = sum(n_F2)
    n_categories_sum = sum(n_categories)

    # Get the normalized confusion Matrix
    norm_cm = get_normalized_confusion(data.test_y, y_hat, n_classes)

    # Get the train/test accuracies
    train_accuracies, test_accuracies = get_tt_accuracies(data, y_hat_train, y_hat, n_classes)

    # Deepcopy the simulation dict and add results entries
    fulld = deepcopy(d)
    fulld["p_tr"] = train_perf
    fulld["p_te"] = test_perf
    fulld["n_F2"] = n_F2
    fulld["n_w"] = n_categories
    fulld["n_F2_sum"] = n_F2_sum
    fulld["n_w_sum"] = n_categories_sum
    fulld["norm_cm"] = norm_cm
    fulld["a_tr"] = train_accuracies
    fulld["a_te"] = test_accuracies

    # Save the results dictionary
    sim_save_name = sweep_results_dir(savename(d, "jld2"))
    @info "Worker $(myid()): saving to $(sim_save_name)"
    # wsave(sim_save_name, f)
    tagsave(sim_save_name, fulld)
end