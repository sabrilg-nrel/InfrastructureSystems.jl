############## CALL THE DESIRED BRANCH OF InfrastructureSystems.jl ########################
# Install a specific branch of InfrastructureSystems.jl for testing
using Pkg
#Pkg.add(url="https://github.com/PabloBotinGP/InfrastructureSystems.jl", rev="pb/convex_checks-make_convex")
#Pkg.add(url="https://github.com/NREL-Sienna/InfrastructureSystems.jl", rev="jd/convex_checks")
Pkg.add(url="https://github.com/NREL-Sienna/InfrastructureSystems.jl", rev="jd/convex_checks")



using Revise
using Test
using CSV
# using WECC
using PowerSystems
using Logging
using DataFrames
using PowerSystemCaseBuilder
using Dates
const PSY = PowerSystems
using TimeSeries
using InfrastructureSystems
const IS = InfrastructureSystems
using PlotlyJS


# Convex toy examples
ioc = PiecewisePointCurve([(1.0, 4.0), (2.0, 6.0), (3.0, 10.0)])
ic = IncrementalCurve(ioc) #slopes f'(x)
ioc_b = InputOutputCurve(ic)
ioc_q = QuadraticCurve(0.001, 15.772, 0.0)

ioc
IS.is_convex(ioc)
IS.make_convex(ioc)

ic
IS.is_convex(ic)
IS.make_convex(ic)

ioc_b
IS.is_convex(ioc_b)
IS.make_convex(ioc_b)

ioc_q
IS.is_convex(ioc_q)
IS.make_convex(ioc_q)


# Non convex

# Piecewise linear InputOutputCurv

points = [
    (x=0.0, y=0.0),
    (x=1.0, y=2.0),
    (x=2.0, y=1.0),  # dip here → non-convex
    (x=3.0, y=3.0),
    (x=4.0, y=5.0)
]

pwldata = PiecewiseLinearData(points)
curve = InputOutputCurve(pwldata)

println("Is convex? ", is_convex(curve))
convex_curve = IS.make_convex(curve)


# Incremental curve

x_coords = [0.0, 1.0, 2.0, 3.0]
y_coords = [6.0, 2.0, 4.0]  # decreasing then increasing

ps_nc = PiecewiseStepData(x_coords, y_coords)
ic_nc = IncrementalCurve(ps_nc, 0.0, 0.0)

IS.is_convex(ic_nc)
IS.make_convex(ic_nc)

# PiecewisePointCurve
ioc_nc = PiecewisePointCurve([
    (1.0, 1.0),
    (2.0, 6.0),
    (3.0, 8.0),
])

IS.is_convex(ioc_nc)
convex_ic = IS.make_convex(ic_nc)

# Concave (non-convex) quadratic: a < 0
q_nc = QuadraticCurve(-0.5, 4.0, 1.0)

IS.is_convex(q_nc)
q_conv = IS.make_convex(q_nc)
IS.make_convex(q_nc)

# Plot
# Extract points for plotting
function plot_pair(x_orig, y_orig, x_conv, y_conv;
    name,
    color)

orig = scatter(
x = x_orig,
y = y_orig,
mode = "lines+markers",
name = "$name (original)",
line = attr(color = color, dash = "solid"),
marker = attr(size = 8)
)

conv = scatter(
x = x_conv,
y = y_conv,
mode = "lines",
name = "$name (convexified)",
line = attr(color = color, dash = "dash", width = 3)
)

return orig, conv
end

function curve_points(curve; n=100)
    # InputOutputCurve / PiecewisePointCurve
    if curve isa InputOutputCurve
        data = get_function_data(curve)
        xmin = first(get_x_coords(data))
        xmax = last(get_x_coords(data))

    # Quadratic / Linear curves
    elseif curve isa AbstractCurve
        xmin = 0.0
        xmax = 5.0

    else
        throw(ArgumentError("Unsupported curve type $(typeof(curve))"))
    end

    xs = range(xmin, xmax; length=n)
    ys = [curve(x) for x in xs]
    return collect(xs), ys
end

function incremental_points(curve::IncrementalCurve)
    io = InputOutputCurve(curve)
    return curve_points(io)
end

# Original
x_nco, y_nco = incremental_points(ic_nc)


# Convexified
convex_curve = IS.make_convex(curve)
x_nc,  y_nc  = incremental_points(IS.make_convex(ic_nc))

t1, t2 = plot_pair(
    x_o, y_o,
    x_c, y_c;
    name = "Input–Output",
    color = "crimson"
)

x_nco, y_nco = curve_points(ic_nc)
x_nc, y_nc = curve_points(IS.make_convex(ic_nc))

t3, t4 = plot_pair(
    x_nco, y_nco,
    x_nc, y_nc;
    name = "Incremental",
    color = "royalblue"
)

x_qo, y_qo = curve_points(q_nc; xmin=0.0, xmax=5.0)
x_qc, y_qc = curve_points(q_conv; xmin=0.0, xmax=5.0)

t5, t6 = plot_pair(
    x_qo, y_qo,
    x_qc, y_qc;
    name = "Quadratic",
    color = "darkgreen"
)

# ---- Plot everything ----
plot(
    [t1, t2, t3, t4, t5, t6],
    Layout(
        title = "Non-Convex vs Convexified Curves",
        xaxis_title = "Capacity / x",
        yaxis_title = "Fuel / Cost / Heat Rate",
        legend = attr(orientation = "h")
    )
)




logger = configure_logging(; console_level=Logging.Info)

sys = PSY.System(joinpath("/Users/sabrilg/Documents/GitHub/InfrastructureSystems.jl/convex_test/DA_sys_2.json"))

gens = collect(get_components(ThermalStandard, sys))

#=
for gen in gens
    println("Generator: ", gen.name)
    
    # The operation cost curve
    cost_curve = gen.operation_cost.variable
    println(cost_curve)
    
    # Check convexity
    @info "Generator $(gen.name) convexity" IS.is_convex = is_convex(get_function_data(cost_curve))
    
    # Make convex if needed
    convex_curve = IS.make_convex(InputOutputCurve(cost_curve))
    println("Convexified curve:")
    println(convex_curve)
    
    #println("------")
end
=#

for gen in gens
    println("Generator: ", gen.name)
    
    # Get the value curve (already an InputOutputCurve)
    io_curve = gen.operation_cost.variable.value_curve
    println("Input-Output / value curve: ", io_curve)
    
    # Check convexity
    @info "Generator $(gen.name) convexity" is_convex = IS.is_convex(io_curve)

    
    # Make convex 
    #convex_curve = IS.make_convex((io_curve))
    #println("Convexified curve: ", convex_curve)

end

################### Examples with all kind of curves on Multiple dispatch ############

# InputOutputCurve — PiecewiseLinearData

ioc_convex = InputOutputCurve(
    PiecewiseLinearData([
        (x=0.0, y=0.0),
        (x=1.0, y=1.0),
        (x=2.0, y=3.0),
        (x=3.0, y=6.0),
    ])
)

ioc_nonconvex = InputOutputCurve(
    PiecewiseLinearData([
        (x=0.0, y=0.0),
        (x=1.0, y=3.0),
        (x=2.0, y=2.0),  # slope drop → non-convex
        (x=3.0, y=6.0),
    ])
)



# IncrementalCurve — PiecewiseStepData

ic_convex = IncrementalCurve(
    PiecewiseStepData(
        
        [0.0, 1.0, 2.0, 3.0],
        
        [1.0, 1.0, 1.0],
    ),
    0.0,  
    0.0   
)
ic_nonconvex = IncrementalCurve(
    PiecewiseStepData(
        [0.0, 1.0, 2.0, 3.0, 4.0],  
        [3.0, 1.0, 4.0, 4.0],       
    ),
    0.0,
    0.0
)


# AverageRateCurve — PiecewiseStepData

arc_convex = AverageRateCurve(
    PiecewiseStepData(
        [0.0, 1.0, 2.0, 3.0],
        [2.0, 2.5, 3.0],
    ),
    0.0,
    0.0
)
arc_nonconvex = AverageRateCurve(
    PiecewiseStepData(
        [0.0, 1.0, 2.0, 3.0],
        [3.0, 1.5, 2.5],
    ),
    0.0,
    0.0
)

# Colinear convex case

ioc_colinear = InputOutputCurve(
    PiecewiseLinearData([
        (x=0.0, y=0.0),
        (x=1.0, y=1.0),
        (x=2.0, y=2.0),  # same slope
        (x=3.0, y=3.0),
    ])
)

# Unsupported (should throw)
q_bad = QuadraticCurve(-0.5, 4.0, 1.0)

toy_curves = Dict(
    "IOC convex"        => ioc_convex,
    "IOC nonconvex"     => ioc_nonconvex,
    "IOC colinear"      => ioc_colinear,
    "Incremental convex"    => ic_convex,
    "Incremental nonconvex" => ic_nonconvex,
    "AvgRate convex"        => arc_convex,
    "AvgRate nonconvex"     => arc_nonconvex,
)

using PrettyTables

summary = []

for (name, curve) in toy_curves
    is_conv = IS.is_convex(curve)
    convexed = IS.make_convex_approximation(curve)
    n_before = length(get_y_coords(get_function_data(curve)))
    n_after  = length(get_y_coords(get_function_data(convexed)))

    push!(summary, (
        name,
        typeof(curve),
        is_conv,
        n_before,
        n_after,
    ))
end

summary = NamedTuple[]

for (name, curve) in toy_curves
    is_conv = IS.is_convex(curve)
    convexed = IS.make_convex_approximation(curve)

    fd1 = curve
    fd2 = convexed

    n_before = length(get_y_coords(fd1))
    n_after  = length(get_y_coords(fd2))

    push!(summary, (
        Curve = name,
        Type = nameof(typeof(curve)),
        Convex = is_conv,
        Segments_orig = n_before,
        Segments_after = n_after,
    ))
end

pretty_table(
    summary;
    title = "Toy Curve Convexification Summary",
)

using PlotlyJS

function plot_value_curve(curve; name="curve")
    fd = get_function_data(curve)

    if fd isa PiecewiseLinearData
        pts = get_points(fd)
        return scatter(
            x=[p.x for p in pts],
            y=[p.y for p in pts],
            mode="lines+markers",
            name=name,
        )
    elseif fd isa PiecewiseStepData
        x = get_x_coords(fd)
        y = get_y_coords(fd)
        return scatter(
            x=repeat(x, inner=2)[2:end-1],
            y=repeat(y, outer=2),
            mode="lines",
            name=name,
        )
    else
        error("Unsupported for plotting")
    end
end

function plot_convexification(curve, label)
    orig = plot_value_curve(curve; name="Original")
    conv = plot_value_curve(IS.make_convex(curve); name="Convexified")

    Plot(
        [orig, conv],
        Layout(
            title = label,
            xaxis = attr(title="x", range=[0,4]),
            yaxis = attr(title="y"),
        )
    )
end

display(plot_convexification(ioc_nonconvex, "InputOutputCurve — Non-convex"))
display(plot_convexification(ic_nonconvex,  "IncrementalCurve — Non-convex"))
display(plot_convexification(arc_nonconvex, "AverageRateCurve — Non-convex"))
display(plot_convexification(ioc_colinear,  "Colinear cleanup"))



function plot_io_equivalent(curve; label="")
    io_orig = curve isa InputOutputCurve ? curve : InputOutputCurve(curve)
    io_conv = InputOutputCurve(IS.make_convex(curve))

    Plot(
        [
            curve_trace(io_orig; name="Original IO"),
            curve_trace(io_conv; name="Convexified IO", dashed=true),
        ],
        Layout(
            title = label * " (IO-equivalent)",
            xaxis = attr(title="Production"),
            yaxis = attr(title="Total cost"),
        )
    )
end

display(plot_io_equivalent(ic_nonconvex; label="IncrementalCurve"))
display(plot_io_equivalent(arc_nonconvex; label="AverageRateCurve"))

# IOC Convex colinear

IS.is_convex(ioc_colinear)                    # true
length(get_points(get_function_data(ioc_colinear)))  # 4

merged = IS.make_convex(ioc_colinear)
length(get_points(get_function_data(merged)))  



# Original
orig_pts = get_points(get_function_data(ioc_colinear))
x_orig = [p.x for p in orig_pts]
y_orig = [p.y for p in orig_pts]

# Merged (convexified)
merged_pts = get_points(get_function_data(merged))
x_merged = [p.x for p in merged_pts]
y_merged = [p.y for p in merged_pts]

# --- Traces ---
trace_orig = scatter(
    x = x_orig,
    y = y_orig,
    mode = "lines+markers",
    name = "Original",
    marker = attr(size = 8),
    line = attr(width = 2)
)

trace_merged = scatter(
    x = x_merged,
    y = y_merged,
    mode = "lines+markers",
    name = "Merged",
    marker = attr(size = 10),
    line = attr(width = 3, dash = "dash")
)

# --- Layout with 1x2 grid ---
layout = Layout(
    title = "IOC Colinear Curve — Original vs Merged",
    grid = attr(rows = 1, columns = 2, pattern = "independent"),
    showlegend = true,
    xaxis = attr(title = "Input"),
    yaxis = attr(title = "Cost"),
    xaxis2 = attr(title = "Input"),
    yaxis2 = attr(title = "Cost")
)

# Assign traces to subplots
trace_orig[:xaxis] = "x"
trace_orig[:yaxis] = "y"

trace_merged[:xaxis] = "x2"
trace_merged[:yaxis] = "y2"

# --- Plot ---
fig = Plot([trace_orig, trace_merged], layout)
display(fig)

# Incremental convex colinear
ioc_collinear = InputOutputCurve(
    PiecewiseLinearData([
        (x=0.0, y=0.0),
        (x=1.0, y=1.0),   # slope = 1
        (x=2.0, y=2.0),   # slope = 1 (collinear)
        (x=3.0, y=4.0),   # slope = 2
        (x=4.0, y=6.0),   # slope = 2 (collinear)
    ])
)

ic_from_ioc = IncrementalCurve(ioc_collinear)
ic_merged = IS.make_convex(ic_from_ioc)

using PlotlyJS

using PlotlyJS

# Function to extract step points for IncrementalCurve plotting
function get_incremental_xy(ic::IncrementalCurve)
    fd = get_function_data(ic)  # PiecewiseStepData
    x_edges = get_x_coords(fd)
    y_values = get_y_coords(fd)
    
    # Build step plot coordinates
    x_plot = [x_edges[1]; repeat(x_edges[2:end], inner=[2])]
    y_plot = repeat(y_values, inner=[2])
    
    # Close the last step
    push!(x_plot, x_edges[end])
    push!(y_plot, y_values[end])
    
    return x_plot, y_plot
end

# Original incremental curve
x_orig, y_orig = get_incremental_xy(ic_from_ioc)

# Convexified incremental curve (with collinearity removed)
x_conv, y_conv = get_incremental_xy(ic_merged)

# Traces
trace_orig = scatter(
    x=x_orig, y=y_orig,
    mode="lines+markers",
    name="Original Incremental",
    line=attr(width=2, color="red"),
    marker=attr(size=6)
)

trace_conv = scatter(
    x=x_conv, y=y_conv,
    mode="lines+markers",
    name="Convexified Incremental",
    line=attr(width=2, color="green", dash="dash"),
    marker=attr(size=6, symbol="square")
)

# Layout
layout = Layout(
    title="IncrementalCurve — Original vs Convexified (collinear removed)",
    xaxis=attr(title="Input"),
    yaxis=attr(title="Step Value / Slope"),
    showlegend=true
)

# Plot
fig = Plot([trace_orig, trace_conv], layout)
display(fig)


## Corresponding IO curve

using PlotlyJS

# Function to extract step points for plotting IncrementalCurve
function get_step_xy(ic::IncrementalCurve)
    # Convert to InputOutputCurve to get cumulative points
    ioc = InputOutputCurve(ic)
    pts = get_points(get_function_data(ioc))
    x = [p.x for p in pts]
    y = [p.y for p in pts]
    return x, y
end

# Original and convexified
x_orig, y_orig = get_step_xy(ic_from_ioc)
x_conv, y_conv = get_step_xy(ic_merged)

# Traces
trace_orig = scatter(
    x=x_orig, y=y_orig,
    mode="lines+markers",
    name="Original",
    marker=attr(size=8),
    line=attr(width=2, color="red"),
    xaxis="x1", yaxis="y1"
)

trace_conv = scatter(
    x=x_conv, y=y_conv,
    mode="lines+markers",
    name="Convexified",
    marker=attr(size=8, symbol="square"),
    line=attr(width=2, color="green"),
    xaxis="x2", yaxis="y2"
)

# Layout with 1x2 grid
layout = Layout(
    title="IncrementalCurve Convexification (Collinear Correction)",
    grid=attr(rows=1, columns=2, pattern="independent"),
    showlegend=true,
    xaxis=attr(title="Input"),
    yaxis=attr(title="Cumulative Value"),
    xaxis2=attr(title="Input"),
    yaxis2=attr(title="Cumulative Value")
)

# Plot
fig = Plot([trace_orig, trace_conv], layout)
display(fig)


################### Toy examples for is_valid_data ###################

# ---------------- LinearFunctionData ----------------
lfd_valid = LinearFunctionData(1.0, 10.0)          # slope > 0, constant reasonable
lfd_neg_slope = LinearFunctionData(-0.5, 10.0)    # negative slope → invalid
lfd_large_slope = LinearFunctionData(1e9, 10.0)   # slope too large → invalid
lfd_neg_constant = LinearFunctionData(1.0, -1e7)  # constant too negative → invalid
lfd_large_constant = LinearFunctionData(1.0, 1e11)# constant too large → invalid

# ---------------- QuadraticFunctionData ----------------
qfd_valid = QuadraticFunctionData(1e-2, 2.0, 5.0)
qfd_neg_proportional = QuadraticFunctionData(1e-2, -0.5, 5.0)
qfd_large_quadratic = QuadraticFunctionData(1e9, 2.0, 5.0)
qfd_neg_constant = QuadraticFunctionData(1e-2, 2.0, -1e7)
qfd_large_constant = QuadraticFunctionData(1e-2, 2.0, 1e11)

# ---------------- PiecewiseLinearData ----------------
pld_valid = PiecewiseLinearData([
    (x=0.0, y=0.0),
    (x=1.0, y=1.0),
    (x=2.0, y=3.0),
])

pld_neg_slope = PiecewiseLinearData([
    (x=0.0, y=0.0),
    (x=1.0, y=2.0),
    (x=2.0, y=1.0),  # negative slope
])

pld_excessive_slope = PiecewiseLinearData([
    (x=0.0, y=0.0),
    (x=1.0, y=1e9),
])

pld_neg_y = PiecewiseLinearData([
    (x=0.0, y=0.0),
    (x=1.0, y=-1e7),  # negative cost
])

# ---------------- PiecewiseStepData ----------------
psd_valid = PiecewiseStepData([0.0, 1.0, 2.0], [1.0, 2.0])
psd_neg_rate = PiecewiseStepData([0.0, 1.0, 2.0], [-1.0, 2.0])
psd_excessive_rate = PiecewiseStepData([0.0, 1.0, 2.0], [1e9, 2.0])

# ---------------- ValueCurves ----------------
ioc_valid = InputOutputCurve(pld_valid)
ioc_invalid = InputOutputCurve(pld_neg_slope)

ic_valid = IncrementalCurve(psd_valid, 0.0, 0.0)
ic_invalid = IncrementalCurve(psd_neg_rate, 0.0, 0.0)

arc_valid = AverageRateCurve(psd_valid, 0.0, 0.0)
arc_invalid = AverageRateCurve(psd_neg_rate, 0.0, 0.0)

# ---------------- Test all ----------------
toy_curves = Dict(
    "Linear valid" => lfd_valid,
    "Linear neg slope" => lfd_neg_slope,
    "Linear large slope" => lfd_large_slope,
    "Linear neg constant" => lfd_neg_constant,
    "Linear large constant" => lfd_large_constant,
    "Quadratic valid" => qfd_valid,
    "Quadratic neg proportional" => qfd_neg_proportional,
    "Quadratic large quadratic" => qfd_large_quadratic,
    "Quadratic neg constant" => qfd_neg_constant,
    "Quadratic large constant" => qfd_large_constant,
    "PLD valid" => pld_valid,
    "PLD neg slope" => pld_neg_slope,
    # "PLD descending x" => pld_descending_x, #not possible to be an input throws error when declare
    "PLD excessive slope" => pld_excessive_slope,
    "PLD neg y" => pld_neg_y,
    "PSD valid" => psd_valid,
    "PSD neg rate" => psd_neg_rate,
    "PSD excessive rate" => psd_excessive_rate,
    #"PSD descending x" => psd_descending_x, #not possible to be an input throws error when declare
    "IOC valid" => ioc_valid,
    "IOC invalid" => ioc_invalid,
    "Incremental valid" => ic_valid,
    "Incremental invalid" => ic_invalid,
    "AverageRate valid" => arc_valid,
    "AverageRate invalid" => arc_invalid,
)




using Logging
using DataFrames


# ============================================================================
# ------------------- Helpers for capturing reasons --------------------------
# ============================================================================

# Clean log messages
clean_reason(msg::AbstractString) = strip(replace(msg, r"┌ Error: Data quality issue:" => ""))

# Check if the reason matches expectations
function check_reason(curve, reason)
    # Any valid rejection should contain one of these keywords
    keywords = ["slope", "rate", "proportional", "quadratic", "constant", "cost"]
    return any(k -> occursin(k, reason), keywords) || reason == "OK"
end

# ============================================================================
# ------------------- Run validations and collect summary -------------------
# ============================================================================

summary = []

for (name, curve) in toy_curves
    log_messages = IOBuffer()
    temp_logger = Logging.SimpleLogger(log_messages, Logging.Error)

    valid, raw_reason = Logging.with_logger(temp_logger) do
        try
            ok = IS.is_valid_data(curve)
            msg = ok ? "OK" : "Invalid data"
            return (ok, msg)
        catch e
            msg = e isa NotImplementedError ? "Unsupported" : "Error: $(e)"
            return (false, msg)
        end
    end

    # Capture and clean logs
    log_str = clean_reason(String(take!(log_messages)))
    reason = isempty(log_str) ? raw_reason : log_str

    # Determine if the reason is valid according to the keywords
    ok_flag = check_reason(curve, reason)

    push!(summary, (
        Name = name,
        Type = nameof(typeof(curve)),
        Valid = valid,
        OK = ok_flag,
        Reason = reason
    ))
end

# Convert to DataFrame
df_summary = DataFrame(summary)

########## NEW VERSION ###############

# ---------------- LinearFunctionData (TOTAL COST) ----------------

lfd_valid = LinearFunctionData(1.0, 10.0)
lfd_decremental = LinearFunctionData(-0.5, 50.0)     # valid total cost
lfd_large_slope = LinearFunctionData(1e9, 10.0)      # invalid
lfd_neg_constant = LinearFunctionData(1.0, -1e7)     # invalid
lfd_large_constant = LinearFunctionData(1.0, 1e11)   # invalid

# ---------------- QuadraticFunctionData (TOTAL COST) ----------------

qfd_valid = QuadraticFunctionData(1e-2, 2.0, 5.0)
qfd_decremental_start = QuadraticFunctionData(1e-2, -1.0, 20.0)  # valid
qfd_large_quadratic = QuadraticFunctionData(1e9, 2.0, 5.0)       # invalid
qfd_neg_constant = QuadraticFunctionData(1e-2, 2.0, -1e7)        # invalid
qfd_large_constant = QuadraticFunctionData(1e-2, 2.0, 1e11)      # invalid

# ---------------- PiecewiseLinearData (TOTAL COST / PWL) ----------------

pld_valid = PiecewiseLinearData([
    (x=0.0, y=0.0),
    (x=1.0, y=1.0),
    (x=2.0, y=3.0),
])

pld_decremental_valid = PiecewiseLinearData([
    (x=0.0, y=100.0),
    (x=1.0, y=90.0),   # negative slope, OK
    (x=2.0, y=95.0),
])

pld_excessive_slope = PiecewiseLinearData([
    (x=0.0, y=0.0),
    (x=1.0, y=1e9),
])

pld_neg_y = PiecewiseLinearData([
    (x=0.0, y=0.0),
    (x=1.0, y=-1e7),   # invalid
])

# ---------------- PiecewiseStepData (MARGINAL COST) ----------------

psd_valid = PiecewiseStepData([0.0, 1.0, 2.0], [1.0, 2.0])
psd_neg_rate = PiecewiseStepData([0.0, 1.0, 2.0], [-1.0, 2.0])   # invalid
psd_excessive_rate = PiecewiseStepData([0.0, 1.0, 2.0], [1e9, 2.0])

# ---------------- ValueCurves ----------------
ioc_valid = InputOutputCurve(pld_valid)
ioc_decremental = InputOutputCurve(pld_decremental_valid)

ic_valid = IncrementalCurve(psd_valid, 0.0, 0.0)
ic_invalid = IncrementalCurve(psd_neg_rate, 0.0, 0.0)

arc_valid = AverageRateCurve(psd_valid, 0.0, 0.0)
arc_invalid = AverageRateCurve(psd_neg_rate, 0.0, 0.0)

# test dictionary

toy_curves = Dict(

    # ---------------- LinearFunctionData (TOTAL COST) ----------------
    "Linear valid" => (
        curve = LinearFunctionData(1.0, 10.0),
        expected = true,
    ),

    "Linear decremental valid" => (
        curve = LinearFunctionData(-0.5, 50.0),   # negative slope allowed
        expected = true,
    ),

    "Linear excessive slope" => (
        curve = LinearFunctionData(1e9, 10.0),
        expected = false,
    ),

    "Linear negative constant" => (
        curve = LinearFunctionData(1.0, -1e7),
        expected = false,
    ),

    "Linear large constant" => (
        curve = LinearFunctionData(1.0, 1e11),
        expected = false,
    ),

    # ---------------- QuadraticFunctionData (TOTAL COST) ----------------
    "Quadratic valid" => (
        curve = QuadraticFunctionData(1e-2, 2.0, 5.0),
        expected = true,
    ),

    "Quadratic decremental start" => (
        curve = QuadraticFunctionData(1e-2, -1.0, 20.0),  # negative initial slope allowed
        expected = true,
    ),

    "Quadratic large quadratic" => (
        curve = QuadraticFunctionData(1e9, 2.0, 5.0),
        expected = false,
    ),

    "Quadratic negative constant" => (
        curve = QuadraticFunctionData(1e-2, 2.0, -1e7),
        expected = false,
    ),

    "Quadratic large constant" => (
        curve = QuadraticFunctionData(1e-2, 2.0, 1e11),
        expected = false,
    ),

    # ---------------- PiecewiseLinearData (PWL – TOTAL COST) ----------------
    "PWL valid" => (
        curve = PiecewiseLinearData([
            (x=0.0, y=0.0),
            (x=1.0, y=1.0),
            (x=2.0, y=3.0),
        ]),
        expected = true,
    ),

    "PWL decremental valid" => (
        curve = PiecewiseLinearData([
            (x=0.0, y=100.0),
            (x=1.0, y=90.0),   # negative slope allowed
            (x=2.0, y=95.0),
        ]),
        expected = true,
    ),

    "PWL excessive slope" => (
        curve = PiecewiseLinearData([
            (x=0.0, y=0.0),
            (x=1.0, y=1e9),
        ]),
        expected = false,
    ),

    "PWL negative cost" => (
        curve = PiecewiseLinearData([
            (x=0.0, y=0.0),
            (x=1.0, y=-1e7),
        ]),
        expected = false,
    ),

    # ---------------- PiecewiseStepData (MARGINAL COST) ----------------
    "PSD valid" => (
        curve = PiecewiseStepData([0.0, 1.0, 2.0], [1.0, 2.0]),
        expected = true,
    ),

    "PSD negative marginal rate" => (
        curve = PiecewiseStepData([0.0, 1.0, 2.0], [-1.0, 2.0]),
        expected = true,
    ),

    "PSD excessive marginal rate" => (
        curve = PiecewiseStepData([0.0, 1.0, 2.0], [1e9, 2.0]),
        expected = false,
    ),

    # ---------------- ValueCurves ----------------
    "InputOutput valid" => (
        curve = InputOutputCurve(PiecewiseLinearData([
            (x=0.0, y=0.0),
            (x=1.0, y=1.0),
        ])),
        expected = true,
    ),

    "InputOutput decremental valid" => (
        curve = InputOutputCurve(PiecewiseLinearData([
            (x=0.0, y=100.0),
            (x=1.0, y=90.0),
        ])),
        expected = true,
    ),

    "Incremental valid" => (
        curve = IncrementalCurve(
            PiecewiseStepData([0.0, 1.0, 2.0], [1.0, 2.0]),
            0.0,
            0.0,
        ),
        expected = true,
    ),

    "Incremental invalid (negative marginal)" => (
        curve = IncrementalCurve(
            PiecewiseStepData([0.0, 1.0, 2.0], [-1.0, 2.0]),
            0.0,
            0.0,
        ),
        expected = true,
    ),

    "AverageRate valid" => (
        curve = AverageRateCurve(
            PiecewiseStepData([0.0, 1.0, 2.0], [1.0, 2.0]),
            0.0,
            0.0,
        ),
        expected = true,
    ),

    "AverageRate invalid (negative marginal)" => (
        curve = AverageRateCurve(
            PiecewiseStepData([0.0, 1.0, 2.0], [-1.0, 2.0]),
            0.0,
            0.0,
        ),
        expected = true,
    ),
)


summary = []

for (name, item) in toy_curves
    curve = item.curve
    expected = item.expected

    log_messages = IOBuffer()
    temp_logger = Logging.SimpleLogger(log_messages, Logging.Error)

    valid, raw_reason = Logging.with_logger(temp_logger) do
        try
            ok = IS.is_valid_data(curve)
            msg = ok ? "OK" : "Invalid data"
            return (ok, msg)
        catch e
            msg = e isa NotImplementedError ? "Unsupported" : "Error: $(e)"
            return (false, msg)
        end
    end

    log_str = clean_reason(String(take!(log_messages)))
    reason = isempty(log_str) ? raw_reason : log_str

    passed = (valid == expected)

    push!(summary, (
        Name = name,
        Type = nameof(typeof(curve)),
        Expected = expected,
        Valid = valid,
        Pass = passed,
        Reason = reason
    ))
end

df_summary = DataFrame(summary)

#Plot

using PlotlyJS

function extract_xy(curve)
    # ---------------- InputOutputCurve ----------------
    if curve isa InputOutputCurve
        fd = get_function_data(curve)
        return extract_xy(fd)  # delegate to underlying function_data

    # ---------------- PiecewisePointCurve ----------------
    elseif curve isa PiecewisePointCurve
        x = [p.x for p in curve.points]
        y = [p.y for p in curve.points]
        return x, y

    # ---------------- PiecewiseLinearData ----------------
    elseif curve isa PiecewiseLinearData
        pts = get_points(curve)
        x = [p.x for p in pts]
        y = [p.y for p in pts]

        # Ensure last segment is included
        if length(x) > 1 && length(y) < length(x)
            push!(y, y[end])
        end
        return x, y

    # ---------------- LinearFunctionData ----------------
    elseif curve isa LinearFunctionData
        x = [0.0, 1.0]
        y = [curve.constant_term, curve.constant_term + curve.proportional_term]
        return x, y

    # ---------------- QuadraticFunctionData ----------------
    elseif curve isa QuadraticFunctionData
        a = curve.quadratic_term
        b = curve.proportional_term
        c = curve.constant_term
        x = collect(range(0.0, 2.0; length=50))
        y = [a*xi^2 + b*xi + c for xi in x]
        return x, y

    # ---------------- PiecewiseStepData ----------------
    elseif curve isa PiecewiseStepData
        x = get_x_coords(curve)
        y = get_y_coords(curve)
        if length(y) == length(x) - 1
            y = [y[1]; y...]  # make lengths match
        end
        return x, y

    # ---------------- Incremental / AverageRate ----------------
    elseif curve isa IncrementalCurve || curve isa AverageRateCurve
        # delegate to underlying function_data
        return extract_xy(curve.function_data)

    else
        return Float64[], Float64[]
    end
end




# --- Plotting ---

traces = PlotlyJS.GenericTrace[]
annotations = Vector{Any}()
n = length(toy_curves)

for (i, (name, item)) in enumerate(toy_curves)
    curve = item.curve
    expected = item.expected

    x, y = extract_xy(curve)

    color = expected ? "rgba(44,160,44,0.8)" : "rgba(214,39,40,0.8)"

    push!(traces,
        scatter(
            x = x,
            y = y,
            mode = "lines+markers",
            name = name,
            marker = attr(size = 7, color = color),
            line = attr(width = 2, color = color),
            xaxis = "x$i",
            yaxis = "y$i",
        )
    )

    push!(annotations, attr(
        text = name,
        xref = "x$i domain",
        yref = "y$i domain",
        x = 0.5,
        y = 1.05,
        showarrow = false,
        font = attr(size = 12),
    ))
end

layout = Layout(
    title = "Toy Curve Validation — Green = Valid, Red = Invalid",
    grid = attr(
        rows = ceil(Int, n / 2),
        columns = 2,
        pattern = "independent",
    ),
    annotations = annotations,
    showlegend = false,
    height = 300 * ceil(Int, n / 2),
    width = 900,
)

fig = Plot(traces, layout)
display(fig)
