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
        dt3 = 2sin(4π * t / T)
        dt5 = 2t / T
    
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

# Goddard (A100)

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

# Quadrotor (A100)

raw =
[ 100 21.353e-3 0.099
  200 34.980e-3 0.098
  500 142.676e-3 0.133792
  750 220.982e-3 0.195213
  1_000 302.281e-3 0.200412
  2_000 662.417e-3 0.247585
  5_000 1.823 0.396962
  7_500 2.804 0.595128
  10_000 3.777 0.740234
  20_000 8.044 1.998651
  50_000 22.227 3.903839
  75_000 35.215 6.172591
  100_000 48.817 8.304282 ]'

my_plot(raw)

# Goddard (H100)

raw =
[ 100 7.738e-3 0.107823
  200 15.637e-3 0.115552
  500 39.242e-3 0.148288
  750 58.258e-3 0.142089
  1_000 76.186e-3 0.160535
  2_000 168.722e-3 0.206995
  5_000 443.280e-3 0.382383
  7_500 654.841e-3 0.549268
  10_000 920.491e-3 0.722610
  20_000 2.004 1.118048
  50_000 5.884 3.915129
  75_000 9.390 5.261726
  100_000 12.583 7.065026
  150_000 82.927 11.068635
  200_000 35.561 15.575185 ]'

my_plot(raw)

# Quadrotor (H100)

raw =
[ 100 11.405e-3 0.058282
  200 17.899e-3 0.063167
  500 97.482e-3 0.098962
  750 148.847e-3 0.116741
  1_000 203.412e-3 0.132041
  2_000 434.968e-3 0.199469
  5_000 1.174 0.319701
  7_500 1.842 0.443139
  10_000 2.516 0.597242
  20_000 5.420 1.171388
  50_000 14.530 2.983489
  75_000 23.110 4.728128
  100_000 32.666 6.395791
  150_000 49.863 9.872939
  200_000 65.463 13.413465 ]'

 my_plot(raw)