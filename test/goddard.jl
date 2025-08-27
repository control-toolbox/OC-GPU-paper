# goddard.jl

using OptimalControl
using MadNLPMumps
using MadNLPGPU
using CUDA
using BenchmarkTools
using Interpolations
import Logging

Logging.disable_logging(Logging.Warn) # disable warnings

# Problem definition: Goddard with bang-singular-boundary-bang structure

const r0 = 1.0     
const v0 = 0.0
const m0 = 1.0 
const vmax = 0.1 
const mf = 0.6   
const Cd = 310.0
const Tmax = 3.5
const β = 500.0
const b = 2.0

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

# Solving

tol = 1e-7
#print_level = MadNLP.WARN
print_level = MadNLP.INFO

for N ∈ (100,) # 500, 1000, 2000, 5000, 7500, 10000, 20000, 50000)

    m_cpu = model(direct_transcription(o, :exa; grid_size=N))
    m_gpu = model(direct_transcription(o, :exa; grid_size=N, exa_backend=CUDABackend()))
    printstyled("\nsolver = MadNLP", ", N = ", N, "\n"; bold = true)
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

end