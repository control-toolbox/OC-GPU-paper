# goddard.jl

using OptimalControl
using MadNLPMumps
using MadNLPGPU
using CUDA
using BenchmarkTools
using Interpolations
import Logging
using Plots

Logging.disable_logging(Logging.Warn) # disable warnings
versioninfo() # CUDA

# Goddard (bang-singular-boundary-bang structure)

function goddard()

    r0 = 1.0     
    v0 = 0.0
    m0 = 1.0 
    vmax = 0.1 
    mf = 0.6   
    Cd = 310.0
    Tmax = 3.5
    β = 500.0
    b = 2.0

    o = @def begin

        tf ∈ R, variable
        t ∈ [0, tf], time
        x = (r, v, m) ∈ R³, state
        u ∈ R, control
    
        x(0) == [r0, v0, m0]
        m(tf) == mf
        0 ≤ u(t) ≤ 1
        r(t) ≥ r0
        0 ≤ v(t) ≤ vmax
    
        ∂(r)(t) == v(t)
        ∂(v)(t) == -Cd * v(t)^2 * exp(-β * (r(t) - 1)) / m(t) - 1 / r(t)^2 + u(t) * Tmax / m(t)
        ∂(m)(t) == -b * Tmax * u(t)
    
        r(tf) → max
    
    end

    return o

end

# Quadrotor

function quadrotor()

    T = 1
    g = 9.8
    r = 0.1

    o = @def begin
        
        t ∈ [0, T], time
        x ∈ R⁹, state
        u ∈ R⁴, control
    
        x(0) == zeros(9)
    
        ∂(x₁)(t) == x₂(t)
        ∂(x₂)(t) == u₁(t) * cos(x₇(t)) * sin(x₈(t)) * cos(x₉(t)) + u₁(t) * sin(x₇(t)) * sin(x₉(t))
        ∂(x₃)(t) == x₄(t)
        ∂(x₄)(t) == u₁(t) * cos(x₇(t)) * sin(x₈(t)) * sin(x₉(t)) - u₁(t) * sin(x₇(t)) * cos(x₉(t))
        ∂(x₅)(t) == x₆(t)
        ∂(x₆)(t) == u₁(t) * cos(x₇(t)) * cos(x₈(t)) - g 
        ∂(x₇)(t) == u₂(t) * cos(x₇(t)) / cos(x₈(t)) + u₃(t) * sin(x₇(t)) / cos(x₈(t))
        ∂(x₈)(t) ==-u₂(t) * sin(x₇(t)) + u₃(t) * cos(x₇(t))
        ∂(x₉)(t) == u₂(t) * cos(x₇(t)) * tan(x₈(t)) + u₃(t) * sin(x₇(t)) * tan(x₈(t)) + u₄(t)
    
        dt1 = sin(2π * t / T)
        df1 = 0 
        dt3 = 2sin(4π * t / T)
        df3 = 0 
        dt5 = 2t / T
        df5 = 2
    
        0.5∫( (x₁(t) - dt1)^2 + (x₃(t) - dt3)^2 + (x₅(t) - dt5)^2 + x₇(t)^2 + x₈(t)^2 + x₉(t)^2 +
           r * (u₁(t)^2 + u₂(t)^2 + u₃(t)^2 + u₄(t)^2) ) → min
    
    end

    return o

end
    
 
# Solving

tol = 1e-7
print_level = MadNLP.WARN
#print_level = MadNLP.INFO

for (name, o) ∈ [("goddard", goddard()), ("quadrotor", quadrotor())]
printstyled("\nProblem: $name\n"; bold=true)
for N ∈ (100, 200, 500, 750, 1_000, 2_000, 5_000, 7_500, 10_000, 20_000, 50_000, 75_000, 100_000)

    m_cpu = model(direct_transcription(o, :exa; grid_size=N))
    m_gpu = model(direct_transcription(o, :exa; grid_size=N, exa_backend=CUDABackend()))
    printstyled("\nsolver = MadNLP", ", N = ", N, "\n"; bold=true)
    print("CPU:")
    try sol = @btime madnlp($m_cpu; print_level=$print_level, tol=$tol, linear_solver=MumpsSolver)
        println("      converged: ", sol.status == MadNLP.Status(1), ", iter: ", sol.iter)
    catch ex
        println("\n      error: ", ex)
    end
    CUDA.functional() || throw("CUDA not available")
    print("GPU:")
    try madnlp(m_gpu; print_level=print_level, tol=tol);
        sol = CUDA.@time madnlp(m_gpu; print_level=print_level, tol=tol)
        println("      converged: ", sol.status == MadNLP.Status(1), ", iter: ", sol.iter)
    catch ex
        println("\n      error: ", ex)
    end

end; end

# Plotting

function my_plot(a)

    p = plot(a[1, :], [a[2, :] a[3, :]],
         marker = [:circle :square],
         markersize = [4 6],
         linewidth = 2,
         labels = ["CPU" "GPU"],
         xscale=:log10,
         yscale=:log10,
         xlabel="N",
         ylabel="time (s)")

    display(p)
    return p

end

# Goddard A100

raw =
[ 100 14.6e-3 0.158 
  200 29.3e-3 0.174
  500 71.6e-3 0.186
  750 102e-3 0.202
 1_000 134e-3 0.211
 2_000 286e-3 0.254
 5_000 861e-3 0.489 
 7_500 1.27 0.762
 10_000 1.72 0.988
 20_000 3.59 1.54
 50_000 10.1 4.33
 75_000 15.9 6.59
 100_000 21.5 8.75 ]'

my_plot(raw)