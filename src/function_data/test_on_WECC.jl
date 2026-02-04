############## CALL THE DESIRED BRANCH OF InfrastructureSystems.jl ########################
# Install a specific branch of InfrastructureSystems.jl for testing
using Pkg
#Pkg.add(url="https://github.com/PabloBotinGP/InfrastructureSystems.jl", rev="pb/convex_checks-make_convex")
#Pkg.add(url="https://github.com/NREL-Sienna/InfrastructureSystems.jl", rev="jd/convex_checks")
Pkg.add(url="https://github.com/NREL-Sienna/InfrastructureSystems.jl", rev="jd/convex_checks")


               
using InfrastructureSystems
const IS = InfrastructureSystems
using PlotlyJS

include("test/thermal_test_ntp.jl")


# Collect all generators from the thermal standard system
gens = collect(get_components(ThermalStandard, sys))

#### Convexity Checking: is_convex & make_convex ########################

n_convex = 0
n_nonconvex = 0

for gen in gens
    println("Generator: ", gen.name)
    
    io_curve = gen.operation_cost.variable.value_curve
    @info "Input-Output / value curve: ", io_curve
    
    # Check convexity
    convex_status = IS.is_convex(io_curve)
    #@info "Generator $(gen.name) convexity" is_convex = IS.is_convex((io_curve))
    
    # Make convex 
    if !convex_status
        n_nonconvex += 1
        convex_curve = IS.make_convex(io_curve)
        @info "Convexified curve: ", convex_curve
    else
        n_convex += 1
        @info "Curve is already convex ✅."
    end

end

# ---------------- Summary table ----------------

using PrettyTables
summary_table = [
    "Convex curves"     n_convex
    "Non-convex curves" n_nonconvex
    "Total"             n_convex + n_nonconvex
]

pretty_table(
    summary_table;
    header = ["Category", "Count"],
    title = "Generator Cost Curve Convexity Summary"
)

#### Collinearity Checking ########################


# Helper function: check for consecutive colinear segments in a piecewise curve

"""
    has_colinear_segments(curve; ε=1e-6) -> Bool

Returns true if the curve contains consecutive colinear segments
that could be merged.
"""
function has_colinear_segments(
    curve::InputOutputCurve{PiecewiseLinearData};
    ε::Float64 = IS._COLINEARITY_TOLERANCE,
)
    slopes = get_slopes(get_function_data(curve))
    for i in 1:length(slopes)-1
        if abs(slopes[i+1] - slopes[i]) ≤ ε
            return true
        end
    end
    return false
end

# Compute fraction of points removable by merging colinear segments
"""
colinearity_reduction_ratio(curve::InputOutputCurve) -> Float64

Computes the fraction of points in a piecewise curve that could be removed
by merging consecutive colinear segments.

Returns a number between 0 and 1, where 0 means no reduction is possible
and 1 means all intermediate points could be removed (fully colinear).

# Arguments
- `curve`: An `InputOutputCurve` (typically with `PiecewiseLinearData`).
"""

function colinearity_reduction_ratio(curve)
    merged = IS.merge_colinear_segments(curve)
    n_orig = length(get_points(get_function_data(curve)))
    n_new  = length(get_points(get_function_data(merged)))
    return (n_orig - n_new) / max(n_orig - 1, 1)
end

# ----------- Collinearity and Convexity Summary ----------------
n_convex = 0
n_nonconvex = 0
n_colinear = 0

colinear_gens = String[]

for gen in gens
    io_curve = gen.operation_cost.variable.value_curve

    is_conv = IS.is_convex(io_curve)
    has_col = io_curve isa InputOutputCurve{PiecewiseLinearData} &&
              has_colinear_segments(io_curve)

    if is_conv
        n_convex += 1
    else
        n_nonconvex += 1
    end

    if has_col
        n_colinear += 1
        push!(colinear_gens, gen.name)
    end
end

summary_table = [
    "Convex curves"              n_convex
    "Non-convex curves"          n_nonconvex
    "Convex but colinear"        n_colinear
    "Total generators"           length(gens)
]

pretty_table(
    summary_table;
    header = ["Category", "Count"],
    title = "Generator Cost Curve Quality Summary"
)

#### Merging Colinear Segments & Reduction Ratios ####################
# Test of IS.merge_colinear_segments

ratios = Float64[]


for gen in gens
    io_curve = gen.operation_cost.variable.value_curve
    io_curve isa InputOutputCurve{PiecewiseLinearData} || continue

    pts = get_points(get_function_data(io_curve))
    length(pts) > 2 || continue   # skip trivial curves

    merged = IS.merge_colinear_segments(io_curve)

    n_orig = length(pts)
    n_new  = length(get_points(get_function_data(merged)))

    reduction = n_orig - n_new

    # ONLY keep curves where points were actually removed
    if reduction > 0
        push!(ratios, reduction / (n_orig - 1))
    end
end

#### Plot histogram of collinearity reduction ratios #################

trace = histogram(
    x = ratios,
    nbinsx = 25,
    marker = attr(
        color = "rgba(82, 133, 107, 0.7)",
        line = attr(color = "black", width = 1)
    )
)

layout = Layout(
    title = "Collinearity Reduction in Generator Cost Curves (WECC)",
    xaxis = attr(title = "Collinearity reduction ratio"),
    yaxis = attr(title = "Number of generators"),
    bargap = 0.05
)

fig = Plot(trace, layout)
display(fig)


## Plots of colinearity

using PlotlyJS
#### Example plot: single generator collinearity cleanup #################

gen = gens[findfirst(name -> name in colinear_gens, getfield.(gens, :name))]

orig  = gen.operation_cost.variable.value_curve
clean = IS.merge_colinear_segments(orig)

orig_pts  = get_points(get_function_data(orig))
clean_pts = get_points(get_function_data(clean))

x_orig = [p.x for p in orig_pts]
y_orig = [p.y for p in orig_pts]

x_clean = [p.x for p in clean_pts]
y_clean = [p.y for p in clean_pts]

trace_orig = scatter(
    x = x_orig,
    y = y_orig,
    mode = "lines+markers",
    name = "Original",
    marker = attr(size = 8),
    line = attr(width = 2)
)

trace_clean = scatter(
    x = x_clean,
    y = y_clean,
    mode = "lines+markers",
    name = "Merged",
    marker = attr(size = 8),
    line = attr(width = 2)
)

layout = Layout(
    title = "Collinearity Cleanup Example: $(gen.name)",
    grid = attr(rows = 1, columns = 2, pattern = "independent"),
    xaxis  = attr(title = "Input"),
    yaxis  = attr(title = "Cost"),
    xaxis2 = attr(title = "Input"),
    yaxis2 = attr(title = "Cost")
)

fig = Plot(
    [
        trace_orig,
        trace_clean
    ],
    layout
)

# Assign traces to subplots
fig.data[1][:xaxis] = "x"
fig.data[1][:yaxis] = "y"

fig.data[2][:xaxis] = "x2"
fig.data[2][:yaxis] = "y2"

display(fig)

##### Multiple generator collinearity cleanup plots ####################

idx = [2, 18, 75, 94, 108]
filtered = filter(g -> g.name in colinear_gens, gens)

selected_gens = filtered[idx]

traces = PlotlyJS.GenericTrace[]

for (i, gen) in enumerate(selected_gens)

    orig  = gen.operation_cost.variable.value_curve
    clean = IS.merge_colinear_segments(orig)

    orig_pts  = get_points(get_function_data(orig))
    clean_pts = get_points(get_function_data(clean))

    x_orig = [p.x for p in orig_pts]
    y_orig = [p.y for p in orig_pts]

    x_clean = [p.x for p in clean_pts]
    y_clean = [p.y for p in clean_pts]

    # Left column: original
    push!(traces, scatter(
        x = x_orig,
        y = y_orig,
        mode = "lines+markers",
        name = "Original – $(gen.name)",
        marker = attr(size = 7),
        line = attr(width = 2),
        xaxis = "x$(2i-1)",
        yaxis = "y$(2i-1)"
    ))

    # Right column: cleaned
    push!(traces, scatter(
        x = x_clean,
        y = y_clean,
        mode = "lines+markers",
        name = "Merged – $(gen.name)",
        marker = attr(size = 7),
        line = attr(width = 2, dash = "dash"),
        xaxis = "x$(2i)",
        yaxis = "y$(2i)"
    ))
end

layout = Layout(
    title = "Collinearity Cleanup — Original vs Merged (5 Generators)",
    grid = attr(
        rows = 5,
        columns = 2,
        pattern = "independent"
    ),
    showlegend = false,
    height = 1400,
    width = 1000
)

fig = Plot(traces, layout)
display(fig)

#### Validity Checking of Generator Curves ########################

n_valid = 0
n_nonvalid = 0

for gen in gens
    println("Generator: ", gen.name)
    
    # Get the value curve (already an InputOutputCurve)
    io_curve = gen.operation_cost.variable.value_curve
    @info "Input-Output / value curve: ", io_curve
    
    # Check if valid
    valid_status = IS.is_valid_data(io_curve)

    if !valid_status
        n_nonvalid += 1
        
        @info "non valid: ", io_curve
    else
        n_valid += 1
        @info "Curve is valid ✅."
    end

end

# ---------------- Summary table ----------------
summary_table = [
    "Valid curves"     n_valid
    "Non-valid curves" n_nonvalid
    "Total"             n_valid + n_nonvalid
]

pretty_table(
    summary_table;
    header = ["Category", "Count"],
    title = "Generator Cost Curve Valid Summary"
)

# Collect indices of failing and non-failing generators
failed_idx = Int[]  # store indices of failing gens
nonfailed_idx = Int[]  # store indices of non failing gens

for (i, gen) in enumerate(gens)
    io_curve = gen.operation_cost.variable.value_curve
    if !IS.is_valid_data(io_curve)
        push!(failed_idx, i)
    end
end

println("Found $(length(failed_idx)) invalid generators")

# Test validity using incremental curves
failed_idx_ic = Int[] 

for (i, gen) in enumerate(gens)
    ic_curve = IncrementalCurve(gen.operation_cost.variable.value_curve)
    if !IS.is_valid_data(ic_curve)
        push!(failed_idx_ic, i)
    end
end

println("Found $(length(failed_idx)) invalid generators in WECC by cheking IO curves")
println("Found $(length(failed_idx_ic)) invalid generators in WECC by cheking Heat rates")


for (i, gen) in enumerate(gens)
    io_curve = gen.operation_cost.variable.value_curve
    if IS.is_valid_data(io_curve)
        push!(nonfailed_idx, i)
    end
end



println("Found $(length(nonfailed_idx)) valid generators")

#### Plot examples of invalid curves ########################

examples_idx = failed_idx[1:min(5, length(failed_idx))]  # first 5 invalid gens
examples_idx_valid = failed_idx[1:min(5, length(nonfailed_idx))]
invalid_gens = gens[examples_idx]

traces = PlotlyJS.GenericTrace[]

for (i, gen) in enumerate(invalid_gens)

    orig = gen.operation_cost.variable.value_curve
    #clean = IS.merge_colinear_segments(orig)  # optional, can skip if just plotting raw

    orig_pts = get_points(get_function_data(orig))
    #clean_pts = get_points(get_function_data(clean))

    x_orig = [p.x for p in orig_pts]
    y_orig = [p.y for p in orig_pts]

    #x_clean = [p.x for p in clean_pts]
    #y_clean = [p.y for p in clean_pts]

    # original
    push!(traces, scatter(
        x = x_orig,
        y = y_orig,
        mode = "lines+markers",
        name = "Original – $(gen.name)",
        marker = attr(size = 7),
        line = attr(width = 2),
        xaxis = "x$(2i-1)",
        yaxis = "y$(2i-1)"
    ))

    # merged / cleaned (optional)
    #=push!(traces, scatter(
        x = x_clean,
        y = y_clean,
        mode = "lines+markers",
        name = "Merged – $(gen.name)",
        marker = attr(size = 7),
        line = attr(width = 2, dash = "dash"),
        xaxis = "x$(2i)",
        yaxis = "y$(2i)"
    ))=#
end

layout = Layout(
    title = "Invalid Generator Cost Curves",
    grid = attr(rows = length(selected_gens), columns = 2, pattern = "independent"),
    showlegend = false,
    height = 1400,
    width = 1000
)

fig = Plot(traces, layout)
display(fig)


